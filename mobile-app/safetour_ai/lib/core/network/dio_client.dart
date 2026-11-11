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
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 25),
        sendTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
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

          // Resilient network fallback: If current baseUrl fails with connection error or timeout,
          // immediately retry against the alternate baseUrl (USB vs Wi-Fi LAN)
          final isNetworkFailure = e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout;
          final currentBase = dio.options.baseUrl;
          final alternateBase = currentBase == ApiConstants.baseUrl
              ? ApiConstants.wifiUrl
              : ApiConstants.baseUrl;

          final wasRetried = e.requestOptions.extra['_fallbackRetried'] == true;

          if (isNetworkFailure && !wasRetried && currentBase != alternateBase) {
            try {
              final newOptions = Options(
                method: e.requestOptions.method,
                headers: e.requestOptions.headers,
                contentType: e.requestOptions.contentType,
                responseType: e.requestOptions.responseType,
                extra: {
                  ...e.requestOptions.extra,
                  '_fallbackRetried': true,
                },
              );

              final fallbackPath = e.requestOptions.path.startsWith('http')
                  ? e.requestOptions.path.replaceFirst(currentBase, alternateBase)
                  : '$alternateBase${e.requestOptions.path}';

              final retryResponse = await dio.request(
                fallbackPath,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
                options: newOptions,
              );

              // Auto-remember working URL so all future requests execute with 0ms penalty
              dio.options.baseUrl = alternateBase;
              return handler.resolve(retryResponse);
            } catch (_) {
              // Fallback also failed, proceed to standard error rejection below
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
                error: NetworkException('Connection timed out. Please check your network or server.'),
                message: 'Connection timed out. Please check your network or server.',
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
