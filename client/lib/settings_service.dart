import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
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
  static const _saltKey = 'settingsEncryptionSalt';
  static const _saltLength = 16;
  static Future<Uint8List> _getOrCreateSalt() async {
    final prefs = await SharedPreferences.getInstance();
    final saltStr = prefs.getString(_saltKey);
    if (saltStr != null) {
      return base64Decode(saltStr);
    } else {
      final salt = Uint8List.fromList(
        List<int>.generate(
          _saltLength,
          (i) => (DateTime.now().millisecondsSinceEpoch >> (i * 2)) & 0xFF,
        ),
      final salt = await Cryptography.instance.randomBytes(_saltLength);
      await prefs.setString(_saltKey, base64Encode(salt));
      return salt;
    }
  }

  static Future<encrypt.Key> _deriveKey(
    String passphrase,
    Uint8List salt,
    int length,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: length * 8,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();
    return encrypt.Key(Uint8List.fromList(keyBytes));
  }

  encrypt.Encrypter? _encrypter;
  Future<void> _initEncrypter() async {
    if (_encrypter != null) return;
    if (AppConfig.encryptionKey.isEmpty) return;
    final salt = await _getOrCreateSalt();
    final key = await _deriveKey(
      AppConfig.encryptionKey,
      salt,
      AppConfig.encryptionKeyLength,
    );
    _encrypter = encrypt.Encrypter(encrypt.AES(key));
  }

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

  Future<List<ConnectionConfig>> getConfigs({
    void Function(String)? onError,
  }) async {
    await _initEncrypter();
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
    try {
      if (AppConfig.encryptionKey.isEmpty) {
        // 暗号化キー未設定なら平文
        final List<dynamic> list = json.decode(str);
        return list.map((e) => ConnectionConfig.fromJson(e)).toList();
      }
    } catch (e) {
      // 暗号化設定情報を平文として処理しようとする場合を考慮
      if (onError != null) {
        onError('設定情報の読み込みに失敗しました。保存データをご確認ください。');
      }
      return [];
    }
    try {
      final parts = str.split(':');
      if (parts.length == 2) {
        final iv = encrypt.IV.fromBase64(parts[0]);
        final encrypted = parts[1];
        if (_encrypter == null) {
          if (onError != null) {
            onError('暗号化キーが未設定または不正です。設定情報の復号に失敗しました。');
          }
          return [];
        }
        final decrypted = _encrypter!.decrypt64(encrypted, iv: iv);
        final List<dynamic> list = json.decode(decrypted);
        return list.map((e) => ConnectionConfig.fromJson(e)).toList();
      } else {
        return [];
      }
    } catch (e) {
      // 復号失敗時は空リスト＋エラーメッセージ通知
      if (onError != null) {
        onError('設定情報の復号に失敗しました。暗号化キーや保存データをご確認ください。');
      }
      return [];
    }
  }

  Future<void> saveConfigs(List<ConnectionConfig> configs) async {
    await _initEncrypter();
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(configs.map((e) => e.toJson()).toList());
    if (AppConfig.encryptionKey.isEmpty || _encrypter == null) {
      // 暗号化キー未設定なら平文保存
      await prefs.setString(_configsKey, jsonStr);
    } else {
      final iv = encrypt.IV.fromSecureRandom(16);
      final encrypted = _encrypter!.encrypt(jsonStr, iv: iv);
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
