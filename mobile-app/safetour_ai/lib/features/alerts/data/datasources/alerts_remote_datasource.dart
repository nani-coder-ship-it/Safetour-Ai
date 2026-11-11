import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/alert_model.dart';

abstract class AlertsRemoteDataSource {
  Future<List<AlertModel>> getUserAlerts({double? lat, double? lng, double? radius});
  Future<int> getUnreadCount({double? lat, double? lng, double? radius});
  Future<bool> markAlertAsRead(String id);
}

class AlertsRemoteDataSourceImpl implements AlertsRemoteDataSource {
  final DioClient dioClient;

  AlertsRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<List<AlertModel>> getUserAlerts({double? lat, double? lng, double? radius}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (lat != null && lng != null) {
        queryParams['lat'] = lat;
        queryParams['lng'] = lng;
        if (radius != null) queryParams['radius'] = radius;
      }

      final response = await dioClient.dio.get('/alerts', queryParameters: queryParams);
      if (response.data['success'] == true && response.data['data'] != null) {
        final list = response.data['data'] as List<dynamic>;
        return list.map((json) => AlertModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException('Failed to retrieve alerts');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<int> getUnreadCount({double? lat, double? lng, double? radius}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (lat != null && lng != null) {
        queryParams['lat'] = lat;
        queryParams['lng'] = lng;
        if (radius != null) queryParams['radius'] = radius;
      }

      final response = await dioClient.dio.get('/alerts/unread-count', queryParameters: queryParams);
      if (response.data['success'] == true && response.data['data'] != null) {
        return response.data['data']['unreadCount'] as int? ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<bool> markAlertAsRead(String id) async {
    try {
      final response = await dioClient.dio.patch('/alerts/$id/read');
      return response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
