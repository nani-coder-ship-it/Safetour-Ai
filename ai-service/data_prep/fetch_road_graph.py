"""
SafeTour AI - Road Network Graph Extractor
------------------------------------------
Fetches the drivable road network from OpenStreetMap using OSMnx for a specified area
(defaults to Krishnankoil / Srivilliputtur, Tamil Nadu testing area).

Nodes represent intersections with latitude/longitude coordinates.
Edges represent drivable road segments with attributes:
  - length (meters)
  - highway (road type: trunk, primary, secondary, tertiary, residential, etc.)
  - name / ref
  - oneway

Outputs:
  ai-service/data/road_graph_raw.graphml (native OSMnx format for fast reloading)
"""

import os
import sys
import argparse
from pathlib import Path
import requests
import networkx as nx

# Ensure UTF-8 output on Windows consoles if supported
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


# Default bounding box covering Krishnankoil, Kalasalingam University, and Srivilliputtur
# Coordinates: (North, South, East, West)
DEFAULT_BBOX = (9.600, 9.500, 77.700, 77.620)
DEFAULT_PLACE_LABEL = "Krishnankoil - Srivilliputtur Corridor, Tamil Nadu, India"
OSM_API_BASE = "https://api.openstreetmap.org/api/0.6/map"


def download_osm_xml(north, south, east, west, osm_output_path):
    """
    Downloads raw OSM XML directly from the official OpenStreetMap REST API.
    BBox order for OSM API: min_lon (west), min_lat (south), max_lon (east), max_lat (north)
    """
    url = f"{OSM_API_BASE}?bbox={west},{south},{east},{north}"
    headers = {"User-Agent": "SafeTourAI-Research/1.0 (Geospatial Safety Evaluation)"}

    print(f"[*] Requesting OSM XML for bounds: N={north}, S={south}, E={east}, W={west}...")
    print(f"[*] API URL: {url}")

    response = requests.get(url, headers=headers, timeout=60)
    if response.status_code != 200:
        raise RuntimeError(f"OSM API returned HTTP {response.status_code}: {response.text[:200]}")

    content_len_kb = len(response.content) / 1024
    print(f"[OK] Downloaded OSM XML payload ({content_len_kb:.2f} KB).")

    Path(osm_output_path).parent.mkdir(parents=True, exist_ok=True)
    with open(osm_output_path, "wb") as f:
        f.write(response.content)

    return osm_output_path


def fetch_road_graph(bbox=DEFAULT_BBOX, raw_osm_path=None, force_download=False):
    """
    Extracts the drivable road network graph using OSMnx.

    Parameters:
      bbox (tuple): (north, south, east, west)
      raw_osm_path (str): Optional path to cache/load the .osm XML file
      force_download (bool): If True, re-downloads even if cached XML exists

    Returns:
      networkx.MultiDiGraph: Graph of intersections (nodes) and road segments (edges)
    """
    north, south, east, west = bbox

    # Check if cached XML already exists
    if raw_osm_path and os.path.exists(raw_osm_path) and not force_download:
        print(f"[*] Loading cached OSM XML from: {raw_osm_path}")
    else:
        if raw_osm_path is None:
            raw_osm_path = "data/srivilliputtur_corridor.osm"
        download_osm_xml(north, south, east, west, raw_osm_path)

    print("[*] Parsing road network graph via osmnx.graph_from_xml...")
    G = ox.graph_from_xml(raw_osm_path)

    # Ensure node coordinates (x: lon, y: lat) are standardized
    for node_id, data in G.nodes(data=True):
        if "y" in data and "lat" not in data:
            data["lat"] = float(data["y"])
        if "x" in data and "lng" not in data:
            data["lng"] = float(data["x"])

    return G


def inspect_graph(G, area_name=DEFAULT_PLACE_LABEL):
    """
    Prints a detailed inspection of the extracted road graph.
    """
    num_nodes = G.number_of_nodes()
    num_edges = G.number_of_edges()

    print("\n" + "=" * 70)
    print(f"  ROAD GRAPH EXTRACTION REPORT: {area_name}")
    print("=" * 70)
    print(f"  * Total Intersections (Nodes): {num_nodes:,}")
    print(f"  * Total Road Segments (Edges): {num_edges:,}")
    print(f"  * Graph Topology Type:         {type(G).__name__}")
    print(f"  * Directed Graph:              {G.is_directed()}")

    # Sample Node inspection
    sample_node_id = next(iter(G.nodes()))
    sample_node = G.nodes[sample_node_id]
    print(f"\n  [Sample Node / Intersection: ID {sample_node_id}]")
    print(f"    - Latitude (y):  {sample_node.get('y', sample_node.get('lat'))}")
    print(f"    - Longitude (x): {sample_node.get('x', sample_node.get('lng'))}")
    print(f"    - Raw OSM Attributes: {list(sample_node.keys())}")

    # Sample Edge inspection
    sample_u, sample_v, sample_edge = next(iter(G.edges(data=True)))
    print(f"\n  [Sample Road Segment / Edge: {sample_u} -> {sample_v}]")
    print(f"    - Road Type (highway tag): {sample_edge.get('highway')}")
    print(f"    - Segment Length (meters): {sample_edge.get('length'):.2f}m")
    print(f"    - Name / Reference:        {sample_edge.get('name', 'Unnamed')} ({sample_edge.get('ref', 'N/A')})")
    print(f"    - Oneway:                  {sample_edge.get('oneway')}")
    print(f"    - Lanes:                   {sample_edge.get('lanes', 'unspecified')}")
    print("=" * 70 + "\n")


def save_raw_graph(G, output_path):
    """
    Saves the extracted graph in OSMnx's native GraphML format.
    """
    out_dir = Path(output_path).parent
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"[*] Serializing raw graph to GraphML: {output_path}")
    ox.save_graphml(G, filepath=output_path)
    file_size_mb = Path(output_path).stat().st_size / (1024 * 1024)
    print(f"[OK] Graph successfully saved to disk ({file_size_mb:.2f} MB).")


def main():
    parser = argparse.ArgumentParser(description="Fetch drivable road network from OpenStreetMap")
    parser.add_argument("--bbox", type=str, default=None,
                        help="Bounding box: north,south,east,west (default: Krishnankoil/Srivilliputtur)")
    parser.add_argument("--output", type=str, default=None,
                        help="Destination file path (default: data/road_graph_raw.graphml)")
    parser.add_argument("--force", action="store_true",
                        help="Force re-download even if cached OSM file exists")

    args = parser.parse_args()

    # Paths
    script_dir = Path(__file__).resolve().parent
    base_dir = script_dir.parent
    output_path = args.output or str(base_dir / "data" / "road_graph_raw.graphml")
    osm_cache_path = str(base_dir / "data" / "srivilliputtur_corridor.osm")

    bbox = DEFAULT_BBOX
    if args.bbox:
        parts = [float(x.strip()) for x in args.bbox.split(",")]
        bbox = (parts[0], parts[1], parts[2], parts[3])

    print("=== SafeTour AI - Step 2: Road Graph Extraction ===")
    print(f"Study Area: {DEFAULT_PLACE_LABEL}")
    print(f"Bounding Box: North={bbox[0]}, South={bbox[1]}, East={bbox[2]}, West={bbox[3]}")

    # Extract
    G = fetch_road_graph(bbox=bbox, raw_osm_path=osm_cache_path, force_download=args.force)

    # Inspect
    inspect_graph(G)

    # Save
    save_raw_graph(G, output_path)

    # Verify reloading
    print("[*] Validating reloadability from GraphML file...")
    G_reload = ox.load_graphml(output_path)
    print(f"[OK] Validation Passed: Reloaded {G_reload.number_of_nodes()} nodes and {G_reload.number_of_edges()} edges from GraphML.")


if __name__ == "__main__":
    main()
