# SafeTour AI - AI Service (Road Graph & GAT Model)

This service manages the geospatial road network graph extraction, real accident & crime feature engineering, Graph Attention Network (GATv2) model training, and the real-time AI safety inference microservice for SafeTour AI.

## Project Structure

```text
ai-service/
├── data/
│   ├── raw/                           # Raw datasets (accidents, complaints, OSM extract)
│   ├── road_graph_raw.graphml         # Serialized raw OpenStreetMap road network
│   ├── road_graph_featured.graphml    # Feature-enriched graph
│   ├── nodes.csv                      # Intersections table with real metrics
│   ├── edges.csv                      # Road segments table with hazard attributes
│   └── test_predictions.csv          # GATv2 model predictions on unseen test edges
├── data_prep/
│   ├── fetch_road_graph.py            # OSMnx road network extraction
│   └── build_features.py              # Real accident & crime feature engineering
├── models/
│   ├── dataset.py                     # PyTorch Geometric Data tensor builder & encoder
│   ├── gat_model.py                   # Edge-Conditioned Multi-Head GATv2 architecture
│   ├── train.py                       # Supervised training loop, metrics & early stopping
│   └── checkpoints/
│       ├── best_gat_model.pt          # Serialized trained model weights (136 KB)
│       └── training_history.json      # Loss and validation metric logs
├── notebooks/
│   └── train_gat_colab.ipynb          # Self-contained Google Colab GPU training notebook
├── app.py                             # Flask real-time inference microservice
├── test_api.py                        # API integration test suite
├── .env.example                       # Environment configuration template
├── README.md                          # Documentation
└── requirements.txt                   # Dependencies
```

---

## Setup & Installation

### 1. Prerequisites
- Python 3.10+
- Git

### 2. Create Virtual Environment

On **Windows (Command Prompt / PowerShell)**:
```bash
cd ai-service
python -m venv venv
venv\Scripts\activate
```

On **macOS / Linux**:
```bash
cd ai-service
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Dependencies
```bash
pip install --upgrade pip
pip install -r requirements.txt
```

---

## Workflow Guide

### Step 1: Road Graph Extraction (Phase 1)
Downloads the drivable road network from OpenStreetMap using OSMnx for the Krishnankoil / Srivilliputtur corridor:
```bash
python data_prep/fetch_road_graph.py
```
*Outputs: `data/road_graph_raw.graphml` (1,389 nodes, 4,148 edges).*

### Step 2: Feature Engineering with Real Data (Phase 1.5)
Enriches the road graph with real Tamil Nadu road accident statistics and police complaint distributions:
```bash
python data_prep/build_features.py
```
*Outputs: `data/road_graph_featured.graphml`, `data/nodes.csv`, `data/edges.csv`.*

### Step 3: GATv2 Model Training (Phase 2)
Trains the Edge-Conditioned Multi-Head GATv2 model with Huber loss and early stopping:
```bash
python models/train.py
```
*Outputs: `models/checkpoints/best_gat_model.pt`, `data/test_predictions.csv` (Test RMSE: 1.410, Test MAE: 1.147).*

### Step 4: Run Real-Time Flask Inference Service (Phase 3)
Starts the REST API service on port 5001:
```bash
python app.py
```

### Step 5: Run Integration Tests
```bash
python test_api.py
```

---

## REST API Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| `GET` | `/health` | Health check & model status |
| `GET` | `/api/v1/network-summary` | Bounding box, center coordinates, and safety distribution |
| `POST` | `/api/v1/predict-segment` | Predicts safety score for a single road segment (by node IDs or GPS coords) |
| `POST` | `/api/v1/evaluate-route` | Evaluates an entire travel route (list of GPS waypoints) and returns safety rating |
| `POST` | `/api/v1/simulate-hazard` | Dynamic hazard simulation (flood surge, road blocks) with on-the-fly re-scoring |

### Example Request: Route Safety Evaluation
```json
POST /api/v1/evaluate-route
Content-Type: application/json

{
  "coordinates": [
    {"lat": 9.5680, "lng": 77.6740},
    {"lat": 9.5690, "lng": 77.6750},
    {"lat": 9.5700, "lng": 77.6760}
  ]
}
```

**Response**:
```json
{
  "overall_safety_score": 75.14,
  "overall_rating": "SAFE",
  "color_code": "LightGreen",
  "summary": "Generally safe route with standard suburban infrastructure.",
  "total_distance_meters": 246.1,
  "evaluated_segments_count": 3,
  "danger_alerts_count": 0,
  "danger_alerts": [],
  "segments": [ ... ]
}
```
