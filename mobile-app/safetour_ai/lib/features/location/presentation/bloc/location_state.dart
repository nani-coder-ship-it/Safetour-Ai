abstract class LocationState {
  const LocationState();
}

class LocationInitial extends LocationState {}

class LocationTracking extends LocationState {
  final List<String> alerts;
  
  const LocationTracking({this.alerts = const []});
}

class LocationPermissionDenied extends LocationState {
  final String message;
  const LocationPermissionDenied(this.message);
}

class LocationError extends LocationState {
  final String message;
  const LocationError(this.message);
}
