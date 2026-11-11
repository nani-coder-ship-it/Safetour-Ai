import '../entities/danger_zone_entity.dart';

abstract class GeofenceRepository {
  Future<List<DangerZoneEntity>> getActiveZones({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
  });
}
