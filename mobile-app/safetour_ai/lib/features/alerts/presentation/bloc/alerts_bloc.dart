import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/alerts_remote_datasource.dart';
import '../../../location/data/services/device_location_service.dart';
import '../../../../injection_container.dart';
import 'alerts_event.dart';
import 'alerts_state.dart';

class AlertsBloc extends Bloc<AlertsEvent, AlertsState> {
  final AlertsRemoteDataSource remoteDataSource;

  AlertsBloc({required this.remoteDataSource}) : super(const AlertsInitial()) {
    on<LoadAlerts>(_onLoadAlerts);
    on<MarkAlertRead>(_onMarkAlertRead);
    on<FilterAlertsByCategory>(_onFilterCategory);
  }

  Future<void> _onLoadAlerts(LoadAlerts event, Emitter<AlertsState> emit) async {
    if (!event.silent && state is! AlertsLoaded) {
      emit(const AlertsLoading());
    }

    try {
      // 1. Obtain user's real-time present location
      double? lat;
      double? lng;
      try {
        final locationService = sl<DeviceLocationService>();
        var pos = await locationService.getLastKnownPosition();
        if (pos == null) {
          pos = await locationService.getCurrentPosition();
        }
        if (pos != null) {
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}

      // 2. Execute alert retrieval and unread count strictly for the current location (2.0 km radius)
      final alertsFuture = remoteDataSource.getUserAlerts(lat: lat, lng: lng, radius: 2.0);
      final unreadFuture = remoteDataSource.getUnreadCount(lat: lat, lng: lng, radius: 2.0);

      final alerts = await alertsFuture;
      int unread;
      try {
        unread = await unreadFuture.timeout(const Duration(milliseconds: 1500));
      } catch (_) {
        unread = alerts.where((a) => !a.read || a.status == 'active').length;
      }

      final currentCategory = state is AlertsLoaded
          ? (state as AlertsLoaded).selectedCategory
          : 'all';

      emit(AlertsLoaded(
        alerts: alerts,
        unreadCount: unread,
        selectedCategory: currentCategory,
      ));
    } catch (e) {
      if (state is! AlertsLoaded) {
        emit(AlertsError(e.toString()));
      }
    }
  }

  Future<void> _onMarkAlertRead(MarkAlertRead event, Emitter<AlertsState> emit) async {
    if (state is AlertsLoaded) {
      final current = state as AlertsLoaded;
      final updatedList = current.alerts.map((a) {
        if (a.id == event.alertId) {
          return a.copyWith(read: true, status: 'acknowledged');
        }
        return a;
      }).toList();

      final newUnread = (current.unreadCount > 0) ? current.unreadCount - 1 : 0;
      emit(current.copyWith(alerts: updatedList, unreadCount: newUnread));

      // Asynchronously notify backend
      remoteDataSource.markAlertAsRead(event.alertId).catchError((_) => false);
    }
  }

  void _onFilterCategory(FilterAlertsByCategory event, Emitter<AlertsState> emit) {
    if (state is AlertsLoaded) {
      emit((state as AlertsLoaded).copyWith(selectedCategory: event.category));
    }
  }
}
