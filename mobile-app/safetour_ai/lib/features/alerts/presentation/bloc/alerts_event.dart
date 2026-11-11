abstract class AlertsEvent {
  const AlertsEvent();
}

class LoadAlerts extends AlertsEvent {
  final bool silent;
  const LoadAlerts({this.silent = false});
}

class MarkAlertRead extends AlertsEvent {
  final String alertId;
  const MarkAlertRead(this.alertId);
}

class FilterAlertsByCategory extends AlertsEvent {
  final String category;
  const FilterAlertsByCategory(this.category);
}
