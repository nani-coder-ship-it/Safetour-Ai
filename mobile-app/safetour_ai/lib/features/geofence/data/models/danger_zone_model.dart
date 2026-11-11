import 'package:latlong2/latlong.dart';
import '../../domain/entities/danger_zone_entity.dart';

class DangerZoneModel extends DangerZoneEntity {
  const DangerZoneModel({
    required super.id,
    required super.name,
    required super.riskLevel,
    required super.riskScore,
    required super.category,
    super.description,
    required super.polygonPoints,
  });

  factory DangerZoneModel.fromJson(Map<String, dynamic> json) {
    final String id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final String name = json['name']?.toString() ?? 'Danger Zone';

    // Parse riskLevel or map from backend zoneType ('red', 'yellow', 'green', 'blue')
    final String rawRisk = (json['riskLevel'] ?? json['zoneType'] ?? 'danger').toString().toLowerCase();
    String riskLevel = 'danger';
    if (rawRisk == 'red' || rawRisk.contains('danger')) {
      riskLevel = 'danger';
    } else if (rawRisk == 'yellow' || rawRisk.contains('caution') || rawRisk.contains('warn')) {
      riskLevel = 'caution';
    } else if (rawRisk == 'green' || rawRisk == 'blue' || rawRisk.contains('safe')) {
      riskLevel = 'safe';
    }

    // Parse riskScore (0.0 to 10.0 scale)
    double riskScore;
    if (json['riskScore'] != null) {
      riskScore = (json['riskScore'] as num).toDouble();
    } else {
      if (riskLevel == 'danger') {
        riskScore = 9.0;
      } else if (riskLevel == 'caution') {
        riskScore = 5.0;
      } else {
        riskScore = 1.0;
      }
    }

    final String category = json['category']?.toString() ?? 'general';
    final String? description = json['description']?.toString();

    // Parse GeoJSON Polygon coordinates
    // GeoJSON structure: [[[lng, lat], [lng, lat], ...]]
    final List<LatLng> points = [];
    try {
      final dynamic polygonObj = json['polygon'] ?? json['boundary'] ?? json['geometry'];
      List<dynamic>? rawCoords;

      if (polygonObj is Map<String, dynamic>) {
        rawCoords = polygonObj['coordinates'] as List<dynamic>?;
      } else if (json['coordinates'] is List<dynamic>) {
        rawCoords = json['coordinates'] as List<dynamic>?;
      }

      if (rawCoords != null && rawCoords.isNotEmpty) {
        // Outer linear ring of polygon is the first element
        final dynamic firstElement = rawCoords[0];
        final List<dynamic> outerRing = firstElement is List ? firstElement : rawCoords;

        for (final item in outerRing) {
          if (item is List && item.length >= 2) {
            // GeoJSON coordinates order is [longitude, latitude]
            // We must flip it to LatLng(latitude, longitude)
            final double lng = (item[0] as num).toDouble();
            final double lat = (item[1] as num).toDouble();
            if (!lat.isNaN && !lat.isInfinite && !lng.isNaN && !lng.isInfinite &&
                lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0) {
              points.add(LatLng(lat, lng));
            }
          }
        }
      }
    } catch (_) {
      // Fallback empty points on format exception
    }

    return DangerZoneModel(
      id: id,
      name: name,
      riskLevel: riskLevel,
      riskScore: riskScore,
      category: category,
      description: description,
      polygonPoints: points,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'riskLevel': riskLevel,
      'riskScore': riskScore,
      'category': category,
      'description': description,
      'polygon': {
        'type': 'Polygon',
        'coordinates': [
          polygonPoints.map((p) => [p.longitude, p.latitude]).toList(),
        ],
      },
    };
  }
}
