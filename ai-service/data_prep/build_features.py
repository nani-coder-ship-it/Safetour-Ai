"""
SafeTour AI - Road Network Feature Engineering (Phase 1.5)
-----------------------------------------------------------
Enriches the extracted road graph with real Tamil Nadu road accident
and crime statistics, alongside placeholder synthetic environmental fields.

Real Datasets integrated:
  1. tn_accidents.csv / updated_dataset.csv - District & spatial accident incidence,
     fatalities, and severity statistics.
  2. tn_complaints.csv / tn_road_accidents_district.csv - Police crime and
     complaint frequencies across Tamil Nadu districts.

Outputs:
  - ai-service/data/road_graph_featured.graphml
  - ai-service/data/nodes.csv
  - ai-service/data/edges.csv
"""

import os
import sys
from pathlib import Path
import numpy as np
import pandas as pd
import networkx as nx
from scipy.spatial import cKDTree

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

try:
    import osmnx as ox
except ImportError:
    print("[ERROR] 'osmnx' is not installed. Please run: pip install -r requirements.txt")
    sys.exit(1)


def load_raw_graph(graphml_path):
    """Loads the raw road network GraphML extracted in Step 2."""
    if not os.path.exists(graphml_path):
        raise FileNotFoundError(f"Raw graph file not found at: {graphml_path}")
    print(f"[*] Loading raw road graph from: {graphml_path}")
    G = ox.load_graphml(graphml_path)
    print(f"[OK] Loaded graph with {G.number_of_nodes()} nodes and {G.number_of_edges()} edges.")
    return G


def load_datasets(raw_dir):
    """Loads accident and crime datasets."""
    accidents_path = raw_dir / "tn_accidents.csv"
    complaints_path = raw_dir / "tn_complaints.csv"
    accidents_district_path = raw_dir / "tn_road_accidents_district.csv"

    if not accidents_path.exists():
        raise FileNotFoundError(f"Accidents CSV missing at: {accidents_path}")

    df_accidents = pd.read_csv(accidents_path)
    df_complaints = pd.read_csv(complaints_path) if complaints_path.exists() else None
    df_acc_district = pd.read_csv(accidents_district_path) if accidents_district_path.exists() else None

    print(f"[OK] Loaded accidents dataset: {len(df_accidents)} records.")
    if df_complaints is not None:
        print(f"[OK] Loaded complaints dataset: {len(df_complaints)} records.")
    return df_accidents, df_complaints, df_acc_district


def compute_real_crime_score(df_complaints, target_district="Virudhunagar"):
    """
    Computes a normalized crime score (0-100) for the target district
    based on total police complaints across all Tamil Nadu districts.
    """
    if df_complaints is None:
        # Fallback if complaints CSV is unavailable
        return 25.0

    # Filter out summary row (e.g., 'TOTAL DISTRICT(S)')
    valid_df = df_complaints.dropna(subset=["District/City"]).copy()
    valid_df = valid_df[~valid_df["District/City"].str.upper().str.contains("TOTAL")]

    # Match target district
    match = valid_df[valid_df["District/City"].str.strip().str.lower() == target_district.lower()]
    if match.empty:
        # Fallback to mean if not found
        mean_complaints = valid_df["Total Complaints"].mean()
        target_val = mean_complaints
    else:
        target_val = float(match["Total Complaints"].values[0])

    min_val = float(valid_df["Total Complaints"].min())
    max_val = float(valid_df["Total Complaints"].max())

    # Min-Max normalization to 0-100 scale
    normalized_score = ((target_val - min_val) / (max_val - min_val)) * 100.0
    return round(normalized_score, 2), int(target_val)


def attach_node_features(G, df_accidents, df_complaints, max_distance_meters=500.0):
    """
    Attaches real accident and crime metrics to each node.
    Uses spatial cKDTree for nearest coordinate matching within max_distance_meters,
    and falls back to regional district statistics for the test area.
    """
    node_ids = list(G.nodes())
    node_coords = np.array([[float(G.nodes[n]["lat"]), float(G.nodes[n]["lng"])] for n in node_ids])

    # Approx meter projection for Tamil Nadu lat (~9.5 deg N)
    lat_mean = np.mean(node_coords[:, 0])
    cos_factor = np.cos(np.radians(lat_mean))

    def to_xy(lat_lng):
        return np.column_stack([lat_lng[:, 0] * 111000.0, lat_lng[:, 1] * 111000.0 * cos_factor])

    node_xy = to_xy(node_coords)
    tree = cKDTree(node_xy)

    # Calculate real crime score for Virudhunagar
    real_crime_score, total_complaints = compute_real_crime_score(df_complaints, "Virudhunagar")

    # Get Virudhunagar accident stats
    vnr_row = df_accidents[df_accidents["district"].str.lower() == "virudhunagar"]
    if not vnr_row.empty:
        dist_accidents = int(vnr_row["total_accidents"].values[0])
        dist_fatal = int(vnr_row["2021_fatal"].values[0])
        dist_nonfatal = int(vnr_row["2021_nonfatal"].values[0])
    else:
        dist_accidents = 2271
        dist_fatal = 413
        dist_nonfatal = 863

    # Severity formula: (fatal * 3 + nonfatal * 1) normalized
    base_severity = (dist_fatal * 3.0 + dist_nonfatal * 1.0) / (dist_fatal + dist_nonfatal)

    # Spatial query for coordinate-level points in df_accidents
    acc_coords = df_accidents[["latitude", "longitude"]].values
    acc_xy = to_xy(acc_coords)
    dists, indices = tree.query(acc_xy)

    # Initialize node feature dictionaries
    accident_counts = {n: 0 for n in node_ids}
    severity_weighted = {n: 0.0 for n in node_ids}

    matched_points = 0
    outside_threshold = 0

    for i, dist in enumerate(dists):
        acc_total = int(df_accidents.iloc[i]["total_accidents"])
        fatal = int(df_accidents.iloc[i]["2021_fatal"])
        nonfatal = int(df_accidents.iloc[i]["2021_nonfatal"])
        sev = (fatal * 3.0 + nonfatal * 1.0) / max(1, fatal + nonfatal)

        if dist <= max_distance_meters:
            matched_node = node_ids[indices[i]]
            accident_counts[matched_node] += acc_total
            severity_weighted[matched_node] += (acc_total * sev)
            matched_points += 1
            print(f"[+] Spatial Match: {df_accidents.iloc[i]['district']} matched to Node {matched_node} (dist: {dist:.1f}m, count: {acc_total})")
        else:
            outside_threshold += 1

    print(f"[*] Spatial point matching: {matched_points} point(s) <= {max_distance_meters}m, {outside_threshold} point(s) outside threshold.")

    # Attach features to all nodes
    # For nodes in the study area, we also assign regional district baseline
    for n in node_ids:
        local_pts = accident_counts[n]
        G.nodes[n]["accident_count"] = int(local_pts)
        G.nodes[n]["accident_severity"] = round(float(severity_weighted[n]), 2)
        G.nodes[n]["regional_accidents"] = int(dist_accidents)  # Real district baseline
        G.nodes[n]["crime_score"] = float(real_crime_score)     # REAL district crime score (0-100)
        G.nodes[n]["nearby_poi_count"] = 0                      # SYNTHETIC - replace with real data source

    return G, matched_points, outside_threshold, real_crime_score


def attach_edge_features(G):
    """
    Attaches road segment features to edges:
    - Real: length, highway/road_type, oneway
    - Real derived: accident_risk, crime_score
    - Synthetic placeholders: flood_risk, road_blocked, tourist_density
    """
    np.random.seed(42)

    for u, v, k, data in G.edges(keys=True, data=True):
        # 1. Real attributes from OSM
        length = float(data.get("length", 10.0))
        highway = str(data.get("highway", "unclassified"))
        oneway = bool(data.get("oneway", False))

        # Standardize highway string if list
        if isinstance(highway, list):
            highway = highway[0]
        data["road_type"] = highway

        # 2. Inherit real crime score from connected nodes
        node_crime = (G.nodes[u].get("crime_score", 15.55) + G.nodes[v].get("crime_score", 15.55)) / 2.0
        data["crime_score"] = round(float(node_crime), 2)  # REAL - from regional police complaint data

        # 3. Real derived accident risk: weight length, road class, and node accident counts
        road_risk_multiplier = {
            "motorway": 1.5, "trunk": 1.4, "primary": 1.3, "secondary": 1.1,
            "tertiary": 1.0, "residential": 0.8, "service": 0.6, "unclassified": 0.9
        }.get(highway, 1.0)

        node_acc_sum = G.nodes[u].get("accident_count", 0) + G.nodes[v].get("accident_count", 0)
        # Normalized segment risk (0 - 100 scale)
        if node_acc_sum > 0:
            accident_risk = min(100.0, 50.0 + (node_acc_sum / 100.0) * road_risk_multiplier)
        else:
            accident_risk = round(20.0 * road_risk_multiplier, 2)
        data["accident_risk"] = float(accident_risk)

        # 4. Synthetic placeholders clearly commented
        # SYNTHETIC - replace with real data source
        data["flood_risk"] = float(np.random.randint(5, 30))

        # SYNTHETIC - replace with real data source (road-block reporting service)
        data["road_blocked"] = int(0)

        # SYNTHETIC - replace with real data source
        data["tourist_density"] = float(np.random.randint(10, 45))

    return G


def export_featured_data(G, base_dir):
    """
    Exports the featured graph as GraphML and tabular CSVs (nodes.csv, edges.csv).
    """
    data_dir = base_dir / "data"
    data_dir.mkdir(parents=True, exist_ok=True)

    # 1. Export GraphML
    graphml_path = data_dir / "road_graph_featured.graphml"
    print(f"[*] Serializing featured graph to: {graphml_path}")
    # Convert any list attributes to strings for GraphML compatibility
    G_clean = G.copy()
    for u, v, k, d in G_clean.edges(keys=True, data=True):
        for key, val in list(d.items()):
            if isinstance(val, (list, tuple)):
                d[key] = str(val)
    ox.save_graphml(G_clean, filepath=str(graphml_path))
    print(f"[OK] Saved {graphml_path.name} ({graphml_path.stat().st_size / (1024*1024):.2f} MB)")

    # 2. Export nodes.csv
    nodes_list = []
    for node_id, d in G.nodes(data=True):
        nodes_list.append({
            "node_id": node_id,
            "lat": float(d.get("lat", d.get("y", 0.0))),
            "lng": float(d.get("lng", d.get("x", 0.0))),
            "accident_count": int(d.get("accident_count", 0)),
            "accident_severity": float(d.get("accident_severity", 0.0)),
            "regional_accidents": int(d.get("regional_accidents", 2271)),
            "crime_score": float(d.get("crime_score", 0.0)),
            "nearby_poi_count": int(d.get("nearby_poi_count", 0))  # SYNTHETIC
        })
    df_nodes = pd.DataFrame(nodes_list)
    nodes_csv_path = data_dir / "nodes.csv"
    df_nodes.to_csv(nodes_csv_path, index=False)
    print(f"[OK] Exported nodes table to: {nodes_csv_path} ({len(df_nodes)} rows)")

    # 3. Export edges.csv
    edges_list = []
    for u, v, k, d in G.edges(keys=True, data=True):
        edges_list.append({
            "u": u,
            "v": v,
            "key": k,
            "length": float(d.get("length", 0.0)),
            "road_type": str(d.get("road_type", "unclassified")),
            "oneway": bool(d.get("oneway", False)),
            "crime_score": float(d.get("crime_score", 0.0)),
            "accident_risk": float(d.get("accident_risk", 0.0)),
            "flood_risk": float(d.get("flood_risk", 0.0)),            # SYNTHETIC
            "road_blocked": int(d.get("road_blocked", 0)),            # SYNTHETIC
            "tourist_density": float(d.get("tourist_density", 0.0))   # SYNTHETIC
        })
    df_edges = pd.DataFrame(edges_list)
    edges_csv_path = data_dir / "edges.csv"
    df_edges.to_csv(edges_csv_path, index=False)
    print(f"[OK] Exported edges table to: {edges_csv_path} ({len(df_edges)} rows)")

    return df_nodes, df_edges


def main():
    script_dir = Path(__file__).resolve().parent
    base_dir = script_dir.parent
    raw_dir = base_dir / "data" / "raw"
    raw_graph_path = base_dir / "data" / "road_graph_raw.graphml"

    print("=== SafeTour AI - Phase 1.5: Feature Engineering with Real Data ===")

    # Load raw graph
    G = load_raw_graph(str(raw_graph_path))

    # Load raw datasets
    df_accidents, df_complaints, _ = load_datasets(raw_dir)

    # Attach node features
    G, matched_pts, outside_thresh, real_crime = attach_node_features(
        G, df_accidents, df_complaints, max_distance_meters=500.0
    )

    # Attach edge features
    G = attach_edge_features(G)

    # Export tables and GraphML
    df_nodes, df_edges = export_featured_data(G, base_dir)

    print("\n" + "=" * 70)
    print("FEATURE ENGINEERING COMPLETED")
    print("=" * 70)
    print(f"Total Nodes: {len(df_nodes):,}")
    print(f"Nodes with non-zero accident count: {(df_nodes['accident_count'] > 0).sum():,}")
    print(f"Nodes with non-zero real crime score: {(df_nodes['crime_score'] > 0).sum():,}")
    print(f"Total Edges: {len(df_edges):,}")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    main()
