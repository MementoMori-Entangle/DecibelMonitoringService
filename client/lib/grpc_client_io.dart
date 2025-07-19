import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'generated/decibel_logger.pb.dart';

abstract class GrpcClient {
  Future<List<DecibelData>> fetchDecibelLogs({
    required String host,
    required int port,
    required String accessToken,
    required String startDatetime,
    required String endDatetime,
    Duration? timeout,
  });
}

GrpcClient createGrpcClient() {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return GrpcAndroidClient();
  } else {
    throw UnimplementedError('This platform is not supported yet.');
  }
}

class GrpcAndroidClient implements GrpcClient {
  static const MethodChannel _channel = MethodChannel('mtls_grpc');

  @override
  Future<List<DecibelData>> fetchDecibelLogs({
    required String host,
    required int port,
    required String accessToken,
    required String startDatetime,
    required String endDatetime,
    Duration? timeout,
  }) async {
    final params = {
      'method': 'getDecibelLog',
      'host': host,
      'port': port,
      'accessToken': accessToken,
      'startDatetime': startDatetime,
      'endDatetime': endDatetime,
      if (timeout != null) 'timeoutMillis': timeout.inMilliseconds,
    };
    final result = await _channel.invokeMethod<String>('getDecibelLog', params);
    if (result == null) throw Exception('gRPCネイティブクライアントからnullレスポンス');
    final decoded = jsonDecode(result);
    if (decoded is Map && decoded['logs'] is List) {
      return (decoded['logs'] as List)
          .map(
            (e) =>
                DecibelData()
                  ..datetime = e['datetime']
                  ..decibel = (e['decibel'] as num).toDouble(),
          )
          .toList();
    } else {
      throw Exception('不正なレスポンス: $result');
    }
  }
}
