import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/danger_zone_entity.dart';
import '../../domain/repositories/geofence_repository.dart';
import '../datasources/geofence_remote_datasource.dart';

class GeofenceRepositoryImpl implements GeofenceRepository {
  final GeofenceRemoteDataSource remoteDataSource;

  GeofenceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<DangerZoneEntity>> getActiveZones({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
  }) async {
    try {
      final models = await remoteDataSource.getActiveZones(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
      );
      return models;
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } on NetworkException catch (e) {
      throw NetworkFailure(e.message);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
