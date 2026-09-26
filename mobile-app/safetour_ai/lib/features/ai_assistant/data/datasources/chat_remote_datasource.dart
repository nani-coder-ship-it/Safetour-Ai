import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/errors/exceptions.dart';

abstract class ChatRemoteDataSource {
  Future<String> sendMessage(String message);
}

class ChatRemoteDataSourceImpl implements ChatRemoteDataSource {
  final DioClient dioClient;

  ChatRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<String> sendMessage(String message) async {
    try {
      final response = await dioClient.dio.post('/chat', data: {'message': message});
      if (response.statusCode == 200 && response.data['success']) {
        return response.data['data']['reply'] as String;
      } else {
        throw ServerException('Failed to get chat response');
      }
    } on DioException catch (e) {
      if (e.error is ServerException || e.error is NetworkException || e.error is AuthException) {
        throw e.error as Exception;
      }
      throw ServerException('Chat network error');
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
