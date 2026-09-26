enum MarkerType {
  user,
  hotel,
  tourist_spot,
  restaurant,
  hospital,
  police,
  atm,
  petrol_pump,
  bus_stop,
  toilet,
  danger,
}

class MapMarkerEntity {
  final String id;
  final double lat;
  final double lng;
  final String label;
  final MarkerType type;
  final String? subType;

  MapMarkerEntity({
    required this.id,
    required this.lat,
    required this.lng,
    required this.label,
    required this.type,
    this.subType,
  });
}
