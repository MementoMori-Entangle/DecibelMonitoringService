// This is a generated file - do not edit.
//
// Generated from decibel_logger.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use decibelLogRequestDescriptor instead')
const DecibelLogRequest$json = {
  '1': 'DecibelLogRequest',
  '2': [
    {'1': 'access_token', '3': 1, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'start_datetime', '3': 2, '4': 1, '5': 9, '10': 'startDatetime'},
    {'1': 'end_datetime', '3': 3, '4': 1, '5': 9, '10': 'endDatetime'},
  ],
};

/// Descriptor for `DecibelLogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decibelLogRequestDescriptor = $convert.base64Decode(
    'ChFEZWNpYmVsTG9nUmVxdWVzdBIhCgxhY2Nlc3NfdG9rZW4YASABKAlSC2FjY2Vzc1Rva2VuEi'
    'UKDnN0YXJ0X2RhdGV0aW1lGAIgASgJUg1zdGFydERhdGV0aW1lEiEKDGVuZF9kYXRldGltZRgD'
    'IAEoCVILZW5kRGF0ZXRpbWU=');

@$core.Deprecated('Use decibelDataDescriptor instead')
const DecibelData$json = {
  '1': 'DecibelData',
  '2': [
    {'1': 'datetime', '3': 1, '4': 1, '5': 9, '10': 'datetime'},
    {'1': 'decibel', '3': 2, '4': 1, '5': 2, '10': 'decibel'},
  ],
};

/// Descriptor for `DecibelData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decibelDataDescriptor = $convert.base64Decode(
    'CgtEZWNpYmVsRGF0YRIaCghkYXRldGltZRgBIAEoCVIIZGF0ZXRpbWUSGAoHZGVjaWJlbBgCIA'
    'EoAlIHZGVjaWJlbA==');

@$core.Deprecated('Use decibelLogResponseDescriptor instead')
const DecibelLogResponse$json = {
  '1': 'DecibelLogResponse',
  '2': [
    {
      '1': 'logs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.decibelmonitor.DecibelData',
      '10': 'logs'
    },
  ],
};

/// Descriptor for `DecibelLogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decibelLogResponseDescriptor = $convert.base64Decode(
    'ChJEZWNpYmVsTG9nUmVzcG9uc2USLwoEbG9ncxgBIAMoCzIbLmRlY2liZWxtb25pdG9yLkRlY2'
    'liZWxEYXRhUgRsb2dz');
