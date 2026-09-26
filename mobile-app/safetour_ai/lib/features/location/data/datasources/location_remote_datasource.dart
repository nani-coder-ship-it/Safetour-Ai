import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/location_model.dart';

abstract class LocationRemoteDataSource {
  Future<List<String>> sendLocation(LocationModel location);
  Future<LocationModel?> getLatestLocation(String userId);
}

class LocationRemoteDataSourceImpl implements LocationRemoteDataSource {
  final DioClient dioClient;

  LocationRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<String>> sendLocation(LocationModel location) async {
    try {
      final response = await dioClient.dio.post('/location', data: location.toJson());
      
      final data = response.data['data'];
      if (data != null && data['triggeredAlerts'] != null) {
        final alerts = data['triggeredAlerts'] as List<dynamic>;
        return alerts.map((alert) => alert['message'] as String).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException('Failed to send location');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<LocationModel?> getLatestLocation(String userId) async {
    try {
      final response = await dioClient.dio.get('/location/$userId/latest');
      if (response.data['success'] == true && response.data['data'] != null) {
        return LocationModel.fromJson(response.data['data']);
      }
      return null;
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException('Failed to get latest location');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
