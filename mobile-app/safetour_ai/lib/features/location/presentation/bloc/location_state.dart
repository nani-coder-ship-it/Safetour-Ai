import 'package:geolocator/geolocator.dart';

abstract class LocationState {
  const LocationState();
}

class LocationInitial extends LocationState {}

class LocationTracking extends LocationState {
  final Position? currentPosition;
  final List<String> alerts;
  
  const LocationTracking({this.currentPosition, this.alerts = const []});

  Position? get currentLocation => currentPosition;
}

class LocationPermissionDenied extends LocationState {
  final String message;
  final bool isPermanentlyDenied;
  final bool isServiceDisabled;

  const LocationPermissionDenied(
    this.message, {
    this.isPermanentlyDenied = false,
    this.isServiceDisabled = false,
  });
}

class LocationError extends LocationState {
  final String message;
  const LocationError(this.message);
}
