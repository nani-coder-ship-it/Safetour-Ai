import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/map_marker_entity.dart';
import '../../../location/data/services/device_location_service.dart';
import 'map_event.dart';
import 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  final DeviceLocationService locationService;
  StreamSubscription? _locationSubscription;
  
  // Default to India coordinates if no location is available yet
  final LatLng defaultCenter = const LatLng(20.5937, 78.9629);

  MapBloc({required this.locationService}) : super(MapInitial()) {
    on<InitializeMap>(_onInitializeMap);
    on<UpdateUserLocation>(_onUpdateUserLocation);
    on<AddMarkers>(_onAddMarkers);
    on<RecenterMap>(_onRecenterMap);
    on<UpdateMapZones>(_onUpdateMapZones);
  }

  Future<void> _onInitializeMap(InitializeMap event, Emitter<MapState> emit) async {
    // Prevent multiple initializations
    if (state is! MapInitial && state is! MapError) return;

    emit(MapLoading());

    LatLng center = defaultCenter;
    List<MapMarkerEntity> initialMarkers = [];
    LatLng? userPos;

    try {
      // Get the immediate current location first using last known to avoid indefinite hang indoors
      final position = await locationService.getLastKnownPosition();
      if (position != null) {
        center = LatLng(position.latitude, position.longitude);
        userPos = center;

        initialMarkers.add(MapMarkerEntity(
          id: 'user_live',
          lat: position.latitude,
          lng: position.longitude,
          label: 'You are here',
          type: MarkerType.user,
        ));
      }

      // Now start listening to the stream for future updates
      _locationSubscription = locationService.getPositionStream().listen(
        (pos) {
          if (!isClosed) {
            add(UpdateUserLocation(LatLng(pos.latitude, pos.longitude)));
          }
        },
        onError: (e) {
          print('MapBloc Stream Error: $e');
        }
      );
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
