import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/api_constants.dart';
import '../errors/exceptions.dart';

class DioClient {
  late final Dio dio;

  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach Firebase ID token if user is logged in
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            try {
              final token = await user.getIdToken();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              // Ignore token fetching error, proceed with request
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Convert Dio exceptions to custom Exceptions/Failures
          String errorMessage = 'An unexpected error occurred';
          if (e.response != null && e.response?.data != null) {
            final data = e.response?.data;
            if (data is Map<String, dynamic> && data.containsKey('message')) {
              errorMessage = data['message'];
            }
          } else {
            errorMessage = e.message ?? errorMessage;
          }

          if (e.type == DioExceptionType.connectionError &&
              e.requestOptions.baseUrl == ApiConstants.baseUrl &&
              ApiConstants.baseUrl != ApiConstants.wifiUrl) {
            try {
              final newOptions = Options(
                method: e.requestOptions.method,
                headers: e.requestOptions.headers,
                contentType: e.requestOptions.contentType,
                responseType: e.requestOptions.responseType,
              );
              final fallbackPath = e.requestOptions.path.startsWith('http')
                  ? e.requestOptions.path.replaceFirst(ApiConstants.baseUrl, ApiConstants.wifiUrl)
                  : '${ApiConstants.wifiUrl}${e.requestOptions.path}';
              final retryResponse = await dio.request(
                fallbackPath,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
                options: newOptions,
              );
              return handler.resolve(retryResponse);
            } catch (_) {
              // Fallback failed, proceed to standard error rejection below
            }
          }

          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.sendTimeout) {
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: NetworkException('Nearby search timed out. Please check your connection or retry.'),
                message: 'Nearby search timed out. Please check your connection or retry.',
              ),
            );
          } else if (e.type == DioExceptionType.connectionError) {
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: NetworkException('Cannot connect to server. Please check your network.'),
                message: 'Cannot connect to server. Please check your network.',
              ),
            );
          } else if (e.response?.statusCode == 401 ||
                     e.response?.statusCode == 403) {
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: AuthException(errorMessage),
                message: errorMessage,
              ),
            );
          } else {
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                response: e.response,
                type: e.type,
                error: ServerException(errorMessage),
                message: errorMessage,
              ),
            );
          }
        },
      ),
    );
  }
}
