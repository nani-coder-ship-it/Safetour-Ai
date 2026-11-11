"""
SafeTour AI - Real-time AI Inference Microservice (Flask)
---------------------------------------------------------
Serves the Graph Attention Network (GATv2) model for real-time road segment
safety evaluation and navigation route safety scoring.

Endpoints:
  GET  /health                   - Service health & model status
  GET  /api/v1/network-summary   - Road network bounds and statistical summary
  POST /api/v1/predict-segment   - Predict safety score for a single road segment
  POST /api/v1/evaluate-route    - Evaluate an entire GPS waypoint route for safety
  POST /api/v1/simulate-hazard   - Simulate hazard changes (flood, road-block) on-the-fly
"""

import os
import sys
import json
import warnings
# Silence PyTorch 2.4+ internal JIT deprecation warnings triggered by torch_geometric
warnings.filterwarnings("ignore", category=FutureWarning, module="torch.jit")
from pathlib import Path
import numpy as np
import pandas as pd
try:
    import torch
    from models.dataset import build_pyg_graph
    from models.gat_model import RoadSafetyGAT
    TORCH_AVAILABLE = True
except Exception as _e:
    print(f"[!] Warning: PyTorch could not be loaded ({_e}).")
    print("[*] Running in Graph & Spatial Road Safety Engine Mode (using real OSM road network & hazard metrics).")
    torch = None
    build_pyg_graph = None
    RoadSafetyGAT = None
    TORCH_AVAILABLE = False
from flask import Flask, request, jsonify
from flask_cors import CORS
from scipy.spatial import cKDTree

# Configure paths
BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

app = Flask(__name__)
CORS(app)

# Global State Container
MODEL_STATE = {
    "model": None,
    "data": None,
    "meta": None,
    "device": None,
    "node_tree": None,
    "edge_tree": None,
    "node_coords": None,
    "edge_midpoints": None,
    "precomputed_safety": None,
    "df_edges": None,
    "df_nodes": None,
    "cos_factor": 1.0
}


def get_safety_rating(score):
    """Categorizes numeric safety score (0-100) into a qualitative rating."""
    if score >= 80.0:
        return "VERY_SAFE", "Green", "Low risk segment with favorable road hierarchy and low crime/accident history."
    elif score >= 70.0:
        return "SAFE", "LightGreen", "Generally safe route with standard suburban infrastructure."
    elif score >= 55.0:
        return "MODERATE_RISK", "Amber", "Exercise caution; moderate accident vulnerability or reduced lighting."
    else:
        return "HIGH_RISK", "Red", "High hazard road segment! Elevated accident history or flood vulnerability."


def initialize_service():
    """Initializes and pre-computes inference components at startup."""
    print("[*] Initializing SafeTour AI Inference Service...")

    nodes_csv = BASE_DIR / "data" / "nodes.csv"
    edges_csv = BASE_DIR / "data" / "edges.csv"
    checkpoint_path = BASE_DIR / "models" / "checkpoints" / "best_gat_model.pt"

    if not nodes_csv.exists() or not edges_csv.exists():
        raise FileNotFoundError(f"Featured CSVs not found in {BASE_DIR / 'data'}. Run build_features.py first.")

    df_nodes = pd.read_csv(nodes_csv)
    df_edges = pd.read_csv(edges_csv)
    MODEL_STATE["df_edges"] = df_edges
    MODEL_STATE["df_nodes"] = df_nodes

    # Spatial cKDTree for Node Queries
    node_coords = np.column_stack([df_nodes["lat"].values, df_nodes["lng"].values])
    lat_mean = np.mean(node_coords[:, 0])
    cos_factor = float(np.cos(np.radians(lat_mean)))

    # Metric projection for fast Euclidean nearest neighbor
    node_xy = np.column_stack([node_coords[:, 0] * 111000.0, node_coords[:, 1] * 111000.0 * cos_factor])
    MODEL_STATE["node_tree"] = cKDTree(node_xy)
    MODEL_STATE["node_coords"] = node_coords
    MODEL_STATE["cos_factor"] = cos_factor

    # Spatial cKDTree for Edge Midpoints
    u_map = df_nodes.set_index("node_id")["lat"]
    v_map = df_nodes.set_index("node_id")["lng"]
    u_lats = df_edges["u"].map(u_map).values
    u_lngs = df_edges["u"].map(v_map).values
    v_lats = df_edges["v"].map(u_map).values
    v_lngs = df_edges["v"].map(v_map).values

    mid_lats = (u_lats + v_lats) / 2.0
    mid_lngs = (u_lngs + v_lngs) / 2.0
    edge_midpoints = np.column_stack([mid_lats, mid_lngs])
    edge_xy = np.column_stack([mid_lats * 111000.0, mid_lngs * 111000.0 * cos_factor])
    MODEL_STATE["edge_tree"] = cKDTree(edge_xy)
    MODEL_STATE["edge_midpoints"] = edge_midpoints
    MODEL_STATE["meta"] = {
        "num_nodes": len(df_nodes),
        "num_edges": len(df_edges)
    }

    # If PyTorch is available, initialize full GATv2 model
    if TORCH_AVAILABLE and torch is not None:
        try:
            device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
            MODEL_STATE["device"] = str(device)

            data, meta = build_pyg_graph(str(nodes_csv), str(edges_csv))
            data = data.to(device)
            MODEL_STATE["data"] = data
            MODEL_STATE["meta"] = meta
            MODEL_STATE["df_edges"] = meta["df_edges"]
            MODEL_STATE["df_nodes"] = meta["df_nodes"]

            model = RoadSafetyGAT(
                node_in_dim=data.x.shape[1],
                edge_in_dim=data.edge_attr.shape[1],
                hidden_dim=64,
                num_heads=4,
                num_layers=2
            ).to(device)

            if checkpoint_path.exists():
                print(f"[*] Loading trained GATv2 weights from: {checkpoint_path.name}")
                checkpoint = torch.load(str(checkpoint_path), map_location=device, weights_only=False)
                model.load_state_dict(checkpoint["model_state_dict"])
            else:
                print("[!] Warning: Checkpoint not found, using untrained model initialization.")

            model.eval()
            MODEL_STATE["model"] = model

            with torch.no_grad():
                pred_safety = model(data.x, data.edge_index, data.edge_attr)
                scores = pred_safety.cpu().numpy().flatten()
                MODEL_STATE["precomputed_safety"] = scores

            print(f"[OK] GATv2 Neural Inference Service initialized! {len(scores):,} road segments cached on {device}.")
            return
        except Exception as e:
            print(f"[!] PyTorch model initialization error: {e}. Falling back to Topological Safety Scorer.")

    # Resilient Spatial Road Safety Scoring Engine using real OSM attributes
    MODEL_STATE["device"] = "CPU (Topological Spatial Safety Engine)"
    acc = df_edges["accident_risk"].fillna(20.0).values
    crm = df_edges["crime_score"].fillna(20.0).values
    fld = df_edges["flood_risk"].fillna(15.0).values
    blk = df_edges["road_blocked"].fillna(0).values
    scores = 100.0 - (0.35 * acc + 0.35 * crm + 0.20 * fld + 50.0 * blk)
    scores = np.clip(scores, 15.0, 98.0)
    MODEL_STATE["precomputed_safety"] = scores
    print(f"[OK] SafeTour AI Spatial Road Safety Engine initialized! {len(scores):,} segments loaded from OSM graph.")


@app.route("/health", methods=["GET"])
@app.route("/api/v1/health", methods=["GET"])
def health_check():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "service": "SafeTour AI - GAT Road Safety Service",
        "version": "1.0.0",
        "device": str(MODEL_STATE["device"]),
        "graph_statistics": {
            "nodes": int(MODEL_STATE["meta"]["num_nodes"]),
            "edges": int(MODEL_STATE["meta"]["num_edges"])
        },
        "model_architecture": "Edge-Conditioned Multi-Head GATv2",
        "cached_segments": len(MODEL_STATE["precomputed_safety"]) if MODEL_STATE["precomputed_safety"] is not None else 0
    }), 200


@app.route("/api/v1/network-summary", methods=["GET"])
def network_summary():
    """Returns geographical coverage and statistical summary of the road network."""
    df_nodes = MODEL_STATE["df_nodes"]
    df_edges = MODEL_STATE["df_edges"]
    scores = MODEL_STATE["precomputed_safety"]

    return jsonify({
        "study_area": "Krishnankoil - Srivilliputtur Corridor, Tamil Nadu",
        "bounding_box": {
            "min_latitude": float(df_nodes["lat"].min()),
            "max_latitude": float(df_nodes["lat"].max()),
            "min_longitude": float(df_nodes["lng"].min()),
            "max_longitude": float(df_nodes["lng"].max())
        },
        "center": {
            "latitude": float(df_nodes["lat"].mean()),
            "longitude": float(df_nodes["lng"].mean())
        },
        "road_type_distribution": df_edges["road_type"].value_counts().to_dict(),
        "safety_statistics": {
            "mean_score": float(np.mean(scores)),
            "min_score": float(np.min(scores)),
            "max_score": float(np.max(scores)),
            "standard_deviation": float(np.std(scores))
        }
    }), 200


@app.route("/api/v1/predict-segment", methods=["POST"])
def predict_segment():
    """
    Predicts the safety score for a single road segment.
    Accepts:
      - Option A: {"u": 245584143, "v": 3555409287}
      - Option B: {"start_lat": 9.5078, "start_lng": 77.6333, "end_lat": 9.5085, "end_lng": 77.6340}
    """
    payload = request.get_json(force=True, silent=True) or {}
    df_edges = MODEL_STATE["df_edges"]
    scores = MODEL_STATE["precomputed_safety"]

    edge_idx = None

    if "u" in payload and "v" in payload:
        u, v = int(payload["u"]), int(payload["v"])
        matches = df_edges.index[(df_edges["u"] == u) & (df_edges["v"] == v)].tolist()
        if matches:
            edge_idx = matches[0]

    elif "start_lat" in payload and "start_lng" in payload:
        slat = float(payload["start_lat"])
        slng = float(payload["start_lng"])
        cos_f = MODEL_STATE["cos_factor"]
        q_xy = np.array([[slat * 111000.0, slng * 111000.0 * cos_f]])
        dist, edge_idx = MODEL_STATE["edge_tree"].query(q_xy)
        edge_idx = int(edge_idx[0])

    if edge_idx is None or edge_idx >= len(scores):
        return jsonify({"error": "Road segment not found in network graph"}), 404

    row = df_edges.iloc[edge_idx]
    score = float(scores[edge_idx])
    rating, color, desc = get_safety_rating(score)

    return jsonify({
        "edge_id": edge_idx,
        "source_node": int(row["u"]),
        "target_node": int(row["v"]),
        "road_type": str(row["road_type"]),
        "length_meters": float(row["length"]),
        "safety_score": round(score, 2),
        "safety_rating": rating,
        "color_code": color,
        "description": desc,
        "hazards": {
            "accident_risk": float(row["accident_risk"]),
            "crime_score": float(row["crime_score"]),
            "flood_risk": float(row["flood_risk"]),
            "tourist_density": float(row["tourist_density"])
        }
    }), 200


@app.route("/api/v1/evaluate-route", methods=["POST"])
def evaluate_route():
    """
    Evaluates an entire travel route (list of GPS points) and produces:
      - Overall route safety index (length-weighted)
      - Segment-by-segment breakdown
      - Danger hotspots and cautionary alerts
    Expected JSON:
      {
        "coordinates": [
          {"lat": 9.568, "lng": 77.674},
          {"lat": 9.569, "lng": 77.675},
          ...
        ]
      }
    """
    payload = request.get_json(force=True, silent=True) or {}
    coords = payload.get("coordinates", [])

    if not coords or len(coords) < 2:
        return jsonify({"error": "Please provide at least 2 coordinate points in 'coordinates'."}), 400

    cos_f = MODEL_STATE["cos_factor"]
    edge_tree = MODEL_STATE["edge_tree"]
    df_edges = MODEL_STATE["df_edges"]
    scores = MODEL_STATE["precomputed_safety"]

    matched_edge_indices = []
    seen_edges = set()

    # Query route points against nearest road segments
    for pt in coords:
        plat, plng = float(pt["lat"]), float(pt["lng"])
        q_xy = np.array([[plat * 111000.0, plng * 111000.0 * cos_f]])
        dist, idx = edge_tree.query(q_xy)
        e_idx = int(idx[0])
        if e_idx not in seen_edges:
            seen_edges.add(e_idx)
            matched_edge_indices.append(e_idx)

    if not matched_edge_indices:
        return jsonify({"error": "Could not map coordinates to known road segments."}), 404

    # Compute length-weighted safety score
    total_length = 0.0
    weighted_score_sum = 0.0
    evaluated_segments = []
    danger_alerts = []

    for idx in matched_edge_indices:
        row = df_edges.iloc[idx]
        score = float(scores[idx])
        length = float(row["length"])
        rating, color, desc = get_safety_rating(score)

        total_length += length
        weighted_score_sum += (score * length)

        seg_info = {
            "edge_id": idx,
            "road_type": str(row["road_type"]),
            "length_meters": round(length, 1),
            "safety_score": round(score, 2),
            "rating": rating,
            "color": color
        }
        evaluated_segments.append(seg_info)

        # Flag cautionary segments (score < 72)
        if score < 72.0:
            danger_alerts.append({
                "edge_id": idx,
                "road_type": str(row["road_type"]),
                "safety_score": round(score, 2),
                "alert": f"Caution on {row['road_type']} segment: elevated accident or lighting vulnerability."
            })

    overall_safety = weighted_score_sum / max(1.0, total_length)
    overall_rating, overall_color, summary_desc = get_safety_rating(overall_safety)

    return jsonify({
        "overall_safety_score": round(overall_safety, 2),
        "overall_rating": overall_rating,
        "color_code": overall_color,
        "summary": summary_desc,
        "total_distance_meters": round(total_length, 1),
        "evaluated_segments_count": len(evaluated_segments),
        "danger_alerts_count": len(danger_alerts),
        "danger_alerts": danger_alerts,
        "segments": evaluated_segments
    }), 200


@app.route("/api/v1/simulate-hazard", methods=["POST"])
def simulate_hazard():
    """
    Simulates a dynamic hazard change (e.g., road block or flood surge)
    and re-runs GAT forward pass to return real-time updated safety scores.
    Expected JSON:
      {
        "edge_id": 0,
        "flood_risk": 90.0,
        "road_blocked": 1
      }
    """
    payload = request.get_json(force=True, silent=True) or {}
    edge_id = payload.get("edge_id")

    if edge_id is None or edge_id >= len(MODEL_STATE["df_edges"]):
        return jsonify({"error": "Invalid edge_id provided."}), 400

    if MODEL_STATE["model"] is not None and torch is not None and MODEL_STATE["data"] is not None:
        data = MODEL_STATE["data"]
        model = MODEL_STATE["model"]
        sim_edge_attr = data.edge_attr.clone()

        if "flood_risk" in payload:
            sim_edge_attr[edge_id, 12] = float(payload["flood_risk"]) / 100.0
        if "road_blocked" in payload:
            sim_edge_attr[edge_id, 14] = float(payload["road_blocked"])

        with torch.no_grad():
            new_preds = model(data.x, data.edge_index, sim_edge_attr)
            new_score = float(new_preds[edge_id].item())
            old_score = float(MODEL_STATE["precomputed_safety"][edge_id])
    else:
        old_score = float(MODEL_STATE["precomputed_safety"][edge_id])
        flood_delta = (float(payload.get("flood_risk", 0)) / 100.0) * 20.0
        block_delta = float(payload.get("road_blocked", 0)) * 50.0
        new_score = float(np.clip(old_score - (flood_delta + block_delta), 10.0, 99.0))

    rating, color, desc = get_safety_rating(new_score)

    return jsonify({
        "edge_id": edge_id,
        "original_safety_score": round(old_score, 2),
        "simulated_safety_score": round(new_score, 2),
        "delta": round(new_score - old_score, 2),
        "new_rating": rating,
        "color_code": color,
        "description": desc
    }), 200


# Self-initialization on startup
initialize_service()

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    print(f"[*] Starting SafeTour AI service on http://0.0.0.0:{port}")
    app.run(host="0.0.0.0", port=port, debug=False)
