import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/errors/failures.dart';
import '../../../location/data/services/device_location_service.dart';
import '../../domain/entities/poi_entity.dart';
import '../../domain/usecases/get_nearby_pois.dart';
import 'poi_event.dart';
import 'poi_state.dart';

class PoiBloc extends Bloc<PoiEvent, PoiState> {
  final GetNearbyPOIs getNearbyPOIs;
  final DeviceLocationService locationService;

  PoiBloc({
    required this.getNearbyPOIs,
    required this.locationService,
  }) : super(const PoiInitial()) {
    on<LoadNearbyPOIs>(_onLoadNearbyPOIs);
    on<SelectCategory>(_onSelectCategory);
    on<SelectRadius>(_onSelectRadius);
    on<SelectSubType>(_onSelectSubType);
    on<UpdateSearchQuery>(_onUpdateSearchQuery);
  }

  Future<void> _onLoadNearbyPOIs(LoadNearbyPOIs event, Emitter<PoiState> emit) async {
    final type = event.type ?? state.selectedType;
    final radius = event.radiusMeters ?? state.selectedRadius;
    final subType = event.subType ?? state.selectedSubType;

    emit(PoiLoading(
      selectedType: type,
      selectedRadius: radius,
      selectedSubType: subType,
      searchQuery: state.searchQuery,
    ));

    double? lat = event.userLat;
    double? lng = event.userLng;

    // If coordinates were not passed in event and we are not forcing a hardware refresh,
    // reuse previously verified GPS location if available
    if ((lat == null || lng == null) && !event.forceRefresh && state is PoiLoaded) {
      final currentLoaded = state as PoiLoaded;
      lat = currentLoaded.userLat;
      lng = currentLoaded.userLng;
    }

    // Otherwise, obtain latest GPS coordinates from device
    if (lat == null || lng == null || event.forceRefresh) {
      final permission = await locationService.requestPermission();
      if (permission == LocationPermissionStatus.denied ||
          permission == LocationPermissionStatus.deniedForever) {
        emit(PoiError(
          message:
              'Location permission is required to find nearby places. Please enable location access in settings.',
          selectedType: type,
          selectedRadius: radius,
          selectedSubType: subType,
          searchQuery: state.searchQuery,
        ));
        return;
      }

      // Try last known position for instant fix
      try {
        final lastPos = await locationService.getLastKnownPosition();
        if (lastPos != null) {
          lat = lastPos.latitude;
          lng = lastPos.longitude;
        }
      } catch (_) {}

      // Try fresh high-accuracy position
      try {
        final position = await locationService
            .getCurrentPosition()
            .timeout(const Duration(seconds: 7));
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {
        // If high accuracy GPS timed out indoors, use last known if available
      }

      if (lat == null || lng == null) {
        emit(PoiError(
          message:
              'Unable to get your GPS location. Please ensure Location / GPS is turned ON and try again.',
          selectedType: type,
          selectedRadius: radius,
          selectedSubType: subType,
          searchQuery: state.searchQuery,
        ));
        return;
      }
    }

    try {
      final rawPois = await getNearbyPOIs(
        lat: lat,
        lng: lng,
        radiusMeters: radius,
        type: type,
        subType: subType,
        search: event.search,
      ).timeout(
        const Duration(seconds: 22),
        onTimeout: () => throw TimeoutException('Nearby search took too long — please try again.'),
      );

      // Defense-in-depth: Exclude collegiate / student accommodation from Hotels & Lodges
      final strictlyWithin = <PoiEntity>[];
      final fallbackPois = <PoiEntity>[];

      for (final p in rawPois) {
        if (type == 'hotel' && p.isStudentAccommodation) {
          continue;
        }

        // Calculate exact distance from user's current GPS location
        final dist = Geolocator.distanceBetween(lat, lng, p.lat, p.lng);
        final updated = p.copyWith(distanceMeters: dist);

        if (dist <= radius) {
          strictlyWithin.add(updated);
        } else {
          fallbackPois.add(updated);
        }
      }

      // Prioritize places strictly within radius; fallback to nearest available if none exist in immediate radius
      final validPois = strictlyWithin.isNotEmpty ? strictlyWithin : fallbackPois;

      // Sort ascending by distance (nearest first)
      validPois.sort((a, b) => (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));

      emit(PoiLoaded(
        pois: validPois,
        userLat: lat,
        userLng: lng,
        selectedType: type,
        selectedRadius: radius,
        selectedSubType: subType,
        searchQuery: state.searchQuery,
      ));
    } catch (e) {
      String msg = 'Unable to find nearby places. Check your internet connection and try again.';
      if (e is Failure) {
        msg = e.message;
      } else if (e is TimeoutException) {
        msg = 'Nearby search timed out. OpenStreetMap servers may be busy, please try again.';
      }

      emit(PoiError(
        message: msg,
        selectedType: type,
        selectedRadius: radius,
        selectedSubType: subType,
        searchQuery: state.searchQuery,
      ));
    }
  }

  Future<void> _onSelectCategory(SelectCategory event, Emitter<PoiState> emit) async {
    if (state.selectedType == event.type && state is PoiLoaded) return;
    double? currentLat;
    double? currentLng;
    if (state is PoiLoaded) {
      currentLat = (state as PoiLoaded).userLat;
      currentLng = (state as PoiLoaded).userLng;
    }
    add(LoadNearbyPOIs(
      type: event.type,
      radiusMeters: state.selectedRadius,
      subType: null, // Reset subtype when category changes
      userLat: currentLat,
      userLng: currentLng,
    ));
  }

  Future<void> _onSelectRadius(SelectRadius event, Emitter<PoiState> emit) async {
    if (state.selectedRadius == event.radiusMeters && state is PoiLoaded) return;
    double? currentLat;
    double? currentLng;
    if (state is PoiLoaded) {
      currentLat = (state as PoiLoaded).userLat;
      currentLng = (state as PoiLoaded).userLng;
    }
    add(LoadNearbyPOIs(
      type: state.selectedType,
      radiusMeters: event.radiusMeters,
      subType: state.selectedSubType,
      userLat: currentLat,
      userLng: currentLng,
    ));
  }

  void _onSelectSubType(SelectSubType event, Emitter<PoiState> emit) {
    if (state is PoiLoaded) {
      final currentState = state as PoiLoaded;
      emit(currentState.copyWith(
        selectedSubType: event.subType,
        clearSubType: event.subType == null || event.subType == 'all',
      ));
    }
  }

  void _onUpdateSearchQuery(UpdateSearchQuery event, Emitter<PoiState> emit) {
    if (state is PoiLoaded) {
      final currentState = state as PoiLoaded;
      emit(currentState.copyWith(searchQuery: event.query));
    }
  }
}
