class LocationEntity {
  final double lat;
  final double lng;
  final double speed;
  final double battery;
  final String network;
  final DateTime timestamp;

  LocationEntity({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.battery,
    required this.network,
    required this.timestamp,
  });
}
