// This is a generated file - do not edit.
//
// Generated from decibel_logger.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class DecibelLogRequest extends $pb.GeneratedMessage {
  factory DecibelLogRequest({
    $core.String? accessToken,
    $core.String? startDatetime,
    $core.String? endDatetime,
  }) {
    final result = create();
    if (accessToken != null) result.accessToken = accessToken;
    if (startDatetime != null) result.startDatetime = startDatetime;
    if (endDatetime != null) result.endDatetime = endDatetime;
    return result;
  }

  DecibelLogRequest._();

  factory DecibelLogRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecibelLogRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecibelLogRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'decibelmonitor'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aOS(2, _omitFieldNames ? '' : 'startDatetime')
    ..aOS(3, _omitFieldNames ? '' : 'endDatetime')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecibelLogRequest clone() => DecibelLogRequest()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecibelLogRequest copyWith(void Function(DecibelLogRequest) updates) =>
      super.copyWith((message) => updates(message as DecibelLogRequest))
          as DecibelLogRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecibelLogRequest create() => DecibelLogRequest._();
  @$core.override
  DecibelLogRequest createEmptyInstance() => create();
  static $pb.PbList<DecibelLogRequest> createRepeated() =>
      $pb.PbList<DecibelLogRequest>();
  @$core.pragma('dart2js:noInline')
  static DecibelLogRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecibelLogRequest>(create);
  static DecibelLogRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get startDatetime => $_getSZ(1);
  @$pb.TagNumber(2)
  set startDatetime($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStartDatetime() => $_has(1);
  @$pb.TagNumber(2)
  void clearStartDatetime() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get endDatetime => $_getSZ(2);
  @$pb.TagNumber(3)
  set endDatetime($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEndDatetime() => $_has(2);
  @$pb.TagNumber(3)
  void clearEndDatetime() => $_clearField(3);
}

class DecibelData extends $pb.GeneratedMessage {
  factory DecibelData({
    $core.String? datetime,
    $core.double? decibel,
  }) {
    final result = create();
    if (datetime != null) result.datetime = datetime;
    if (decibel != null) result.decibel = decibel;
    return result;
  }

  DecibelData._();

  factory DecibelData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecibelData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecibelData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'decibelmonitor'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'datetime')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'decibel', $pb.PbFieldType.OF)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecibelData clone() => DecibelData()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecibelData copyWith(void Function(DecibelData) updates) =>
      super.copyWith((message) => updates(message as DecibelData))
          as DecibelData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecibelData create() => DecibelData._();
  @$core.override
  DecibelData createEmptyInstance() => create();
  static $pb.PbList<DecibelData> createRepeated() => $pb.PbList<DecibelData>();
  @$core.pragma('dart2js:noInline')
  static DecibelData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecibelData>(create);
  static DecibelData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get datetime => $_getSZ(0);
  @$pb.TagNumber(1)
  set datetime($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDatetime() => $_has(0);
  @$pb.TagNumber(1)
  void clearDatetime() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get decibel => $_getN(1);
  @$pb.TagNumber(2)
  set decibel($core.double value) => $_setFloat(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDecibel() => $_has(1);
  @$pb.TagNumber(2)
  void clearDecibel() => $_clearField(2);
}

class DecibelLogResponse extends $pb.GeneratedMessage {
  factory DecibelLogResponse({
    $core.Iterable<DecibelData>? logs,
  }) {
    final result = create();
    if (logs != null) result.logs.addAll(logs);
    return result;
  }

  DecibelLogResponse._();

  factory DecibelLogResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DecibelLogResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DecibelLogResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'decibelmonitor'),
      createEmptyInstance: create)
    ..pc<DecibelData>(1, _omitFieldNames ? '' : 'logs', $pb.PbFieldType.PM,
        subBuilder: DecibelData.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecibelLogResponse clone() => DecibelLogResponse()..mergeFromMessage(this);
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DecibelLogResponse copyWith(void Function(DecibelLogResponse) updates) =>
      super.copyWith((message) => updates(message as DecibelLogResponse))
          as DecibelLogResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DecibelLogResponse create() => DecibelLogResponse._();
  @$core.override
  DecibelLogResponse createEmptyInstance() => create();
  static $pb.PbList<DecibelLogResponse> createRepeated() =>
      $pb.PbList<DecibelLogResponse>();
  @$core.pragma('dart2js:noInline')
  static DecibelLogResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DecibelLogResponse>(create);
  static DecibelLogResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DecibelData> get logs => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
