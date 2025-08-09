import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';
import 'main.dart' show registerAutoWatchTaskIfNeeded;
import 'settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _pinClusterRadiusController =
      TextEditingController();
  double _pinClusterRadius = AppConfig.defaultPinClusterRadiusMeter;
  bool _showGps = false;
  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _load();
    _intervalController.text = AppConfig.defaultAutoWatchIntervalSec.toString();
    _thresholdController.text = AppConfig.defaultDecibelThreshold.toString();
    _pinClusterRadiusController.text =
        AppConfig.defaultPinClusterRadiusMeter.toString();
  }

  Future<void> _requestNotificationPermission() async {
    await Permission.notification.request();
  }

  final TextEditingController _thresholdController = TextEditingController();
  double _decibelThreshold = AppConfig.defaultDecibelThreshold;
  bool _autoWatchEnabled = false;
  final TextEditingController _intervalController = TextEditingController();
  int _autoWatchIntervalSec = AppConfig.defaultAutoWatchIntervalSec;
  final _settings = SettingsService();
  List<ConnectionConfig> _configs = [];
  int _selectedIndex = 0;

  Future<void> _load() async {
    final configs = await _settings.getConfigs();
    final idx = await _settings.getSelectedConfigIndex();
    final enabled = await _settings.getAutoWatchEnabled();
    final interval = await _settings.getAutoWatchIntervalSec();
    final threshold = await _settings.getDecibelThreshold();
    final showGps = await _settings.getShowGps() ?? false;
    final pinClusterRadius = await _settings.getPinClusterRadiusMeter();
    setState(() {
      _configs = configs;
      _selectedIndex = idx.clamp(0, configs.length - 1);
      _autoWatchEnabled = enabled;
      _autoWatchIntervalSec = interval;
      _intervalController.text = interval.toString();
      _decibelThreshold = threshold;
      _thresholdController.text = threshold.toString();
      _showGps = showGps;
      _pinClusterRadius = pinClusterRadius;
      _pinClusterRadiusController.text = pinClusterRadius.toString();
    });
  }

  Future<void> _save() async {
    await _settings.saveConfigs(_configs);
    await _settings.setSelectedConfigIndex(_selectedIndex);
    await _settings.setAutoWatchEnabled(_autoWatchEnabled);
    await _settings.setAutoWatchIntervalSec(_autoWatchIntervalSec);
    await _settings.setDecibelThreshold(_decibelThreshold);
    await _settings.setShowGps(_showGps);
    await _settings.setPinClusterRadiusMeter(_pinClusterRadius);
    // 監視タスクの登録/解除を即時反映
    await registerAutoWatchTaskIfNeeded();
    if (mounted) Navigator.of(context).pop();
  }

  void _addConfig() {
    setState(() {
      _configs.add(
        ConnectionConfig(
          host: '',
          port: 50051,
          accessToken: '',
          timeoutMillis: 10000,
        ),
      );
      _selectedIndex = _configs.length - 1;
    });
  }

  void _removeConfig(int idx) {
    if (_configs.length <= 1) return;
    setState(() {
      _configs.removeAt(idx);
      if (_selectedIndex >= _configs.length) {
        _selectedIndex = _configs.length - 1;
      }
    });
  }

  Widget _buildConfigEditor(int idx) {
    final config = _configs[idx];
    return Card(
      color: idx == _selectedIndex ? Colors.blue[50] : null,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<int>(
                  value: idx,
                  groupValue: _selectedIndex,
                  onChanged: (v) {
                    setState(() {
                      _selectedIndex = v!;
                    });
                  },
                ),
                const Text('この接続先を選択'),
                const Spacer(),
                if (_configs.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: '削除',
                    onPressed: () => _removeConfig(idx),
                  ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'gRPCサーバーHost'),
              controller: TextEditingController(text: config.host),
              onChanged: (v) => config.host = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'gRPCサーバーPort'),
              keyboardType: TextInputType.number,
              controller: TextEditingController(text: config.port.toString()),
              onChanged: (v) => config.port = int.tryParse(v) ?? 50051,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'アクセストークン'),
              controller: TextEditingController(text: config.accessToken),
              onChanged: (v) => config.accessToken = v,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'gRPCタイムアウト（ミリ秒）',
                hintText: '例: 10000',
              ),
              keyboardType: TextInputType.number,
              controller: TextEditingController(
                text: config.timeoutMillis.toString(),
              ),
              onChanged: (v) => config.timeoutMillis = int.tryParse(v) ?? 10000,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _thresholdController.dispose();
    _pinClusterRadiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('接続先設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...List.generate(_configs.length, _buildConfigEditor),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('GPSデータを表示'),
            value: _showGps,
            onChanged: (v) {
              setState(() {
                _showGps = v;
              });
            },
          ),
          SwitchListTile(
            title: const Text('自動監視（バックグラウンド取得&通知）'),
            value: _autoWatchEnabled,
            onChanged: (v) {
              setState(() {
                _autoWatchEnabled = v;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: TextField(
              controller: _pinClusterRadiusController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'ピンまとめ距離（メートル）',
                hintText: '5以上の値を入力（デフォルト: 5）',
              ),
              onChanged: (v) {
                double val =
                    double.tryParse(v) ??
                    AppConfig.defaultPinClusterRadiusMeter;
                if (val < AppConfig.minPinClusterRadiusMeter) {
                  val = AppConfig.minPinClusterRadiusMeter;
                }
                setState(() {
                  _pinClusterRadius = val;
                });
              },
              onEditingComplete: () {
                double val =
                    double.tryParse(_pinClusterRadiusController.text) ??
                    AppConfig.defaultPinClusterRadiusMeter;
                if (val < AppConfig.minPinClusterRadiusMeter) {
                  val = AppConfig.minPinClusterRadiusMeter;
                  setState(() {
                    _pinClusterRadius = val;
                    _pinClusterRadiusController.text = val.toString();
                  });
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: TextField(
              controller: _intervalController,
              enabled: _autoWatchEnabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
              ),
              decoration: const InputDecoration(
                labelText: '監視間隔（秒）',
                hintText:
                    '${AppConfig.defaultAutoWatchIntervalSec}以上の整数（最低値: 900秒）',
              ),
              onSubmitted: (v) {
                final val =
                    int.tryParse(v) ?? AppConfig.defaultAutoWatchIntervalSec;
                setState(() {
                  _autoWatchIntervalSec =
                      val < AppConfig.defaultAutoWatchIntervalSec
                          ? AppConfig.defaultAutoWatchIntervalSec
                          : val;
                  _intervalController.text = _autoWatchIntervalSec.toString();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
            child: TextField(
              controller: _thresholdController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'デシベル閾値',
                hintText: '例: 70.0',
              ),
              onChanged: (v) {
                final val = double.tryParse(v) ?? 70.0;
                setState(() {
                  _decibelThreshold = val;
                  _thresholdController.text = _decibelThreshold.toString();
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _addConfig,
                icon: const Icon(Icons.add),
                label: const Text('接続先を追加'),
              ),
              const Spacer(),
              ElevatedButton(onPressed: _save, child: const Text('保存')),
            ],
          ),
        ],
      ),
    );
  }
}
