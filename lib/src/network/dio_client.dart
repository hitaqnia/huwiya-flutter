import 'package:dio/dio.dart';

import '../core/huwiya_config.dart';
import 'logging_interceptor.dart';

class DioClient {
  late final Dio instance;

  DioClient(HuwiyaConfig config) {
    instance = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        contentType: 'application/x-www-form-urlencoded',
      ),
    )..interceptors.add(LoggingInterceptor());
  }
}
