import '../../data/models/alert_model.dart';

abstract class AlertsState {
  const AlertsState();
}

class AlertsInitial extends AlertsState {
  const AlertsInitial();
}

class AlertsLoading extends AlertsState {
  const AlertsLoading();
}

class AlertsLoaded extends AlertsState {
  final List<AlertModel> alerts;
  final int unreadCount;
  final String selectedCategory;

  const AlertsLoaded({
    required this.alerts,
    this.unreadCount = 0,
    this.selectedCategory = 'all',
  });

  List<AlertModel> get filteredAlerts {
    if (selectedCategory == 'all') return alerts;
    return alerts.where((a) {
      if (selectedCategory == 'critical') return a.severity == 'critical';
      if (selectedCategory == 'weather') return a.type == 'weather';
      if (selectedCategory == 'geofence') return a.type == 'geofence';
      if (selectedCategory == 'wildlife') return a.type == 'wildlife';
      if (selectedCategory == 'travel') {
        return a.type == 'roadblock' || a.type == 'advisory';
      }
      return true;
    }).toList();
  }

  AlertModel? get highestSeverityAlert {
    if (alerts.isEmpty) return null;
    final critical = alerts.where((a) => a.severity == 'critical' && a.status == 'active');
    if (critical.isNotEmpty) return critical.first;
    final warning = alerts.where((a) => a.severity == 'warning' && a.status == 'active');
    if (warning.isNotEmpty) return warning.first;
    final advisory = alerts.where((a) => a.severity == 'advisory' && a.status == 'active');
    if (advisory.isNotEmpty) return advisory.first;
    return alerts.first;
  }

  AlertsLoaded copyWith({
    List<AlertModel>? alerts,
    int? unreadCount,
    String? selectedCategory,
  }) {
    return AlertsLoaded(
      alerts: alerts ?? this.alerts,
      unreadCount: unreadCount ?? this.unreadCount,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }
}

class AlertsError extends AlertsState {
  final String message;
  const AlertsError(this.message);
}
