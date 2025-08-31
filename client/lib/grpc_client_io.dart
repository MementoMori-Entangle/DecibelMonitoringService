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
    bool useGps = false,
    bool useApt = false,
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
    bool useGps = false,
    bool useApt = false,
  }) async {
    final params = {
      'method': 'getDecibelLog',
      'host': host,
      'port': port,
      'accessToken': accessToken,
      'startDatetime': startDatetime,
      'endDatetime': endDatetime,
      if (timeout != null) 'timeoutMillis': timeout.inMilliseconds,
      'useGps': useGps,
      'useApt': useApt,
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
                  ..decibel = (e['decibel'] as num).toDouble()
                  ..latitude =
                      (e['latitude'] is num)
                          ? (e['latitude'] as num).toDouble()
                          : double.tryParse(e['latitude']?.toString() ?? '') ??
                              0.0
                  ..longitude =
                      (e['longitude'] is num)
                          ? (e['longitude'] as num).toDouble()
                          : double.tryParse(e['longitude']?.toString() ?? '') ??
                              0.0
                  ..altitude =
                      (e['altitude'] is num)
                          ? (e['altitude'] as num).toDouble()
                          : double.tryParse(e['altitude']?.toString() ?? '') ??
                              0.0
                  ..pressure =
                      (e['pressure'] is num)
                          ? (e['pressure'] as num).toDouble()
                          : double.tryParse(e['pressure']?.toString() ?? '') ??
                              0.0
                  ..temperature =
                      (e['temperature'] is num)
                          ? (e['temperature'] as num).toDouble()
                          : double.tryParse(
                                e['temperature']?.toString() ?? '',
                              ) ??
                              0.0,
          )
          .toList();
    } else {
      throw Exception('不正なレスポンス: $result');
    }
  }
}
