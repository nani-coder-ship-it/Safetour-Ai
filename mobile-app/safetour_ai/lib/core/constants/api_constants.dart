class ApiConstants {
  // Production URL can be injected via:
  // flutter build apk --dart-define=API_BASE_URL=https://<your-backend-domain>/api/v1
  // Or defaults to active Wi-Fi IP for local debugging.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.2.26.146:5000/api/v1',
  );

  // Secondary: 127.0.0.1 for USB cable (via `adb reverse tcp:5000 tcp:5000`)
  static const String wifiUrl = 'http://127.0.0.1:5000/api/v1';

  // Server root URL without /api/v1 for public verification routes
  static String get serverBaseUrl => baseUrl.replaceAll('/api/v1', '');
}
