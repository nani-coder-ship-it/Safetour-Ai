import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_remote_datasource.dart';
import '../models/location_model.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationRemoteDataSource remoteDataSource;

  LocationRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<String>> sendLocation(LocationEntity location) async {
    try {
      final model = LocationModel(
        lat: location.lat,
        lng: location.lng,
        speed: location.speed,
        battery: location.battery,
        network: location.network,
        timestamp: location.timestamp,
      );
      return await remoteDataSource.sendLocation(model);
    } on NetworkException {
      throw const NetworkFailure('Failed to connect to the server');
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }

  @override
  Future<LocationEntity?> getLatestLocation(String userId) async {
    try {
      return await remoteDataSource.getLatestLocation(userId);
    } on NetworkException {
      throw const NetworkFailure('Failed to connect to the server');
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    } catch (e) {
      throw ServerFailure(e.toString());
    }
  }
}
