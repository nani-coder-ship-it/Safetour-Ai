import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/location_entity.dart';
import '../../domain/usecases/send_location.dart';
import '../../data/services/device_location_service.dart';
import 'location_event.dart';
import 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final DeviceLocationService locationService;
  final SendLocation sendLocation;
  
  StreamSubscription<Position>? _positionSubscription;

  LocationBloc({
    required this.locationService,
    required this.sendLocation,
  }) : super(LocationInitial()) {
    on<StartTracking>(_onStartTracking);
    on<StopTracking>(_onStopTracking);
    on<LocationUpdated>(_onLocationUpdated);
  }

  Future<void> _onStartTracking(StartTracking event, Emitter<LocationState> emit) async {
    final permissionStatus = await locationService.requestPermission();
    
    if (permissionStatus == LocationPermissionStatus.denied || 
        permissionStatus == LocationPermissionStatus.deniedForever) {
      emit(const LocationPermissionDenied("Location permission is required for tracking to work."));
      return;
    }

    emit(LocationTracking());

    await _positionSubscription?.cancel();
    _positionSubscription = locationService.getPositionStream().listen(
      (Position position) {
        if (!isClosed) {
          add(LocationUpdated(position));
        }
      },
      onError: (error) {
        if (!isClosed) {
          add(StopTracking());
        }
      },
    );
  }

  Future<void> _onStopTracking(StopTracking event, Emitter<LocationState> emit) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    emit(LocationInitial());
  }

  Future<void> _onLocationUpdated(LocationUpdated event, Emitter<LocationState> emit) async {
    if (state is LocationTracking) {
      try {
        final locationEntity = LocationEntity(
          lat: event.position.latitude,
          lng: event.position.longitude,
          speed: event.position.speed,
          battery: 100.0, // Mocked battery since fetching native battery requires another package
          network: 'cellular', // Mocked network type
          timestamp: event.position.timestamp ?? DateTime.now(),
        );

        final alerts = await sendLocation(locationEntity);
        print('ALERTS RETURNED FROM BACKEND: $alerts');
        emit(LocationTracking(alerts: alerts));
      } catch (e) {
        // We log or handle error, but usually keep tracking state active
        // so we don't break the background loop.
        print('Error sending location: $e');
      }
    }
  }

  @override
  Future<void> close() {
    _positionSubscription?.cancel();
    return super.close();
  }
}
