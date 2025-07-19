import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import 'chart_page.dart';
import 'config.dart';
import 'generated/decibel_logger.pbgrpc.dart';
import 'grpc_client_io.dart';
import 'settings_page.dart';
import 'settings_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.title,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String _error = '';

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      authenticated = await auth.authenticate(
        localizedReason: 'Please authenticate to access decibel data',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: false,
        ),
      );
    } catch (e) {
      String message;
      if (e.toString().contains('NotAvailable')) {
        message = '認証エラー: デバイスに認証情報（生体認証やパスコード）が設定されていません。';
      } else {
        message = '認証エラー';
      }
      setState(() {
        _error = message;
      });
      return;
    }
    if (authenticated && mounted) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const TopScreen()));
    } else if (!authenticated) {
      setState(() {
        _error = '認証に失敗しました。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _authenticate,
              child: const Text('端末認証ログイン'),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_error, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class TopScreen extends StatefulWidget {
  const TopScreen({super.key});

  @override
  State<TopScreen> createState() => _TopScreenState();
}

class _TopScreenState extends State<TopScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<DecibelData> _decibelList = [];
  ConnectionConfig? _selectedConfig;

  // gRPCクライアント
  late final GrpcClient _grpcClient;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _grpcClient = createGrpcClient();
    _loadSelectedConfig();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _loadSelectedConfig() async {
    final service = SettingsService();
    final configs = await service.getConfigs();
    final idx = await service.getSelectedConfigIndex();
    if (mounted) {
      setState(() {
        _selectedConfig = configs[idx.clamp(0, configs.length - 1)];
      });
    }
  }

  Future<void> _fetchDecibelLogs() async {
    if (_startDate == null || _endDate == null || _selectedConfig == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await _grpcClient.fetchDecibelLogs(
        host: _selectedConfig!.host,
        port: _selectedConfig!.port,
        accessToken: _selectedConfig!.accessToken,
        startDatetime: DateFormat(AppConfig.dateTimeFormat).format(_startDate!),
        endDatetime: DateFormat(AppConfig.dateTimeFormat).format(_endDate!),
        timeout: Duration(milliseconds: _selectedConfig!.timeoutMillis),
      );
      setState(() {
        _decibelList = logs;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
              // 設定画面から戻ったら再取得
              await _loadSelectedConfig();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'グラフ表示',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChartPage(decibelList: _decibelList),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'アプリを終了',
            onPressed: () async {
              if (Platform.isAndroid) {
                const channel = MethodChannel('mtls_grpc');
                await channel.invokeMethod('moveTaskToBack');
              } else if (Platform.isIOS) {
                SystemNavigator.pop();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (!mounted) return;
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            _startDate ?? DateTime.now(),
                          ),
                        );
                        if (!mounted) return;
                        if (pickedTime != null) {
                          setState(
                            () =>
                                _startDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                ),
                          );
                        } else {
                          setState(
                            () =>
                                _startDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                ),
                          );
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '開始日'),
                      child: Text(
                        _startDate == null
                            ? ''
                            : DateFormat(
                              AppConfig.inputCalendarFormat,
                            ).format(_startDate!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (!mounted) return;
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            _endDate ?? DateTime.now(),
                          ),
                        );
                        if (!mounted) return;
                        if (pickedTime != null) {
                          setState(
                            () =>
                                _endDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                ),
                          );
                        } else {
                          setState(
                            () =>
                                _endDate = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                ),
                          );
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '終了日'),
                      child: Text(
                        _endDate == null
                            ? ''
                            : DateFormat(
                              AppConfig.inputCalendarFormat,
                            ).format(_endDate!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      (_startDate != null && _endDate != null && !_loading)
                          ? _fetchDecibelLogs
                          : null,
                  child:
                      _loading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('表示'),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _decibelList.length,
              itemBuilder: (context, idx) {
                final d = _decibelList[idx];
                String formattedDate;
                try {
                  final dateTime = DateFormat(
                    AppConfig.dateTimeFormat,
                  ).parse(d.datetime);
                  formattedDate = DateFormat(
                    AppConfig.dateTimeFormat,
                  ).format(dateTime);
                } catch (e) {
                  formattedDate = d.datetime;
                }
                return ListTile(
                  title: Text(formattedDate),
                  subtitle: Text('${d.decibel.toStringAsFixed(2)} dB'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
