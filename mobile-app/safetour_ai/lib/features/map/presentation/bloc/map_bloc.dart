import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/map_marker_entity.dart';
import '../../../location/data/services/device_location_service.dart';
import '../../../geofence/domain/usecases/get_active_zones.dart';
import 'map_event.dart';
import 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final DeviceLocationService locationService;
  final GetActiveZones getActiveZones;
  StreamSubscription? _locationSubscription;

  // Track the last position where danger zones were fetched
  // Used for distance-based refetching (every 2km)
  LatLng? _lastZonesFetchedPosition;
  bool _isLoadingZones = false;
  
  // Default to India coordinates if no location is available yet
  final LatLng defaultCenter = const LatLng(20.5937, 78.9629);

  MapBloc({
    required this.locationService,
    required this.getActiveZones,
  }) : super(MapInitial()) {
    on<InitializeMap>(_onInitializeMap);
    on<UpdateUserLocation>(_onUpdateUserLocation);
    on<AddMarkers>(_onAddMarkers);
    on<RecenterMap>(_onRecenterMap);
    on<UpdateMapZones>(_onUpdateMapZones);
    on<LoadDangerZones>(_onLoadDangerZones);
  }

  Future<void> _onInitializeMap(InitializeMap event, Emitter<MapState> emit) async {
    // Prevent multiple initializations
    if (state is! MapInitial && state is! MapError) return;

    emit(MapLoading());

    LatLng center = defaultCenter;
    List<MapMarkerEntity> initialMarkers = [];
    LatLng? userPos;

    try {
      // 1. Request/verify location permission first
      final perm = await locationService.requestPermission();

      if (perm == LocationPermissionStatus.granted) {
        // Get the immediate current location first using last known to avoid indefinite hang indoors
        final position = await locationService.getLastKnownPosition();
        if (position != null &&
            !position.latitude.isNaN && !position.latitude.isInfinite &&
            !position.longitude.isNaN && !position.longitude.isInfinite) {
          center = LatLng(position.latitude, position.longitude);
          userPos = center;

          initialMarkers.add(MapMarkerEntity(
            id: 'user_live',
            lat: position.latitude,
            lng: position.longitude,
            label: 'You are here',
            type: MarkerType.user,
          ));

          // Immediately fetch active danger zones for current location
          add(LoadDangerZones(
            lat: position.latitude,
            lng: position.longitude,
          ));
        }

        // Now start listening to the stream for future updates
        _locationSubscription = locationService.getPositionStream().listen(
          (pos) {
            if (!isClosed &&
                !pos.latitude.isNaN && !pos.latitude.isInfinite &&
                !pos.longitude.isNaN && !pos.longitude.isInfinite) {
              add(UpdateUserLocation(LatLng(pos.latitude, pos.longitude)));
            }
          },
          onError: (e) {
            print('MapBloc Stream Error: $e');
          },
        );
      }
    } catch (e) {
      print('MapBloc Init Error: $e');
      // If we fail to get location (e.g., permissions), we just show default center
    }

    emit(MapLoaded(
      currentCenter: center,
      markers: initialMarkers,
      userPosition: userPos,
    ));
  }

  Future<void> _onUpdateUserLocation(UpdateUserLocation event, Emitter<MapState> emit) async {
    if (event.position.latitude.isNaN || event.position.latitude.isInfinite ||
        event.position.longitude.isNaN || event.position.longitude.isInfinite) {
      return;
    }

    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      
      final userMarker = MapMarkerEntity(
        id: 'user_live',
        lat: event.position.latitude,
        lng: event.position.longitude,
        label: 'You are here',
        type: MarkerType.user,
      );

      // Keep existing markers, update the user marker
      final otherMarkers = currentState.markers.where((m) => m.type != MarkerType.user).toList();
      
      // We do NOT auto-pan the camera on every update (it frustrates users), 
      // but we update the userPosition so Recenter can use it.
      emit(currentState.copyWith(
        markers: [...otherMarkers, userMarker],
        userPosition: event.position,
        // Only pan automatically if it's the very first location we got (currentCenter == defaultCenter)
        currentCenter: currentState.currentCenter == defaultCenter ? event.position : currentState.currentCenter,
      ));

      // Distance-based refetching:
      // If zones were never fetched, or if user moved >= 2000 meters (2km) from last fetch
      if (_lastZonesFetchedPosition == null) {
        add(LoadDangerZones(
          lat: event.position.latitude,
          lng: event.position.longitude,
        ));
      } else {
        final double distanceMoved = Geolocator.distanceBetween(
          _lastZonesFetchedPosition!.latitude,
          _lastZonesFetchedPosition!.longitude,
          event.position.latitude,
          event.position.longitude,
        );

        if (distanceMoved >= 2000 && !_isLoadingZones) {
          add(LoadDangerZones(
            lat: event.position.latitude,
            lng: event.position.longitude,
          ));
        }
      }
    }
  }

  Future<void> _onLoadDangerZones(LoadDangerZones event, Emitter<MapState> emit) async {
    if (event.lat.isNaN || event.lat.isInfinite ||
        event.lng.isNaN || event.lng.isInfinite) {
      return;
    }
    _isLoadingZones = true;
    _lastZonesFetchedPosition = LatLng(event.lat, event.lng);

    try {
      final zones = await getActiveZones(
        lat: event.lat,
        lng: event.lng,
        radiusMeters: event.radiusMeters,
      );

      if (state is MapLoaded) {
        final currentState = state as MapLoaded;
        emit(currentState.copyWith(activeZones: zones));
      }
    } catch (e) {
      // Graceful error handling: map continues to function normally if network/backend fails
      print('MapBloc LoadDangerZones Error: $e');
    } finally {
      _isLoadingZones = false;
    }
  }

  Future<void> _onAddMarkers(AddMarkers event, Emitter<MapState> emit) async {
    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      emit(currentState.copyWith(markers: event.markers));
    }
  }

  Future<void> _onRecenterMap(RecenterMap event, Emitter<MapState> emit) async {
    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      if (currentState.userPosition != null) {
        emit(currentState.copyWith(currentCenter: currentState.userPosition));
      }
    }
  }

  Future<void> _onUpdateMapZones(UpdateMapZones event, Emitter<MapState> emit) async {
    if (state is MapLoaded) {
      final currentState = state as MapLoaded;
      emit(currentState.copyWith(zones: event.zones));
    }
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }
}
