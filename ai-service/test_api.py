"""
SafeTour AI - API Integration Test Suite
-----------------------------------------
Validates all Flask API endpoints using the Flask test client:
  1. GET  /health
  2. GET  /api/v1/network-summary
  3. POST /api/v1/predict-segment (by node IDs and coordinates)
  4. POST /api/v1/evaluate-route (waypoint route safety evaluation)
  5. POST /api/v1/simulate-hazard (dynamic flood/block re-scoring)
"""

import json
from app import app


def run_api_tests():
    client = app.test_client()

    print("=== SafeTour AI: API Endpoint Integration Tests ===\n")

    # 1. Health Endpoint
    print("[1] Testing GET /health...")
    resp = client.get("/health")
    assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
    health_data = resp.get_json()
    print("    Status:", health_data["status"])
    print("    Cached segments:", health_data["cached_segments"])
    print("    Nodes / Edges:", health_data["graph_statistics"])
    print("    [PASS]\n")

    # 2. Network Summary Endpoint
    print("[2] Testing GET /api/v1/network-summary...")
    resp = client.get("/api/v1/network-summary")
    assert resp.status_code == 200
    summary = resp.get_json()
    print("    Study area:", summary["study_area"])
    print("    Mean safety score:", f"{summary['safety_statistics']['mean_score']:.2f}")
    print("    Safety score range:", f"[{summary['safety_statistics']['min_score']:.2f}, {summary['safety_statistics']['max_score']:.2f}]")
    print("    Road types:", list(summary["road_type_distribution"].keys()))
    print("    [PASS]\n")

    # 3. Predict Single Segment (by node IDs)
    print("[3] Testing POST /api/v1/predict-segment (by node IDs)...")
    payload = {"u": 245584143, "v": 3555409596}
    resp = client.post("/api/v1/predict-segment", json=payload)
    assert resp.status_code == 200
    seg_data = resp.get_json()
    print("    Road segment:", f"{seg_data['source_node']} -> {seg_data['target_node']}")
    print("    Road type:", seg_data["road_type"])
    print("    Length:", f"{seg_data['length_meters']:.1f}m")
    print("    Safety Score:", seg_data["safety_score"], f"({seg_data['safety_rating']})")
    print("    Color code:", seg_data["color_code"])
    print("    Hazards:", seg_data["hazards"])
    print("    [PASS]\n")

    # 4. Predict Single Segment (by coordinates)
    print("[4] Testing POST /api/v1/predict-segment (by GPS coordinates)...")
    coord_payload = {"start_lat": 9.5680, "start_lng": 77.6740, "end_lat": 9.5685, "end_lng": 77.6745}
    resp = client.post("/api/v1/predict-segment", json=coord_payload)
    assert resp.status_code == 200
    coord_seg = resp.get_json()
    print("    Matched segment ID:", coord_seg["edge_id"])
    print("    Road type:", coord_seg["road_type"])
    print("    Safety score:", coord_seg["safety_score"], f"({coord_seg['safety_rating']})")
    print("    [PASS]\n")

    # 5. Route Safety Evaluation
    print("[5] Testing POST /api/v1/evaluate-route (waypoint route)...")
    route_payload = {
        "coordinates": [
            {"lat": 9.5680, "lng": 77.6740},
            {"lat": 9.5690, "lng": 77.6750},
            {"lat": 9.5700, "lng": 77.6760},
            {"lat": 9.5710, "lng": 77.6770}
        ]
    }
    resp = client.post("/api/v1/evaluate-route", json=route_payload)
    assert resp.status_code == 200
    route_data = resp.get_json()
    print("    Overall Route Safety:", route_data["overall_safety_score"], f"({route_data['overall_rating']})")
    print("    Total distance:", f"{route_data['total_distance_meters']}m")
    print("    Evaluated segments count:", route_data["evaluated_segments_count"])
    print("    Danger alerts count:", route_data["danger_alerts_count"])
    print("    [PASS]\n")

    # 6. Dynamic Hazard Simulation
    print("[6] Testing POST /api/v1/simulate-hazard (flood surge simulation)...")
    sim_payload = {"edge_id": 0, "flood_risk": 95.0}
    resp = client.post("/api/v1/simulate-hazard", json=sim_payload)
    assert resp.status_code == 200
    sim_data = resp.get_json()
    print("    Original safety score:", sim_data["original_safety_score"])
    print("    Simulated safety score:", sim_data["simulated_safety_score"])
    print("    Safety delta:", sim_data["delta"])
    print("    New rating:", sim_data["new_rating"])
    print("    [PASS]\n")

    print("=" * 60)
    print("ALL 6 API ENDPOINT TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)


if __name__ == "__main__":
    run_api_tests()
