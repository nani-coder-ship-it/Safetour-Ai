"""
SafeTour AI - GAT Model Training and Evaluation Pipeline
---------------------------------------------------------
Trains the Edge-Conditioned Multi-Head GATv2 model on the real road network
graph to predict road segment safety scores.

Features:
  - Supervised training with Smooth L1 / Huber loss and AdamW optimizer.
  - Learning rate scheduling with ReduceLROnPlateau.
  - Checkpoint tracking with Early Stopping.
  - Comprehensive IEEE metrics: RMSE, MAE, R^2 score.
  - Edge prediction export: data/test_predictions.csv.
"""

import os
import sys
import json
import time
from pathlib import Path
import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.optim import AdamW
from torch.optim.lr_scheduler import ReduceLROnPlateau
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

# Add package root to sys.path
script_dir = Path(__file__).resolve().parent
base_dir = script_dir.parent
if str(base_dir) not in sys.path:
    sys.path.insert(0, str(base_dir))

from models.dataset import build_pyg_graph
from models.gat_model import RoadSafetyGAT


def train_epoch(model, data, optimizer, criterion):
    model.train()
    optimizer.zero_grad()

    # Forward pass
    pred = model(data.x, data.edge_index, data.edge_attr)

    # Compute loss over training edges only
    loss = criterion(pred[data.train_mask], data.y[data.train_mask])
    loss.backward()
    nn.utils.clip_grad_norm_(model.parameters(), max_norm=2.0)
    optimizer.step()

    return loss.item()


@torch.no_grad()
def evaluate(model, data, mask):
    model.eval()
    pred = model(data.x, data.edge_index, data.edge_attr)

    y_true = data.y[mask].cpu().numpy().flatten()
    y_pred = pred[mask].cpu().numpy().flatten()

    mse = mean_squared_error(y_true, y_pred)
    rmse = np.sqrt(mse)
    mae = mean_absolute_error(y_true, y_pred)
    r2 = r2_score(y_true, y_pred)

    return rmse, mae, r2, y_true, y_pred


def train_gat(
    num_epochs=150,
    lr=0.003,
    hidden_dim=64,
    num_heads=4,
    num_layers=2,
    patience=30,
    seed=42
):
    # Reproducibility
    torch.manual_seed(seed)
    np.random.seed(seed)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[*] Training on device: {device}")

    # Paths
    nodes_csv = base_dir / "data" / "nodes.csv"
    edges_csv = base_dir / "data" / "edges.csv"
    checkpoints_dir = base_dir / "models" / "checkpoints"
    checkpoints_dir.mkdir(parents=True, exist_ok=True)
    best_model_path = checkpoints_dir / "best_gat_model.pt"

    # Build PyG Data
    print("[*] Loading graph and constructing PyG tensors...")
    data, meta = build_pyg_graph(str(nodes_csv), str(edges_csv), seed=seed)
    data = data.to(device)

    # Model
    model = RoadSafetyGAT(
        node_in_dim=data.x.shape[1],
        edge_in_dim=data.edge_attr.shape[1],
        hidden_dim=hidden_dim,
        num_heads=num_heads,
        num_layers=num_layers,
        dropout=0.1
    ).to(device)

    total_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    print(f"[*] Model initialized: {total_params:,} trainable parameters.")

    # Optimizer, Loss, Scheduler
    optimizer = AdamW(model.parameters(), lr=lr, weight_decay=1e-4)
    criterion = nn.SmoothL1Loss(beta=1.0)  # Robust Huber loss
    scheduler = ReduceLROnPlateau(optimizer, mode="min", factor=0.5, patience=10, min_lr=1e-5)

    best_val_rmse = float("inf")
    best_epoch = 0
    patience_counter = 0

    history = {
        "train_loss": [],
        "val_rmse": [],
        "val_mae": [],
        "val_r2": [],
        "lr": []
    }

    print("\n" + "=" * 70)
    print("STARTING GATv2 MODEL TRAINING")
    print("=" * 70)
    start_time = time.time()

    for epoch in range(1, num_epochs + 1):
        loss = train_epoch(model, data, optimizer, criterion)
        val_rmse, val_mae, val_r2, _, _ = evaluate(model, data, data.val_mask)

        scheduler.step(val_rmse)
        curr_lr = optimizer.param_groups[0]["lr"]

        history["train_loss"].append(loss)
        history["val_rmse"].append(val_rmse)
        history["val_mae"].append(val_mae)
        history["val_r2"].append(val_r2)
        history["lr"].append(curr_lr)

        # Checkpoint best model
        if val_rmse < best_val_rmse:
            best_val_rmse = val_rmse
            best_epoch = epoch
            patience_counter = 0
            torch.save({
                "epoch": int(epoch),
                "model_state_dict": model.state_dict(),
                "val_rmse": float(val_rmse),
                "val_mae": float(val_mae),
                "val_r2": float(val_r2),
                "metadata": {
                    "node_in_dim": int(data.x.shape[1]),
                    "edge_in_dim": int(data.edge_attr.shape[1]),
                    "hidden_dim": int(hidden_dim),
                    "num_heads": int(num_heads)
                }
            }, str(best_model_path))
        else:
            patience_counter += 1

        if epoch % 10 == 0 or epoch == 1:
            print(f"Epoch {epoch:03d} | Train Loss: {loss:.4f} | Val RMSE: {val_rmse:.2f} | Val MAE: {val_mae:.2f} | Val R^2: {val_r2:.4f} | LR: {curr_lr:.6f}")

        # Early Stopping
        if patience_counter >= patience:
            print(f"\n[!] Early stopping triggered at epoch {epoch} (No improvement for {patience} epochs).")
            break

    elapsed = time.time() - start_time
    print(f"\n[OK] Training completed in {elapsed:.2f}s. Best model from Epoch {best_epoch:03d} (Val RMSE: {best_val_rmse:.2f}).")

    # Load Best Model for Final Test Evaluation
    print(f"[*] Loading best checkpoint from {best_model_path.name} for Test Evaluation...")
    checkpoint = torch.load(str(best_model_path), map_location=device, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])

    test_rmse, test_mae, test_r2, y_true_test, y_pred_test = evaluate(model, data, data.test_mask)

    print("\n" + "=" * 70)
    print("FINAL TEST SET EVALUATION (Unseen Test Edges)")
    print("=" * 70)
    print(f"  * Test RMSE:         {test_rmse:.3f} (on 0-100 safety score scale)")
    print(f"  * Test MAE:          {test_mae:.3f} points")
    print(f"  * Test R^2 Score:    {test_r2:.4f} ({test_r2 * 100:.1f}% variance explained)")
    print("=" * 70 + "\n")

    # Export Test Predictions Table for Analysis
    df_edges = meta["df_edges"]
    test_indices = np.where(data.test_mask.cpu().numpy())[0]

    df_test_results = df_edges.iloc[test_indices].copy()
    df_test_results["ground_truth_safety"] = y_true_test
    df_test_results["predicted_safety"] = y_pred_test
    df_test_results["absolute_error"] = np.abs(y_true_test - y_pred_test)

    pred_out_path = base_dir / "data" / "test_predictions.csv"
    df_test_results.to_csv(pred_out_path, index=False)
    print(f"[OK] Exported test predictions to: {pred_out_path}")

    # Save training history
    history_path = checkpoints_dir / "training_history.json"
    with open(history_path, "w") as f:
        json.dump(history, f, indent=2)
    print(f"[OK] Saved training history to: {history_path}")

    return {
        "best_epoch": best_epoch,
        "val_rmse": best_val_rmse,
        "test_rmse": test_rmse,
        "test_mae": test_mae,
        "test_r2": test_r2,
        "checkpoint_path": str(best_model_path)
    }


if __name__ == "__main__":
    train_gat(num_epochs=120, lr=0.003, hidden_dim=64, num_heads=4, patience=25)
