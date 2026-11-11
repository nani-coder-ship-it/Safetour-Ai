import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Supported types of geofence safety zones
enum MapZoneType {
  safe,
  warning,
  danger,
}

/// Domain entity representing a vector geofence polygon (Safe / Danger Zone)
class MapZoneEntity {
  final String id;
  final String name;
  final MapZoneType zoneType;
  final List<LatLng> points;
  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;

  const MapZoneEntity({
    required this.id,
    required this.name,
    required this.zoneType,
    required this.points,
    required this.strokeColor,
    required this.fillColor,
    this.strokeWidth = 2.5,
  });

  /// Factory constructor to parse GeoJSON polygon format commonly used in MongoDB
  /// GeoJSON coordinates structure: [ [ [longitude, latitude], ... ] ]
  factory MapZoneEntity.fromGeoJson(Map<String, dynamic> json) {
    final String id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    final String name = json['name']?.toString() ?? 'Safety Zone';
    final String rawType = (json['zoneType'] ?? json['type'] ?? 'danger').toString().toLowerCase();

    MapZoneType zoneType = MapZoneType.danger;
    Color strokeColor = const Color(0xFFDC2626); // Crimson Red
    Color fillColor = const Color(0x33DC2626); // 20% transparent fill

    if (rawType.contains('safe') || rawType == 'green') {
      zoneType = MapZoneType.safe;
      strokeColor = const Color(0xFF10B981); // Emerald Green
      fillColor = const Color(0x3310B981);
    } else if (rawType.contains('warn') || rawType == 'amber' || rawType == 'orange') {
      zoneType = MapZoneType.warning;
      strokeColor = const Color(0xFFF59E0B); // Amber
      fillColor = const Color(0x33F59E0B);
    }

    final points = <LatLng>[];

    try {
      final polygonData = json['polygon'] as Map<String, dynamic>?;
      final coordinates = (polygonData != null ? polygonData['coordinates'] : json['coordinates']) as List<dynamic>?;

      if (coordinates != null && coordinates.isNotEmpty) {
        // First ring of polygon
        final outerRing = coordinates[0] as List<dynamic>;
        for (final coord in outerRing) {
          if (coord is List && coord.length >= 2) {
            // GeoJSON coordinates are [longitude, latitude]
            final double lng = (coord[0] as num).toDouble();
            final double lat = (coord[1] as num).toDouble();
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

    return MapZoneEntity(
      id: id,
      name: name,
      zoneType: zoneType,
      points: points,
      strokeColor: strokeColor,
      fillColor: fillColor,
    );
  }
}
