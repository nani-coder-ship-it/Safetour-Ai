import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

class DeviceLocationService {
  /// Opens the device settings page where the user can turn ON GPS / Location Services
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Opens the App Settings page in Android/iOS settings where permissions can be toggled
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Requests location permissions from the user and returns the status
  Future<LocationPermissionStatus> requestPermission() async {
    // 1. Check if device location services (GPS toggle in notification tray) are enabled
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionStatus.serviceDisabled;
    }

    // 2. Check current OS permission status
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Actively show the Android/iOS system permission popup dialog
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationPermissionStatus.denied;
      }
    }
    
    // 3. If permanently denied, OS blocks dialogs; user must be directed to App Settings
    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionStatus.deniedForever;
    } 

    return LocationPermissionStatus.granted;
  }

  /// Gets the current one-off position with indoor Wi-Fi/cell tower fallback
  Future<Position> getCurrentPosition({
    LocationAccuracy desiredAccuracy = LocationAccuracy.high,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: desiredAccuracy,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      // Fallback to medium accuracy (instant fix indoors via Wi-Fi/Cell)
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    }
  }

  /// Gets the last known position (returns immediately)
  Future<Position?> getLastKnownPosition() async {
    return await Geolocator.getLastKnownPosition();
  }

  /// Returns a stream of position updates, filtering out tiny GPS jitters 
  /// (only triggers if the device moves more than 10 meters).
  Stream<Position> getPositionStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Must move at least 10 meters to trigger an update
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}
