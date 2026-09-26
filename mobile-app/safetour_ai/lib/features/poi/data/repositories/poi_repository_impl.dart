import '../../../../core/errors/failures.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/poi_entity.dart';
import '../../domain/repositories/poi_repository.dart';
import '../datasources/poi_remote_datasource.dart';

class PoiRepositoryImpl implements PoiRepository {
  final PoiRemoteDataSource remoteDataSource;

  PoiRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<PoiEntity>> getNearbyPOIs({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  }) async {
    try {
      final models = await remoteDataSource.getNearbyPOIs(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        type: type,
        subType: subType,
        search: search,
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

  @override
  Future<List<PoiEntity>> searchPlaces(String query, {double? lat, double? lng}) async {
    try {
      final models = await remoteDataSource.searchPlaces(query, lat: lat, lng: lng);
      return models;
    } catch (_) {
      return [];
    }
  }
}
