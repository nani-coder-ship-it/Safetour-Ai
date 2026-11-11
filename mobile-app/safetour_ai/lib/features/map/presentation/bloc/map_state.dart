import 'package:latlong2/latlong.dart';
import '../../domain/entities/map_marker_entity.dart';
import '../../domain/entities/map_zone_entity.dart';
import '../../../geofence/domain/entities/danger_zone_entity.dart';

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

  // Active danger zones fetched from backend geofence API
  final List<DangerZoneEntity> activeZones;

  MapLoaded({
    required this.currentCenter,
    required this.markers,
    this.userPosition,
    this.zones = const [],
    this.activeZones = const [],
  });

  MapLoaded copyWith({
    LatLng? currentCenter,
    List<MapMarkerEntity>? markers,
    LatLng? userPosition,
    List<MapZoneEntity>? zones,
    List<DangerZoneEntity>? activeZones,
  }) {
    return MapLoaded(
      currentCenter: currentCenter ?? this.currentCenter,
      markers: markers ?? this.markers,
      userPosition: userPosition ?? this.userPosition,
      zones: zones ?? this.zones,
      activeZones: activeZones ?? this.activeZones,
    );
  }
}

class MapError extends MapState {
  final String message;
  MapError(this.message);
}
