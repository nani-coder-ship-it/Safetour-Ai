class ApiConstants {
  // Primary: 127.0.0.1 over USB (supported via `adb reverse tcp:5000 tcp:5000`)
  // Fallback: local Wi-Fi LAN
  static const String baseUrl = 'http://127.0.0.1:5000/api/v1';
  static const String wifiUrl = 'http://192.168.1.100:5000/api/v1';
}
