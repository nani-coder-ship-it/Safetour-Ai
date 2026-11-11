"""
SafeTour AI - Shortest vs. Safest Route Comparison Experiment
--------------------------------------------------------------
Evaluates the trade-off between traveling via the shortest route (distance-optimized)
and the safest route (GAT-derived risk-optimized) across 30 distinct Origin-Destination
pairs on the real OpenStreetMap road network graph of Krishnankoil / Srivilliputtur corridor.

Methodology:
  1. Edge Safety Scores: Predicted by the trained Edge-Conditioned GATv2 model (0-100 scale).
  2. Edge Risk Scores: risk_score(e) = 100.0 - safety_score(e).
  3. Shortest Route: Dijkstra on graph topology minimizing total distance L_e (meters).
  4. Safest Route: Dijkstra on graph topology minimizing cumulative risk score sum(risk_score(e)).
  5. Metrics Recorded for each OD pair:
     - Shortest Route: Distance (m), Cumulative Risk (sum of segment risk scores), Mean Safety Score.
     - Safest Route: Distance (m), Cumulative Risk (sum of segment risk scores), Mean Safety Score.
     - Percentage Distance Increase: (Dist_safest - Dist_shortest) / Dist_shortest * 100%
     - Percentage Risk Reduction: (Risk_shortest - Risk_safest) / Risk_shortest * 100%

Outputs:
  - ai-service/data/route_comparison_results.csv
  - ai-service/data/route_comparison_summary.json
  - root route_comparison_results.csv & route_comparison_summary.json
"""

import os
import sys
import json
import time
import shutil
from pathlib import Path
import numpy as np
import pandas as pd
import networkx as nx
import torch

# Ensure package root is in sys.path
script_dir = Path(__file__).resolve().parent
base_dir = script_dir.parent
repo_root = base_dir.parent
if str(base_dir) not in sys.path:
    sys.path.insert(0, str(base_dir))

from models.dataset import build_pyg_graph
from models.gat_model import RoadSafetyGAT


def load_gat_model_and_predict_safety():
    """
    Loads nodes.csv, edges.csv, builds PyG tensors, loads the trained GAT checkpoint,
    and runs batch inference to compute safety scores for all edges.
    """
    nodes_csv = base_dir / "data" / "nodes.csv"
    edges_csv = base_dir / "data" / "edges.csv"
    ckpt_path = base_dir / "models" / "checkpoints" / "best_gat_model.pt"

    print("[*] Loading road graph tensors...")
    data, meta = build_pyg_graph(str(nodes_csv), str(edges_csv), seed=42)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    data = data.to(device)

    print(f"[*] Loading trained GATv2 checkpoint from: {ckpt_path.name}")
    ckpt = torch.load(str(ckpt_path), map_location=device, weights_only=False)
    model = RoadSafetyGAT(
        node_in_dim=data.x.shape[1],
        edge_in_dim=data.edge_attr.shape[1],
        hidden_dim=ckpt.get("metadata", {}).get("hidden_dim", 64),
        num_heads=ckpt.get("metadata", {}).get("num_heads", 4),
        num_layers=2
    ).to(device)
    model.load_state_dict(ckpt["model_state_dict"])
    model.eval()

    print("[*] Performing full-network safety scoring with GATv2...")
    with torch.no_grad():
        pred_safety = model(data.x, data.edge_index, data.edge_attr)
        safety_scores = pred_safety.cpu().numpy().flatten()

    df_edges = meta["df_edges"].copy()
    df_nodes = meta["df_nodes"].copy()

    df_edges["gat_safety_score"] = safety_scores
    # Edge risk score is the complement of safety score: risk in [0, 100]
    df_edges["gat_risk_score"] = 100.0 - safety_scores
    # Length-weighted risk exposure
    df_edges["risk_exposure_cost"] = df_edges["length"] * df_edges["gat_risk_score"]

    print(f"[OK] Inferred safety scores for {len(df_edges):,} road segments.")
    print(f"     Safety Score: mean={safety_scores.mean():.2f}, min={safety_scores.min():.2f}, max={safety_scores.max():.2f}")
    print(f"     Risk Score:   mean={(100.0 - safety_scores).mean():.2f}, min={(100.0 - safety_scores).min():.2f}, max={(100.0 - safety_scores).max():.2f}")

    return df_nodes, df_edges


def build_routing_graph(df_nodes, df_edges):
    """
    Constructs a directed graph with edge attributes for shortest and safest routing.
    """
    print("[*] Constructing directed routing graph...")
    G = nx.MultiDiGraph()

    for row in df_nodes.itertuples():
        G.add_node(int(row.node_id), lat=float(row.lat), lng=float(row.lng))

    for row in df_edges.itertuples():
        u = int(row.u)
        v = int(row.v)
        k = int(row.key)
        length = float(row.length)
        safety = float(row.gat_safety_score)
        risk = float(row.gat_risk_score)
        risk_cost = float(row.risk_exposure_cost)

        G.add_edge(
            u, v, key=k,
            length=length,
            safety=safety,
            risk=risk,
            risk_cost=risk_cost
        )

    print(f"[OK] Routing graph ready: {G.number_of_nodes():,} nodes, {G.number_of_edges():,} edges.")
    return G


def compute_path_metrics(G, node_path, weight_attr="length"):
    """
    Given a node sequence [n0, n1, ...], resolves multi-edges by weight_attr
    and computes:
      - total_distance (m)
      - cumulative_risk (sum of segment risk scores)
      - cumulative_risk_exposure (sum of length * risk)
      - mean_risk (length-weighted)
      - mean_safety (100 - mean_risk)
    """
    total_distance = 0.0
    cumulative_risk = 0.0
    cumulative_risk_exposure = 0.0

    for i in range(len(node_path) - 1):
        u = node_path[i]
        v = node_path[i + 1]
        edges = G[u][v]

        best_k = min(edges.keys(), key=lambda k: edges[k][weight_attr])
        edge_data = edges[best_k]

        length = edge_data["length"]
        risk = edge_data["risk"]

        total_distance += length
        cumulative_risk += risk
        cumulative_risk_exposure += (length * risk)

    mean_risk = cumulative_risk_exposure / max(1.0, total_distance)
    mean_safety = 100.0 - mean_risk
    segment_count = len(node_path) - 1

    return {
        "distance_m": total_distance,
        "cumulative_risk": cumulative_risk,
        "risk_exposure": cumulative_risk_exposure,
        "mean_risk": mean_risk,
        "mean_safety": mean_safety,
        "segment_count": segment_count
    }


def sample_diverse_od_pairs(G, df_nodes, num_pairs=30, min_dist_m=800.0, max_dist_m=10000.0, seed=42):
    """
    Samples valid, diverse OD pairs from the largest strongly connected component
    ensuring unique origin and destination nodes across different network zones.
    """
    sccs = list(nx.strongly_connected_components(G))
    largest_scc = list(max(sccs, key=len))
    print(f"[*] Sampling diverse OD pairs from largest SCC ({len(largest_scc):,} nodes)...")

    rng = np.random.default_rng(seed)
    node_dict = df_nodes.set_index("node_id")[["lat", "lng"]].to_dict(orient="index")
    lat_mean = df_nodes["lat"].mean()
    cos_f = np.cos(np.radians(lat_mean))

    valid_pairs = []
    used_origins = set()
    used_destinations = set()

    for _ in range(10000):
        o = int(rng.choice(largest_scc))
        d = int(rng.choice(largest_scc))

        if o == d or o in used_origins or d in used_destinations:
            continue

        o_lat, o_lng = node_dict[o]["lat"], node_dict[o]["lng"]
        d_lat, d_lng = node_dict[d]["lat"], node_dict[d]["lng"]

        dy = (d_lat - o_lat) * 111000.0
        dx = (d_lng - o_lng) * 111000.0 * cos_f
        straight_dist = np.sqrt(dx * dx + dy * dy)

        if straight_dist < min_dist_m or straight_dist > max_dist_m:
            continue

        try:
            p_short = nx.shortest_path(G, source=o, target=d, weight="length")
            p_safe = nx.shortest_path(G, source=o, target=d, weight="risk")
        except (nx.NetworkXNoPath, nx.NodeNotFound):
            continue

        valid_pairs.append({
            "origin": o,
            "dest": d,
            "o_lat": o_lat,
            "o_lng": o_lng,
            "d_lat": d_lat,
            "d_lng": d_lng,
            "straight_dist_m": straight_dist,
            "p_short": p_short,
            "p_safe": p_safe
        })
        used_origins.add(o)
        used_destinations.add(d)

        if len(valid_pairs) >= num_pairs:
            break

    print(f"[OK] Successfully sampled {len(valid_pairs)} distinct OD pairs (distance: {min_dist_m}m - {max_dist_m}m).")
    return valid_pairs


def run_route_comparison_experiment():
    print("=" * 84)
    print("SAFETOUR AI - ROUTE OPTIMIZATION EXPERIMENT: SHORTEST VS. SAFEST ROUTES")
    print("=" * 84)

    # 1. Load GAT and predict safety/risk scores
    df_nodes, df_edges = load_gat_model_and_predict_safety()

    # 2. Build graph
    G = build_routing_graph(df_nodes, df_edges)

    # 3. Sample 30 diverse OD pairs
    num_target_pairs = 30
    od_pairs = sample_diverse_od_pairs(G, df_nodes, num_pairs=num_target_pairs, min_dist_m=800.0, max_dist_m=10000.0, seed=42)

    # 4. Evaluate each pair
    records = []
    print(f"\n[*] Evaluating {len(od_pairs)} Origin-Destination pairs...")

    for i, pair in enumerate(od_pairs, start=1):
        origin = pair["origin"]
        dest = pair["dest"]
        p_short = pair["p_short"]
        p_safe = pair["p_safe"]

        short_m = compute_path_metrics(G, p_short, weight_attr="length")
        safe_m = compute_path_metrics(G, p_safe, weight_attr="risk")

        dist_diff_m = safe_m["distance_m"] - short_m["distance_m"]
        dist_inc_pct = (dist_diff_m / max(1.0, short_m["distance_m"])) * 100.0

        risk_reduction = short_m["cumulative_risk"] - safe_m["cumulative_risk"]
        risk_red_pct = (risk_reduction / max(1e-5, short_m["cumulative_risk"])) * 100.0

        safety_score_gain = safe_m["mean_safety"] - short_m["mean_safety"]
        is_detour = (p_short != p_safe)

        rec = {
            "pair_id": i,
            "origin_node_id": origin,
            "destination_node_id": dest,
            "origin_lat": round(pair["o_lat"], 5),
            "origin_lng": round(pair["o_lng"], 5),
            "dest_lat": round(pair["d_lat"], 5),
            "dest_lng": round(pair["d_lng"], 5),
            "straight_line_dist_m": round(pair["straight_dist_m"], 1),
            "shortest_distance_m": round(short_m["distance_m"], 2),
            "shortest_segments": short_m["segment_count"],
            "shortest_cumulative_risk": round(short_m["cumulative_risk"], 2),
            "shortest_mean_safety": round(short_m["mean_safety"], 2),
            "safest_distance_m": round(safe_m["distance_m"], 2),
            "safest_segments": safe_m["segment_count"],
            "safest_cumulative_risk": round(safe_m["cumulative_risk"], 2),
            "safest_mean_safety": round(safe_m["mean_safety"], 2),
            "distance_increase_m": round(dist_diff_m, 2),
            "distance_increase_pct": round(dist_inc_pct, 2),
            "cumulative_risk_reduction": round(risk_reduction, 2),
            "cumulative_risk_reduction_pct": round(risk_red_pct, 2),
            "safety_gain_points": round(safety_score_gain, 2),
            "took_safer_detour": is_detour
        }
        records.append(rec)

    df_results = pd.DataFrame(records)

    # 5. Compute Aggregate Summary Metrics
    avg_dist_short = df_results["shortest_distance_m"].mean()
    avg_dist_safe = df_results["safest_distance_m"].mean()
    avg_dist_increase_pct = df_results["distance_increase_pct"].mean()
    avg_dist_increase_m = df_results["distance_increase_m"].mean()

    avg_risk_short = df_results["shortest_cumulative_risk"].mean()
    avg_risk_safe = df_results["safest_cumulative_risk"].mean()
    avg_risk_reduction = df_results["cumulative_risk_reduction"].mean()
    avg_risk_reduction_pct = df_results["cumulative_risk_reduction_pct"].mean()

    avg_safety_short = df_results["shortest_mean_safety"].mean()
    avg_safety_safe = df_results["safest_mean_safety"].mean()
    avg_safety_gain_points = df_results["safety_gain_points"].mean()
    pct_detour = (df_results["took_safer_detour"].sum() / len(df_results)) * 100.0

    summary = {
        "experiment_name": "SafeTour AI Shortest vs. Safest Route Comparison Benchmark",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "valid_od_pairs_evaluated": int(len(df_results)),
        "metrics_summary": {
            "avg_shortest_distance_m": round(float(avg_dist_short), 2),
            "avg_safest_distance_m": round(float(avg_dist_safe), 2),
            "avg_distance_increase_m": round(float(avg_dist_increase_m), 2),
            "avg_distance_increase_pct": round(float(avg_dist_increase_pct), 2),
            "avg_shortest_cumulative_risk": round(float(avg_risk_short), 2),
            "avg_safest_cumulative_risk": round(float(avg_risk_safe), 2),
            "avg_cumulative_risk_reduction": round(float(avg_risk_reduction), 2),
            "avg_cumulative_risk_reduction_pct": round(float(avg_risk_reduction_pct), 2),
            "avg_shortest_mean_safety": round(float(avg_safety_short), 2),
            "avg_safest_mean_safety": round(float(avg_safety_safe), 2),
            "avg_safety_score_gain_points": round(float(avg_safety_gain_points), 2),
            "routes_taking_safer_detour_pct": round(float(pct_detour), 1)
        },
        "risk_calculation_methodology": {
            "safety_score_source": "Edge-Conditioned Multi-Head GATv2 model predictions (0 to 100 scale)",
            "segment_risk_score": "risk(e) = 100.0 - safety(e)",
            "shortest_path_cost": "cost_short(e) = length(e) in meters (minimizes physical distance)",
            "safest_path_cost": "cost_safe(e) = risk(e) (minimizes cumulative segment risk along the route)",
            "cumulative_risk_formula": "Cumulative Risk = sum_{e in path} risk(e)",
            "distance_increase_formula": "Distance Increase (%) = (Dist_safest - Dist_shortest) / Dist_shortest * 100%",
            "risk_reduction_formula": "Risk Reduction (%) = (Risk_shortest - Risk_safest) / Risk_shortest * 100%"
        }
    }

    # 6. Save Output Files
    out_csv_path1 = base_dir / "data" / "route_comparison_results.csv"
    out_json_path1 = base_dir / "data" / "route_comparison_summary.json"
    out_csv_path2 = repo_root / "route_comparison_results.csv"
    out_json_path2 = repo_root / "route_comparison_summary.json"

    df_results.to_csv(out_csv_path1, index=False)
    with open(out_json_path1, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    shutil.copyfile(out_csv_path1, out_csv_path2)
    shutil.copyfile(out_json_path1, out_json_path2)

    print(f"\n[OK] Saved individual results to:\n     - {out_csv_path1}\n     - {out_csv_path2}")
    print(f"[OK] Saved summary metrics to:\n     - {out_json_path1}\n     - {out_json_path2}")

    # 7. Print Terminal Summary Report
    print("\n" + "=" * 84)
    print("ROUTE COMPARISON EXPERIMENT SUMMARY RESULTS")
    print("=" * 84)
    print(f"  * Valid Origin-Destination Pairs Evaluated:   {len(df_results)}")
    print(f"  * Routes Taking Safer Detours:                {pct_detour:.1f}% ({df_results['took_safer_detour'].sum()} of {len(df_results)})")
    print(f"  * Average Shortest Route Distance:            {avg_dist_short:.1f} m")
    print(f"  * Average Safest Route Distance:              {avg_dist_safe:.1f} m")
    print(f"  * Average Distance Increase:                  +{avg_dist_increase_pct:.2f}% (+{avg_dist_increase_m:.1f} m)")
    print(f"  * Average Shortest Cumulative Risk:           {avg_risk_short:.1f}")
    print(f"  * Average Safest Cumulative Risk:             {avg_risk_safe:.1f}")
    print(f"  * Average Cumulative Risk Reduction:          -{avg_risk_reduction_pct:.2f}% (-{avg_risk_reduction:.1f} risk units)")
    print(f"  * Average Route Safety Score Gain:            +{avg_safety_gain_points:.2f} points")
    print("=" * 84)

    # Print first 10 sample results
    print("\nSAMPLE RESULTS (First 10 Diverse OD Pairs):")
    cols_to_print = [
        "pair_id", "shortest_distance_m", "safest_distance_m",
        "distance_increase_pct", "shortest_cumulative_risk",
        "safest_cumulative_risk", "cumulative_risk_reduction_pct"
    ]
    print(df_results[cols_to_print].head(10).to_string(index=False))
    print("=" * 84 + "\n")

    return df_results, summary


if __name__ == "__main__":
    run_route_comparison_experiment()
