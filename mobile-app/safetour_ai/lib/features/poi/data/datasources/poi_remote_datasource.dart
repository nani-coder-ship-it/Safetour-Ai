import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/poi_model.dart';

abstract class PoiRemoteDataSource {
  Future<List<PoiModel>> getNearbyPOIs({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  });

  Future<List<PoiModel>> searchPlaces(String query, {double? lat, double? lng});
}

class PoiRemoteDataSourceImpl implements PoiRemoteDataSource {
  final DioClient dioClient;

  PoiRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<PoiModel>> getNearbyPOIs({
    required double lat,
    required double lng,
    required int radiusMeters,
    required String type,
    String? subType,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'type': type,
        'lat': lat,
        'lng': lng,
        'radius': radiusMeters,
      };

      if (subType != null && subType.isNotEmpty && subType != 'all') {
        queryParams['subType'] = subType;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await dioClient.dio.get(
        '/poi/nearby',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data
            .map((item) => PoiModel.fromJson(item as Map<String, dynamic>, userLat: lat, userLng: lng))
            .toList();
      } else {
        throw ServerException(response.data['message'] ?? 'Failed to fetch nearby POIs');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw NetworkException('Nearby search timed out — please try again.');
      }
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      final msg = e.response?.data?['message'] ?? e.message ?? 'Network error while fetching nearby places';
      throw ServerException(msg);
    } catch (e) {
      if (e is ServerException || e is NetworkException || e is AuthException) {
        rethrow;
      }
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<PoiModel>> searchPlaces(String query, {double? lat, double? lng}) async {
    try {
      final queryParams = <String, dynamic>{
        'q': query.trim(),
      };
      if (lat != null && lng != null) {
        queryParams['lat'] = lat;
        queryParams['lng'] = lng;
      }

      final response = await dioClient.dio.get(
        '/poi/search',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data
            .map((item) => PoiModel.fromJson(item as Map<String, dynamic>, userLat: lat, userLng: lng))
            .toList();
      } else {
        return [];
      }
    } catch (_) {
      return [];
    }
  }
}
