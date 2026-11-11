import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/danger_zone_model.dart';

abstract class GeofenceRemoteDataSource {
  Future<List<DangerZoneModel>> getActiveZones({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
  });
}

class GeofenceRemoteDataSourceImpl implements GeofenceRemoteDataSource {
  final DioClient dioClient;

  GeofenceRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<DangerZoneModel>> getActiveZones({
    required double lat,
    required double lng,
    int radiusMeters = 5000,
  }) async {
    try {
      final response = await dioClient.dio.get(
        '/geofence/zones',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radiusMeters,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final dynamic rawData = response.data['data'];
        if (rawData is List<dynamic>) {
          return rawData
              .map((item) => DangerZoneModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return [];
      } else {
        throw ServerException(response.data?['message'] ?? 'Failed to fetch danger zones');
      }
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException(e.message ?? 'Network error fetching danger zones');
    } catch (e) {
      if (e is ServerException || e is NetworkException || e is AuthException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }
}
