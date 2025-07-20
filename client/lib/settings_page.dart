import 'package:flutter/material.dart';
import 'settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settings = SettingsService();
  List<ConnectionConfig> _configs = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configs = await _settings.getConfigs();
    final idx = await _settings.getSelectedConfigIndex();
    setState(() {
      _configs = configs;
      _selectedIndex = idx.clamp(0, configs.length - 1);
    });
  }

  Future<void> _save() async {
    await _settings.saveConfigs(_configs);
    await _settings.setSelectedConfigIndex(_selectedIndex);
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('接続先設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...List.generate(_configs.length, _buildConfigEditor),
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
