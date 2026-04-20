import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  static final _separator = '─' * 60;

  final Map<int, Stopwatch> _timers = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final sw = Stopwatch()..start();
    _timers[options.hashCode] = sw;

    debugPrint(_separator);
    debugPrint('→ REQUEST');
    debugPrint('  Method : ${options.method}');
    debugPrint('  URL    : ${options.uri}');
    _printHeaders('  Headers', options.headers);
    if (options.data != null) {
      debugPrint('  Body   : ${options.data}');
    }
    debugPrint('  Time   : ${DateTime.now().toIso8601String()}');
    debugPrint(_separator);

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final elapsed = _stopTimer(response.requestOptions);

    debugPrint(_separator);
    debugPrint('← RESPONSE');
    debugPrint('  Status  : ${response.statusCode}');
    debugPrint('  URL     : ${response.requestOptions.uri}');
    _printHeaders('  Headers', response.headers.map);
    debugPrint('  Body    : ${response.data}');
    debugPrint('  Elapsed : ${elapsed}ms');
    debugPrint(_separator);

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final elapsed = _stopTimer(err.requestOptions);

    debugPrint(_separator);
    debugPrint('✕ ERROR');
    debugPrint('  Type    : ${err.type}');
    debugPrint('  URL     : ${err.requestOptions.uri}');
    debugPrint('  Message : ${err.message}');
    if (err.response != null) {
      debugPrint('  Status  : ${err.response!.statusCode}');
      debugPrint('  Body    : ${err.response!.data}');
    }
    debugPrint('  Elapsed : ${elapsed}ms');
    debugPrint(_separator);

    handler.next(err);
  }

  int _stopTimer(RequestOptions options) {
    final sw = _timers.remove(options.hashCode);
    sw?.stop();
    return sw?.elapsedMilliseconds ?? -1;
  }

  void _printHeaders(String label, Map<String, dynamic> headers) {
    if (headers.isEmpty) return;
    debugPrint('$label :');
    for (final entry in headers.entries) {
      debugPrint('    ${entry.key}: ${entry.value}');
    }
  }
}
