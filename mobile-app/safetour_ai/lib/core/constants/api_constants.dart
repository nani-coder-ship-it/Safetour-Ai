class ApiConstants {
  // Primary: Active Wi-Fi Host IP for direct mobile phone communication
  static const String baseUrl = 'http://10.2.22.244:5000/api/v1';
  // Secondary: 127.0.0.1 for USB cable (via `adb reverse tcp:5000 tcp:5000`)
  static const String wifiUrl = 'http://127.0.0.1:5000/api/v1';
}
