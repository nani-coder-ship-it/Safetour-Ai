import '../../domain/entities/location_entity.dart';

class LocationModel extends LocationEntity {
  LocationModel({
    required super.lat,
    required super.lng,
    required super.speed,
    required super.battery,
    required super.network,
    required super.timestamp,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      battery: (json['battery'] as num).toDouble(),
      network: json['network'] as String? ?? 'unknown',
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'battery': battery,
      'network': network,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
