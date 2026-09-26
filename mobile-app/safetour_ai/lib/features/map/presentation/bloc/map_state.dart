import 'package:latlong2/latlong.dart';
import '../../domain/entities/map_marker_entity.dart';
import '../../domain/entities/map_zone_entity.dart';

abstract class MapState {}

class MapInitial extends MapState {}

class MapLoading extends MapState {}

class MapLoaded extends MapState {
  final LatLng currentCenter;
  final List<MapMarkerEntity> markers;
  
  // Keep track of user's live position directly 
  // so the UI knows where the "recenter" button should jump to.
  final LatLng? userPosition;

  // Vector geofence safe/danger zones to render on the map overlay
  final List<MapZoneEntity> zones;

  MapLoaded({
    required this.currentCenter,
    required this.markers,
    this.userPosition,
    this.zones = const [],
  });

  MapLoaded copyWith({
    LatLng? currentCenter,
    List<MapMarkerEntity>? markers,
    LatLng? userPosition,
    List<MapZoneEntity>? zones,
  }) {
    return MapLoaded(
      currentCenter: currentCenter ?? this.currentCenter,
      markers: markers ?? this.markers,
      userPosition: userPosition ?? this.userPosition,
      zones: zones ?? this.zones,
    );
  }
}

class MapError extends MapState {
  final String message;
  MapError(this.message);
}
