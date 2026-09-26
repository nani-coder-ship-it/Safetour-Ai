import 'package:geolocator/geolocator.dart';

abstract class LocationEvent {
  const LocationEvent();
}

class StartTracking extends LocationEvent {}

class StopTracking extends LocationEvent {}

class LocationUpdated extends LocationEvent {
  final Position position;
  const LocationUpdated(this.position);
}
