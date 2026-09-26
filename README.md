# SafeTour AI 🛡️🗺️

SafeTour AI is an intelligent, real-time travel safety and navigation ecosystem designed to safeguard tourists, solo travelers, and backpackers in unfamiliar and high-risk regions.

---

## 🌟 Key Features

* **Multi-Layer Interactive Maps:** Switch between High-Resolution Satellite (ESRI), MapTiler Streets v2, OpenStreetMap Standard, and Humanitarian OSM tiles.
* **Live GPS Tracking & Radar Marker:** Hardware GPS tracking with an animated pulsating radar marker and real-time location streaming.
* **Intelligent Nearby POI Discovery:** Multi-source search (MapTiler, OSM Nominatim, Overpass QL, and local MongoDB 2dsphere cache) with strict negative filtering to exclude college student hostels from hotel/lodge queries.
* **AI Travel Safety Assistant:** Powered by Google Gemini 1.5 Flash with an integrated deterministic fallback rule engine for emergency guidance, scam alerts, and local safety rules.
* **Spatial Geofencing & Alerting:** Real-time spatial intersection queries (`$geoIntersects`) detecting user entry into danger/caution zones.
* **Emergency Hub & SOS Siren Mode:** One-tap emergency dialer (100, 108, 112, 1091), alternating red/blue full-screen visual strobe, and GPS distress broadcast to clipboard.

---

## 🏗️ Architecture

```
SafeTour AI
├── backend/                   # Node.js + Express REST API Server
│   ├── src/
│   │   ├── config/            # MongoDB (Mongoose) & Firebase Admin configuration
│   │   ├── middleware/        # JWT Authentication and global error handlers
│   │   └── modules/           # Auth, Location, Geofence, POI, Chat, Alerts
├── mobile-app/
│   └── safetour_ai/           # Flutter Mobile Application (Clean Architecture + BLoC)
```

---

## 🚀 Getting Started

### 1. Backend Setup
```bash
cd backend
npm install
cp .env.example .env
# Configure your MONGODB_URI, GEMINI_API_KEY, and MAPTILER_API_KEY in .env
npm run dev
```

### 2. Mobile App Setup
```bash
cd mobile-app/safetour_ai
flutter pub get

# Configure Firebase:
# 1. Place your own google-services.json in android/app/ (see google-services.json.example)
# 2. Configure lib/firebase_options.dart with your project keys (see firebase_options.dart.example)

# If running on a physical Android device via USB:
adb reverse tcp:5000 tcp:5000

# Run with optional MapTiler API Key:
flutter run --dart-define=MAPTILER_API_KEY=your_key_here
```

---

## 📄 License
This project is licensed under the MIT License.
