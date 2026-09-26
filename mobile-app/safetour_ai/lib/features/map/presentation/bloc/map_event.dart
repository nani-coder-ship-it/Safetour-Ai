import 'package:latlong2/latlong.dart';
import '../../domain/entities/map_marker_entity.dart';
import '../../domain/entities/map_zone_entity.dart';

abstract class MapEvent {}

class InitializeMap extends MapEvent {}

class UpdateUserLocation extends MapEvent {
  final LatLng position;
  UpdateUserLocation(this.position);
}

class AddMarkers extends MapEvent {
  final List<MapMarkerEntity> markers;
  AddMarkers(this.markers);
}

class RecenterMap extends MapEvent {}

class UpdateMapZones extends MapEvent {
  final List<MapZoneEntity> zones;
  UpdateMapZones(this.zones);
}
