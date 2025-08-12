import 'dart:convert';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class ConnectionConfig {
  String host;
  int port;
  String accessToken;
  int timeoutMillis;

  ConnectionConfig({
    required this.host,
    required this.port,
    required this.accessToken,
    required this.timeoutMillis,
  });

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) =>
      ConnectionConfig(
        host: json['host'] ?? AppConfig.defaultHost,
        port: json['port'] ?? AppConfig.defaultPort,
        accessToken: json['accessToken'] ?? AppConfig.defaultAccessToken,
        timeoutMillis: json['timeoutMillis'] ?? 10000,
      );
  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'accessToken': accessToken,
    'timeoutMillis': timeoutMillis,
  };
}

class SettingsService {
  static final _key = encrypt.Key.fromUtf8(
    AppConfig.encryptionKey
        .padRight(AppConfig.encryptionKeyLength, '0')
        .substring(0, AppConfig.encryptionKeyLength),
  );
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));
  static const _pinClusterRadiusKey = 'pinClusterRadiusMeter';

  Future<double> getPinClusterRadiusMeter() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_pinClusterRadiusKey);
    if (v == null || v < AppConfig.minPinClusterRadiusMeter) {
      return AppConfig.defaultPinClusterRadiusMeter;
    }
    return v;
  }

  Future<void> setPinClusterRadiusMeter(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final v =
        value < AppConfig.minPinClusterRadiusMeter
            ? AppConfig.minPinClusterRadiusMeter
            : value;
    await prefs.setDouble(_pinClusterRadiusKey, v);
  }

  static const _showGpsKey = 'showGps';
  Future<bool?> getShowGps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showGpsKey);
  }

  Future<void> setShowGps(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showGpsKey, value);
  }

  static const _decibelThresholdKey = 'decibelThreshold';
  Future<double> getDecibelThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_decibelThresholdKey) ??
        AppConfig.defaultDecibelThreshold;
  }

  Future<void> setDecibelThreshold(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_decibelThresholdKey, value);
  }

  static const _autoWatchEnabledKey = 'autoWatchEnabled';
  static const _autoWatchIntervalSecKey = 'autoWatchIntervalSec';
  Future<bool> getAutoWatchEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoWatchEnabledKey) ?? false;
  }

  Future<void> setAutoWatchEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoWatchEnabledKey, enabled);
  }

  Future<int> getAutoWatchIntervalSec() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoWatchIntervalSecKey) ??
        AppConfig.defaultAutoWatchIntervalSec;
  }

  Future<void> setAutoWatchIntervalSec(int sec) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoWatchIntervalSecKey, sec);
  }

  static const _configsKey = 'connectionConfigs';
  static const _selectedIndexKey = 'selectedConfigIndex';

  Future<List<ConnectionConfig>> getConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_configsKey);
    if (str == null) {
      // 初回はデフォルト1件
      return [
        ConnectionConfig(
          host: AppConfig.defaultHost,
          port: AppConfig.defaultPort,
          accessToken: AppConfig.defaultAccessToken,
          timeoutMillis: 10000,
        ),
      ];
    }
    if (AppConfig.encryptionKey.isEmpty) {
      // 暗号化キー未設定なら平文
      final List<dynamic> list = json.decode(str);
      return list.map((e) => ConnectionConfig.fromJson(e)).toList();
    }
    try {
      final parts = str.split(':');
      if (parts.length == 2) {
        final iv = encrypt.IV.fromBase64(parts[0]);
        final encrypted = parts[1];
        final decrypted = _encrypter.decrypt64(encrypted, iv: iv);
        final List<dynamic> list = json.decode(decrypted);
        return list.map((e) => ConnectionConfig.fromJson(e)).toList();
      } else {
        return [];
      }
    } catch (e) {
      // 復号失敗時は空リスト
      return [];
    }
  }

  Future<void> saveConfigs(List<ConnectionConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(configs.map((e) => e.toJson()).toList());
    if (AppConfig.encryptionKey.isEmpty) {
      // 暗号化キー未設定なら平文保存
      await prefs.setString(_configsKey, jsonStr);
    } else {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = _encrypter.encrypt(jsonStr, iv: iv);
      final saveValue = '${iv.base64}:${encrypted.base64}';
      await prefs.setString(_configsKey, saveValue);
    }
  }

  Future<int> getSelectedConfigIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedIndexKey) ?? 0;
  }

  Future<void> setSelectedConfigIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedIndexKey, index);
  }

  Future<String> getHost() async {
    final configs = await getConfigs();
    final idx = await getSelectedConfigIndex();
    if (idx < 0 || idx >= configs.length) {
      return AppConfig.defaultHost;
    }
    return configs[idx].host;
  }

  Future<int> getPort() async {
    final configs = await getConfigs();
    final idx = await getSelectedConfigIndex();
    if (idx < 0 || idx >= configs.length) {
      return AppConfig.defaultPort;
    }
    return configs[idx].port;
  }

  Future<String> getAccessToken() async {
    final configs = await getConfigs();
    final idx = await getSelectedConfigIndex();
    if (idx < 0 || idx >= configs.length) {
      return AppConfig.defaultAccessToken;
    }
    return configs[idx].accessToken;
  }

  Future<int?> getTimeoutMillis() async {
    final configs = await getConfigs();
    final idx = await getSelectedConfigIndex();
    if (idx < 0 || idx >= configs.length) {
      return 10000; // Default timeout
    }
    return configs[idx].timeoutMillis;
  }
}
