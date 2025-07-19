// This is a generated file - do not edit.
//
// Generated from decibel_logger.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'decibel_logger.pb.dart' as $0;

export 'decibel_logger.pb.dart';

@$pb.GrpcServiceName('decibelmonitor.DecibelLogger')
class DecibelLoggerClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  DecibelLoggerClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.DecibelLogResponse> getDecibelLog(
    $0.DecibelLogRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getDecibelLog, request, options: options);
  }

  // method descriptors

  static final _$getDecibelLog =
      $grpc.ClientMethod<$0.DecibelLogRequest, $0.DecibelLogResponse>(
          '/decibelmonitor.DecibelLogger/GetDecibelLog',
          ($0.DecibelLogRequest value) => value.writeToBuffer(),
          $0.DecibelLogResponse.fromBuffer);
}

@$pb.GrpcServiceName('decibelmonitor.DecibelLogger')
abstract class DecibelLoggerServiceBase extends $grpc.Service {
  $core.String get $name => 'decibelmonitor.DecibelLogger';

  DecibelLoggerServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.DecibelLogRequest, $0.DecibelLogResponse>(
        'GetDecibelLog',
        getDecibelLog_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DecibelLogRequest.fromBuffer(value),
        ($0.DecibelLogResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.DecibelLogResponse> getDecibelLog_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.DecibelLogRequest> $request) async {
    return getDecibelLog($call, await $request);
  }

  $async.Future<$0.DecibelLogResponse> getDecibelLog(
      $grpc.ServiceCall call, $0.DecibelLogRequest request);
}
