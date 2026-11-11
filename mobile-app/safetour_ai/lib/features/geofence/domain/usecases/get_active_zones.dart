import '../entities/danger_zone_entity.dart';
import '../repositories/geofence_repository.dart';

class GetActiveZones {
  final GeofenceRepository repository;

  GetActiveZones(this.repository);

  Future<List<DangerZoneEntity>> call({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
  }) async {
    return await repository.getActiveZones(
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
    );
  }
}
