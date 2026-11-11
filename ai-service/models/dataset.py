"""
SafeTour AI - PyTorch Geometric Dataset Loader for Road Network
----------------------------------------------------------------
Constructs PyG `Data` tensors from featured road graph exports:
  - Node Features X in R^(N x d_node): normalized coordinates, accident metrics,
    crime rates, intersection structural centrality.
  - Edge Index E in R^(2 x M): directed graph connectivity mapping OSM node IDs.
  - Edge Attributes in R^(M x d_edge): length, road class (one-hot), oneway,
    environmental hazards (flood, crime, tourist density).
  - Target Y in R^(M x 1): composite ground-truth safety score (0 - 100).
  - Masks: train_mask (70%), val_mask (15%), test_mask (15%).
"""

import os
from pathlib import Path
import numpy as np
import pandas as pd
import torch
from torch_geometric.data import Data
from sklearn.preprocessing import StandardScaler

ROAD_CLASSES = [
    "trunk", "primary", "secondary", "tertiary",
    "residential", "service", "unclassified", "other"
]


def encode_road_type(road_type_str):
    """One-hot encodes highway/road type."""
    rt = str(road_type_str).lower().strip()
    encoding = [0.0] * len(ROAD_CLASSES)
    if rt in ROAD_CLASSES:
        encoding[ROAD_CLASSES.index(rt)] = 1.0
    else:
        encoding[ROAD_CLASSES.index("other")] = 1.0
    return encoding


def calculate_ground_truth_safety(df_edges):
    """
    Computes a multi-hazard empirical ground-truth safety score in [0, 100].
    Higher score = Safer road segment.
    Lower score = Dangerous segment (high accident/crime/flood vulnerability).

    Weights:
      - 35% Accident Risk
      - 25% Crime Score
      - 15% Flood Risk
      - 15% Road Vulnerability (unclassified/service roads have less lighting/surveillance)
      - 10% Tourist / Crowd Density Stress
    """
    # Vulnerability by road class (high hierarchy = better infrastructure & surveillance)
    road_vuln_map = {
        "trunk": 15.0, "primary": 20.0, "secondary": 30.0, "tertiary": 40.0,
        "residential": 50.0, "service": 65.0, "unclassified": 55.0, "other": 60.0
    }
    road_vuln = df_edges["road_type"].map(lambda x: road_vuln_map.get(str(x).lower().strip(), 50.0))

    acc_risk = df_edges["accident_risk"].astype(float)
    crime = df_edges["crime_score"].astype(float)
    flood = df_edges["flood_risk"].astype(float)
    tourist = df_edges["tourist_density"].astype(float)

    hazard_index = (
        0.35 * acc_risk +
        0.25 * crime +
        0.15 * flood +
        0.15 * road_vuln +
        0.10 * tourist
    )

    # Invert so higher score represents safer road
    safety_score = np.clip(100.0 - hazard_index, 0.0, 100.0)
    return safety_score.values.astype(np.float32)


def build_pyg_graph(nodes_csv_path, edges_csv_path, seed=42):
    """
    Loads nodes.csv and edges.csv, maps node IDs to contiguous indices,
    normalizes features, and creates a PyTorch Geometric `Data` object.
    """
    df_nodes = pd.read_csv(nodes_csv_path)
    df_edges = pd.read_csv(edges_csv_path)

    # 1. Continuous Node ID Mapping
    unique_node_ids = df_nodes["node_id"].unique()
    node_to_idx = {nid: idx for idx, nid in enumerate(unique_node_ids)}
    num_nodes = len(unique_node_ids)

    # Filter any edges referencing missing nodes
    df_edges = df_edges[
        df_edges["u"].isin(node_to_idx) & df_edges["v"].isin(node_to_idx)
    ].reset_index(drop=True)

    # 2. Compute Structural Graph Centrality (In/Out Degree)
    u_indices = df_edges["u"].map(node_to_idx).values
    v_indices = df_edges["v"].map(node_to_idx).values

    out_degree = np.bincount(u_indices, minlength=num_nodes).astype(np.float32)
    in_degree = np.bincount(v_indices, minlength=num_nodes).astype(np.float32)

    # 3. Construct Node Feature Matrix X
    # [lat, lng, log_acc_count, acc_sev, norm_reg_acc, norm_crime, poi_count, in_deg, out_deg]
    lat_scaled = (df_nodes["lat"].values - df_nodes["lat"].mean()) / (df_nodes["lat"].std() + 1e-6)
    lng_scaled = (df_nodes["lng"].values - df_nodes["lng"].mean()) / (df_nodes["lng"].std() + 1e-6)
    log_acc = np.log1p(df_nodes["accident_count"].values)
    acc_sev = df_nodes["accident_severity"].values / 1000.0
    reg_acc = df_nodes["regional_accidents"].values / 5000.0
    crime = df_nodes["crime_score"].values / 100.0
    poi = df_nodes["nearby_poi_count"].values.astype(np.float32)

    node_features = np.column_stack([
        lat_scaled, lng_scaled, log_acc, acc_sev,
        reg_acc, crime, poi, in_degree, out_degree
    ]).astype(np.float32)

    X = torch.tensor(node_features, dtype=torch.float)

    # 4. Construct Edge Index
    edge_index = torch.tensor(np.array([u_indices, v_indices]), dtype=torch.long)

    # 5. Construct Edge Feature Matrix
    # [log_length, oneway, road_type_onehot (8), crime, acc_risk, flood_risk, tourist_density, road_blocked]
    norm_length = (np.log1p(df_edges["length"].values) / 6.0).astype(np.float32)
    oneway = df_edges["oneway"].astype(np.float32).values
    road_onehot = np.array([encode_road_type(rt) for rt in df_edges["road_type"].values], dtype=np.float32)
    e_crime = (df_edges["crime_score"].values / 100.0).astype(np.float32)
    e_acc = (df_edges["accident_risk"].values / 100.0).astype(np.float32)
    e_flood = (df_edges["flood_risk"].values / 100.0).astype(np.float32)
    e_tourist = (df_edges["tourist_density"].values / 100.0).astype(np.float32)
    e_blocked = df_edges["road_blocked"].astype(np.float32).values

    edge_features = np.column_stack([
        norm_length, oneway, road_onehot, e_crime, e_acc, e_flood, e_tourist, e_blocked
    ]).astype(np.float32)

    edge_attr = torch.tensor(edge_features, dtype=torch.float)

    # 6. Target Safety Scores
    ground_truth_safety = calculate_ground_truth_safety(df_edges)
    Y = torch.tensor(ground_truth_safety, dtype=torch.float).unsqueeze(1)

    # 7. Create Train / Val / Test edge masks (70% / 15% / 15%)
    num_edges = len(df_edges)
    np.random.seed(seed)
    indices = np.random.permutation(num_edges)

    train_end = int(0.70 * num_edges)
    val_end = int(0.85 * num_edges)

    train_mask = torch.zeros(num_edges, dtype=torch.bool)
    val_mask = torch.zeros(num_edges, dtype=torch.bool)
    test_mask = torch.zeros(num_edges, dtype=torch.bool)

    train_mask[indices[:train_end]] = True
    val_mask[indices[train_end:val_end]] = True
    test_mask[indices[val_end:]] = True

    # 8. Package into PyG Data Object
    data = Data(
        x=X,
        edge_index=edge_index,
        edge_attr=edge_attr,
        y=Y,
        train_mask=train_mask,
        val_mask=val_mask,
        test_mask=test_mask
    )

    metadata = {
        "num_nodes": num_nodes,
        "num_edges": num_edges,
        "node_features_dim": X.shape[1],
        "edge_features_dim": edge_attr.shape[1],
        "target_dim": Y.shape[1],
        "node_to_idx": node_to_idx,
        "idx_to_node": {idx: nid for nid, idx in node_to_idx.items()},
        "df_edges": df_edges,
        "df_nodes": df_nodes
    }

    return data, metadata


if __name__ == "__main__":
    base_dir = Path(__file__).resolve().parent.parent
    nodes_csv = base_dir / "data" / "nodes.csv"
    edges_csv = base_dir / "data" / "edges.csv"

    data, meta = build_pyg_graph(str(nodes_csv), str(edges_csv))
    print("=== PyTorch Geometric Graph Loader Verification ===")
    print(f"Nodes Tensor X:       {data.x.shape} (dtype={data.x.dtype})")
    print(f"Edge Index E:         {data.edge_index.shape} (dtype={data.edge_index.dtype})")
    print(f"Edge Attributes E_att: {data.edge_attr.shape} (dtype={data.edge_attr.dtype})")
    print(f"Target Y:             {data.y.shape} (mean={data.y.mean().item():.2f}, min={data.y.min().item():.2f}, max={data.y.max().item():.2f})")
    print(f"Train Mask Count:     {data.train_mask.sum().item()} edges ({data.train_mask.sum().item()/len(data.y)*100:.1f}%)")
    print(f"Val Mask Count:       {data.val_mask.sum().item()} edges ({data.val_mask.sum().item()/len(data.y)*100:.1f}%)")
    print(f"Test Mask Count:      {data.test_mask.sum().item()} edges ({data.test_mask.sum().item()/len(data.y)*100:.1f}%)")
