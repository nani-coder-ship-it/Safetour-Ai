import 'package:geolocator/geolocator.dart';
import '../../domain/entities/poi_entity.dart';

class PoiModel extends PoiEntity {
  const PoiModel({
    required super.osmId,
    required super.name,
    required super.type,
    super.subType,
    super.address,
    super.phone,
    super.website,
    required super.lat,
    required super.lng,
    super.rating,
    super.distanceMeters,
  });

  factory PoiModel.fromJson(Map<String, dynamic> json, {double? userLat, double? userLng}) {
    final lat = (json['lat'] as num).toDouble();
    final lng = (json['lng'] as num).toDouble();

    double? distance;
    if (userLat != null && userLng != null) {
      distance = Geolocator.distanceBetween(userLat, userLng, lat, lng);
    }

    return PoiModel(
      osmId: json['osmId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Place',
      type: json['type']?.toString() ?? 'tourist_spot',
      subType: json['subType']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      website: json['website']?.toString(),
      lat: lat,
      lng: lng,
      rating: json['rating'] != null ? (json['rating'] as num).toDouble() : null,
      distanceMeters: distance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'osmId': osmId,
      'name': name,
      'type': type,
      'subType': subType,
      'address': address,
      'phone': phone,
      'website': website,
      'lat': lat,
      'lng': lng,
      'rating': rating,
    };
  }
}
