import 'dart:convert';

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
    final jsonStr = prefs.getString(_configsKey);
    if (jsonStr == null) {
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
    final List<dynamic> list = json.decode(jsonStr);
    return list.map((e) => ConnectionConfig.fromJson(e)).toList();
  }

  Future<void> saveConfigs(List<ConnectionConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(configs.map((e) => e.toJson()).toList());
    await prefs.setString(_configsKey, jsonStr);
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
