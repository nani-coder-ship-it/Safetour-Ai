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
      if (permission == LocationPermissionStatus.serviceDisabled) {
        emit(PoiError(
          message:
              'Device GPS / Location is turned OFF. Please turn ON location in device settings to find nearby places.',
          selectedType: type,
          selectedRadius: radius,
          selectedSubType: subType,
          searchQuery: state.searchQuery,
        ));
        return;
      } else if (permission == LocationPermissionStatus.deniedForever) {
        emit(PoiError(
          message:
              'Location permission is permanently denied. Please tap "Open Settings" to enable location permission for SafeTour AI.',
          selectedType: type,
          selectedRadius: radius,
          selectedSubType: subType,
          searchQuery: state.searchQuery,
        ));
        return;
      } else if (permission == LocationPermissionStatus.denied) {
        emit(PoiError(
          message:
              'Location permission is required to find nearby places. Please tap "Grant Permission" to allow access.',
          selectedType: type,
          selectedRadius: radius,
          selectedSubType: subType,
          searchQuery: state.searchQuery,
        ));
        return;
      }

      // Instant fix: Try last known position first (instant <10ms)
      try {
        final lastPos = await locationService.getLastKnownPosition();
        if (lastPos != null &&
            !lastPos.latitude.isNaN && !lastPos.latitude.isInfinite &&
            !lastPos.longitude.isNaN && !lastPos.longitude.isInfinite) {
          lat = lastPos.latitude;
          lng = lastPos.longitude;
        }
      } catch (_) {}

      // Only if no location was available or user forced a refresh, await fresh satellite lock with a lean 2.5s ceiling
      if ((lat == null || lng == null) || event.forceRefresh) {
        try {
          final position = await locationService
              .getCurrentPosition()
              .timeout(const Duration(milliseconds: 2500));
          if (!position.latitude.isNaN && !position.latitude.isInfinite &&
              !position.longitude.isNaN && !position.longitude.isInfinite) {
            lat = position.latitude;
            lng = position.longitude;
          }
        } catch (_) {
          // If high accuracy GPS timed out indoors, continue with last known if available
        }
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
        const Duration(seconds: 32),
        onTimeout: () => throw TimeoutException('Nearby search took too long — please try again.'),
      );

      // Defense-in-depth: Exclude collegiate / student accommodation from Hotels & Lodges
      final strictlyWithin = <PoiEntity>[];
      final fallbackPois = <PoiEntity>[];

      for (final p in rawPois) {
        // Defense-in-depth: Exclude collegiate / student accommodation across all categories
        if (p.isStudentAccommodation) {
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
