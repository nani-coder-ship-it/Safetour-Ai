import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/digital_id_model.dart';

abstract class DigitalIdRemoteDataSource {
  Future<DigitalIdModel> getMyDigitalId();
  Future<DigitalIdModel> updateDigitalId(Map<String, dynamic> updates);
  Future<Map<String, dynamic>> verifyOnChain(String identifier);
}

class DigitalIdRemoteDataSourceImpl implements DigitalIdRemoteDataSource {
  final DioClient dioClient;

  DigitalIdRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<DigitalIdModel> getMyDigitalId() async {
    try {
      final response = await dioClient.dio.get('/blockchain/id');
      if (response.data['success'] == true && response.data['data'] != null) {
        return DigitalIdModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw ServerException('Failed to retrieve Digital ID');
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException(e.response?.data?['message']?.toString() ?? 'Failed to retrieve Digital ID');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<DigitalIdModel> updateDigitalId(Map<String, dynamic> updates) async {
    try {
      final response = await dioClient.dio.put('/blockchain/id', data: updates);
      if (response.data['success'] == true && response.data['data'] != null) {
        return DigitalIdModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
      throw ServerException('Failed to update Digital ID');
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException(e.response?.data?['message']?.toString() ?? 'Failed to update Digital ID');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> verifyOnChain(String identifier) async {
    try {
      final encoded = Uri.encodeComponent(identifier.trim());
      final response = await dioClient.dio.get(
        '/blockchain/verify/$encoded',
        queryParameters: {'format': 'json'},
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );
      if (response.data is Map<String, dynamic>) {
        final dataMap = response.data as Map<String, dynamic>;
        if (dataMap['success'] == true && dataMap['data'] != null) {
          return Map<String, dynamic>.from(dataMap['data'] as Map);
        }
      }
      return {'verified': false, 'message': 'Verification check failed'};
    } catch (e) {
      return {'verified': false, 'message': e.toString()};
    }
  }
}
