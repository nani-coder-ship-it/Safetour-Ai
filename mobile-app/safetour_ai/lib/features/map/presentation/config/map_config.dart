/// Map Configuration for SafeTour AI
///
/// Multi-provider configuration with Standard OpenStreetMap as default.
/// Supports 1-tap switching between Standard Streets, Real Satellite, and Humanitarian.
class MapConfig {
  MapConfig._();

  /// Standard OpenStreetMap (Vibrant, colorful roads, green parks, 100% Free)
  static const String standardOsmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Real Satellite Imagery (ESRI World Imagery - Free, Real satellite photos from space)
  static const String satelliteTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  /// Humanitarian OpenStreetMap (High contrast, bold landmarks)
  static const String humanitarianOsmTileUrl =
      'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';

  /// User MapTiler API Key (Configurable via --dart-define=MAPTILER_API_KEY=your_key)
  static const String maptilerApiKey =
      String.fromEnvironment('MAPTILER_API_KEY', defaultValue: 'YOUR_MAPTILER_API_KEY');

  /// MapTiler Streets-v2
  static const String maptilerStreetsUrl =
      'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=$maptilerApiKey';

  /// Active default tile URL template (Standard colorful OpenStreetMap)
  static const String defaultTileUrl = standardOsmTileUrl;

  /// Multi-domain sharding (for servers that support it)
  static const List<String> tileSubdomains = [];

  /// Package user agent identifier
  static const String userAgentPackageName = 'com.example.safetour_ai';

  /// Map camera zoom constraints
  static const double minZoom = 3.0;
  static const double maxZoom = 20.0;
  static const int maxNativeZoom = 19;
  static const double defaultZoom = 17.5;
  static const double placeFocusZoom = 17.5;
}
