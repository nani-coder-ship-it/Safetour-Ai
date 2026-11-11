"""
SafeTour AI - System Responsiveness Benchmarking Script
-------------------------------------------------------
Measures actual real-world response times on live backend microservices:
  1. Location-Update to Generated & Returned Alert Latency (POST /api/v1/location).
  2. Nearby Places Latency: Cold Cache vs. Warm Cache (GET /api/v1/poi/nearby).

All timings are recorded using a high-resolution monotonic clock (time.perf_counter).
Outputs:
  - ai-service/data/responsiveness_results.csv
  - ai-service/data/responsiveness_summary.json
"""

import os
import sys
import json
import time
from pathlib import Path
import numpy as np
import pandas as pd
import requests

# Ensure UTF-8 output on Windows
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

BASE_DIR = Path(__file__).resolve().parent
BACKEND_URL = "http://127.0.0.1:5000"
USER_ID = "6a8e69a05ea71d0631882ec6"  # Valid test user in MongoDB

HEADERS = {
    "x-user-id": USER_ID,
    "Content-Type": "application/json"
}

# Real Danger Zones in SafeTour AI (active in MongoDB)
DANGER_ZONES = [
    {"name": "Pilavakkal Dam Deep Reservoir", "lat": 9.6225, "lng": 77.5925},
    {"name": "Ayyanar Falls Flash Flood", "lat": 9.5350, "lng": 77.5475},
    {"name": "Shenbagathoppu Forest Elephant Corridor", "lat": 9.5100, "lng": 77.5700},
    {"name": "Sanjeevi Hills Cliff Edge", "lat": 9.5125, "lng": 77.6165},
    {"name": "Naranapuram Lake Deep Water Hazard", "lat": 9.5950, "lng": 77.7050},
    {"name": "Courtallam Falls Torrential Gorge", "lat": 8.9325, "lng": 77.2725},
    {"name": "Kodaikanal Suicide Point Cliff", "lat": 10.2140, "lng": 77.4900},
    {"name": "Meghamalai Mountain Landslide Corridor", "lat": 9.7100, "lng": 77.4150},
]

# Coordinates for Warm Cache (pre-seeded and populated in MongoDB, count >= 3)
WARM_CACHE_CONFIGS = [
    {"type": "hospital", "lat": 9.5680, "lng": 77.6740, "radius": 10000},
    {"type": "hotel", "lat": 9.5680, "lng": 77.6740, "radius": 10000},
    {"type": "restaurant", "lat": 9.5680, "lng": 77.6740, "radius": 10000},
    {"type": "bus_stop", "lat": 9.5680, "lng": 77.6740, "radius": 10000},
    {"type": "hospital", "lat": 9.5700, "lng": 77.6720, "radius": 10000},
    {"type": "hotel", "lat": 9.5660, "lng": 77.6750, "radius": 10000},
    {"type": "restaurant", "lat": 9.5690, "lng": 77.6730, "radius": 10000},
]

# Coordinates for Cold Cache (fresh geographical coordinates across Tamil Nadu/India without cached entries)
COLD_CACHE_BASE_COORDS = [
    {"lat": 10.7905, "lng": 79.1378}, # Thanjavur
    {"lat": 11.6643, "lng": 78.1460}, # Salem
    {"lat": 10.9601, "lng": 79.3845}, # Kumbakonam
    {"lat": 11.3410, "lng": 77.7172}, # Erode
    {"lat": 12.9165, "lng": 79.1325}, # Vellore
    {"lat": 8.7139, "lng": 77.7567},  # Tirunelveli
    {"lat": 10.3673, "lng": 77.9803}, # Dindigul
    {"lat": 11.7480, "lng": 79.7714}, # Cuddalore
]
COLD_TYPES = ["hospital", "pharmacy", "hotel", "restaurant", "police"]


def verify_server_health():
    """Ensures backend is running before benchmarking."""
    try:
        r = requests.get(f"{BACKEND_URL}/", timeout=3.0)
        if r.status_code == 200:
            print(f"[OK] Backend server is reachable on {BACKEND_URL}")
            return True
    except Exception as e:
        print(f"[ERROR] Cannot connect to backend: {e}")
        return False
    return False


def run_location_alert_benchmark(n_samples=35):
    """
    Measures latency from POST /api/v1/location ping to evaluated geofence alert response.
    Monotonic timer: time.perf_counter().
    """
    print(f"\n[*] Benchmarking Location Update to Geofence Alert ({n_samples} requests)...")
    results = []

    for i in range(1, n_samples + 1):
        zone = DANGER_ZONES[(i - 1) % len(DANGER_ZONES)]
        # Add small micro-jitter to coordinates to simulate real GPS movement
        lat = zone["lat"] + float(np.random.uniform(-0.001, 0.001))
        lng = zone["lng"] + float(np.random.uniform(-0.001, 0.001))

        payload = {
            "lat": lat,
            "lng": lng,
            "speed": float(np.random.uniform(1.0, 15.0)),
            "battery": int(np.random.randint(60, 100)),
            "network": "4G"
        }

        t_start = time.perf_counter()
        resp = requests.post(
            f"{BACKEND_URL}/api/v1/location",
            headers=HEADERS,
            json=payload,
            timeout=10.0
        )
        elapsed_ms = (time.perf_counter() - t_start) * 1000.0

        status = resp.status_code
        triggered_alerts = []
        if status == 201:
            data = resp.json().get("data", {})
            triggered_alerts = data.get("triggeredAlerts", [])

        alerts_count = len(triggered_alerts)
        alert_name = triggered_alerts[0].get("locationName", "") if alerts_count > 0 else "No Alert"

        results.append({
            "test_case": "location_update_to_alert",
            "request_id": i,
            "condition": "geofence_active",
            "endpoint": "POST /api/v1/location",
            "status_code": status,
            "success": (status == 201 and alerts_count > 0),
            "latency_ms": round(elapsed_ms, 2),
            "payload_details": f"Target: {zone['name']}",
            "response_items_count": alerts_count
        })

        if i % 10 == 0 or i == 1:
            print(f"    Req {i:02d}/{n_samples} | Latency: {elapsed_ms:.1f}ms | Alerts: {alerts_count} | Zone: {zone['name'][:30]}")

        # Minor spacing between pings
        time.sleep(0.05)

    return results


def run_poi_benchmark(n_samples=35):
    """
    Measures latency for Nearby Places (GET /api/v1/poi/nearby):
      - Cold-cache: Fresh coordinates and categories querying live providers (MapTiler/Overpass)
      - Warm-cache: Re-querying cached entries hitting MongoDB spatial index directly
    """
    print(f"\n[*] Benchmarking Nearby Places: Cold Cache vs. Warm Cache ({n_samples} each)...")
    cold_results = []
    warm_results = []

    # 1. Cold Cache Requests (fresh coordinates across regional centers)
    print("  -> Phase A: Cold-Cache Requests (Live Provider Queries)...")
    for i in range(1, n_samples + 1):
        coord = COLD_CACHE_BASE_COORDS[(i - 1) % len(COLD_CACHE_BASE_COORDS)]
        poi_type = COLD_TYPES[(i - 1) % len(COLD_TYPES)]
        # Offset lat/lng so it lands on a distinct uncached grid cell
        lat = coord["lat"] + (i * 0.015)
        lng = coord["lng"] + (i * 0.015)
        radius = 3000

        url = f"{BACKEND_URL}/api/v1/poi/nearby?type={poi_type}&lat={lat:.5f}&lng={lng:.5f}&radius={radius}"

        t_start = time.perf_counter()
        resp = requests.get(url, headers=HEADERS, timeout=15.0)
        elapsed_ms = (time.perf_counter() - t_start) * 1000.0

        status = resp.status_code
        count = 0
        if status == 200:
            count = resp.json().get("count", 0)

        cold_results.append({
            "test_case": "nearby_places",
            "request_id": i,
            "condition": "cold_cache",
            "endpoint": "GET /api/v1/poi/nearby",
            "status_code": status,
            "success": (status == 200),
            "latency_ms": round(elapsed_ms, 2),
            "payload_details": f"Type: {poi_type}, Coord: ({lat:.3f}, {lng:.3f})",
            "response_items_count": count
        })

        if i % 10 == 0 or i == 1:
            print(f"    Cold Req {i:02d}/{n_samples} | Latency: {elapsed_ms:.1f}ms | Places: {count} | Type: {poi_type}")

        time.sleep(0.05)

    # 2. Warm Cache Requests (querying populated areas that hit MongoDB directly)
    print("  -> Phase B: Warm-Cache Requests (MongoDB In-Memory / 2dsphere Hit)...")
    for i in range(1, n_samples + 1):
        cfg = WARM_CACHE_CONFIGS[(i - 1) % len(WARM_CACHE_CONFIGS)]
        poi_type = cfg["type"]
        lat = cfg["lat"]
        lng = cfg["lng"]
        radius = cfg["radius"]

        url = f"{BACKEND_URL}/api/v1/poi/nearby?type={poi_type}&lat={lat}&lng={lng}&radius={radius}"

        t_start = time.perf_counter()
        resp = requests.get(url, headers=HEADERS, timeout=10.0)
        elapsed_ms = (time.perf_counter() - t_start) * 1000.0

        status = resp.status_code
        count = 0
        if status == 200:
            count = resp.json().get("count", 0)

        warm_results.append({
            "test_case": "nearby_places",
            "request_id": i,
            "condition": "warm_cache",
            "endpoint": "GET /api/v1/poi/nearby",
            "status_code": status,
            "success": (status == 200 and count > 0),
            "latency_ms": round(elapsed_ms, 2),
            "payload_details": f"Type: {poi_type}, Radius: {radius}m",
            "response_items_count": count
        })

        if i % 10 == 0 or i == 1:
            print(f"    Warm Req {i:02d}/{n_samples} | Latency: {elapsed_ms:.1f}ms | Places: {count} | Type: {poi_type}")

        time.sleep(0.02)

    return cold_results, warm_results


def calculate_stats(latencies):
    """Computes mean, median, p95, min, max, std."""
    arr = np.array(latencies, dtype=np.float64)
    return {
        "mean_ms": round(float(np.mean(arr)), 2),
        "median_ms": round(float(np.median(arr)), 2),
        "p95_ms": round(float(np.percentile(arr, 95)), 2),
        "min_ms": round(float(np.min(arr)), 2),
        "max_ms": round(float(np.max(arr)), 2),
        "std_ms": round(float(np.std(arr)), 2),
    }


def main():
    print("=" * 84)
    print("SAFETOUR AI - SYSTEM RESPONSIVENESS & LATENCY BENCHMARK")
    print("=" * 84)

    if not verify_server_health():
        sys.exit(1)

    # 1. Run benchmarks
    loc_results = run_location_alert_benchmark(n_samples=35)
    cold_results, warm_results = run_poi_benchmark(n_samples=35)

    all_raw_data = loc_results + cold_results + warm_results
    df_raw = pd.DataFrame(all_raw_data)

    # 2. Compute Statistics per Test Case & Condition
    summary = {
        "benchmark_name": "SafeTour AI Live System Responsiveness",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "backend_url": BACKEND_URL,
        "results": {}
    }

    test_groups = [
        ("Location Update to Alert", loc_results),
        ("Nearby Places (Cold Cache)", cold_results),
        ("Nearby Places (Warm Cache)", warm_results),
    ]

    print("\n" + "=" * 84)
    print("BENCHMARK SUMMARY RESULTS TABLE")
    print("=" * 84)
    print(f"{'Endpoint / Pipeline':<30} | {'Condition':<12} | {'Reqs':<5} | {'Mean (ms)':<10} | {'Median (ms)':<11} | {'P95 (ms)':<9} | {'Min-Max (ms)':<14}")
    print("-" * 84)

    for name, sample_list in test_groups:
        latencies = [s["latency_ms"] for s in sample_list if s["success"]]
        stats = calculate_stats(latencies)
        success_count = sum(1 for s in sample_list if s["success"])
        total_count = len(sample_list)

        group_key = name.lower().replace(" ", "_").replace("(", "").replace(")", "")
        summary["results"][group_key] = {
            "name": name,
            "total_requests": total_count,
            "successful_requests": success_count,
            "success_rate_pct": round((success_count / total_count) * 100.0, 1),
            "latency": stats
        }

        min_max_str = f"{stats['min_ms']:.0f} - {stats['max_ms']:.0f}"
        cond_str = sample_list[0]["condition"]
        print(f"{name:<30} | {cond_str:<12} | {total_count:<5} | {stats['mean_ms']:<10.1f} | {stats['median_ms']:<11.1f} | {stats['p95_ms']:<9.1f} | {min_max_str:<14}")

    print("=" * 84)

    # Calculate Cache Speedup Factor
    cold_mean = summary["results"]["nearby_places_cold_cache"]["latency"]["mean_ms"]
    warm_mean = summary["results"]["nearby_places_warm_cache"]["latency"]["mean_ms"]
    speedup = round(cold_mean / max(0.1, warm_mean), 1)
    summary["cache_performance"] = {
        "speedup_factor": f"{speedup}x faster on warm cache",
        "latency_reduction_pct": round(((cold_mean - warm_mean) / cold_mean) * 100.0, 1)
    }

    print(f"\n[*] Cache Efficiency: Warm cache is {speedup}x FASTER than cold cache ({summary['cache_performance']['latency_reduction_pct']}% latency reduction).")

    # 3. Save Files
    data_dir = BASE_DIR / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    csv_path = data_dir / "responsiveness_results.csv"
    json_path = data_dir / "responsiveness_summary.json"

    df_raw.to_csv(csv_path, index=False)
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    print(f"\n[OK] Saved raw measurement results to: {csv_path} ({len(df_raw)} records)")
    print(f"[OK] Saved summary statistics to:       {json_path}")


if __name__ == "__main__":
    main()
