import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus { granted, denied, deniedForever }

class DeviceLocationService {
  /// Requests location permissions from the user and returns the status
  Future<LocationPermissionStatus> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      return LocationPermissionStatus.denied;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        return LocationPermissionStatus.denied;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      return LocationPermissionStatus.deniedForever;
    } 

    return LocationPermissionStatus.granted;
  }

  /// Gets the current one-off position
  Future<Position> getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
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
