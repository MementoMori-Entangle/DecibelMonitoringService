import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:workmanager/workmanager.dart';

import 'chart_page.dart';
import 'config.dart';
import 'generated/decibel_logger.pbgrpc.dart';
import 'grpc_client_io.dart';
import 'map_page.dart';
import 'settings_page.dart';
import 'settings_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
  runApp(const MyApp());
}

// バックグラウンドタスクのエントリポイント
@pragma('vm:entry-point')
// 監視処理本体（初回即時実行にも利用）
Future<void> runDecibelMonitorTask() async {
  // 通知初期化
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  // 設定取得
  final settings = SettingsService();
  final configs = await settings.getConfigs();
  final idx = await settings.getSelectedConfigIndex();
  if (configs.isEmpty) {
    if (kDebugMode) log('[BG] 設定が空のため処理中断');
    return;
  }
  final config = configs[idx.clamp(0, configs.length - 1)];
  final threshold = await settings.getDecibelThreshold();
  // 監視間隔前～現在のデータ取得
  final now = DateTime.now();
  final userInterval = await settings.getAutoWatchIntervalSec();
  final interval =
      (userInterval > 0) ? userInterval : AppConfig.defaultAutoWatchIntervalSec;
  final start = now.subtract(Duration(seconds: interval));
  if (kDebugMode) {
    log(
      '[BG] gRPCリクエスト送信: host=${config.host}, port=${config.port}, start=$start, end=$now, threshold=$threshold',
    );
  }
  try {
    final grpcClient = createGrpcClient();
    final logs = await grpcClient.fetchDecibelLogs(
      host: config.host,
      port: config.port,
      accessToken: config.accessToken,
      startDatetime: DateFormat(AppConfig.dateTimeFormat).format(start),
      endDatetime: DateFormat(AppConfig.dateTimeFormat).format(now),
      timeout: Duration(milliseconds: config.timeoutMillis),
    );
    if (kDebugMode) log('[BG] gRPCレスポンス件数: ${logs.length}');
    // 閾値超えがあれば通知
    final over = logs.where((d) => d.decibel > threshold).toList();
    if (kDebugMode) log('[BG] 閾値超え件数: ${over.length}');
    if (over.isNotEmpty) {
      // 最大デシベル値とそのデータ
      final maxData = over.reduce((a, b) => a.decibel >= b.decibel ? a : b);
      final maxDb = maxData.decibel;
      String maxDbTime;
      try {
        final dt = DateFormat(AppConfig.dateTimeFormat).parse(maxData.datetime);
        maxDbTime = DateFormat('yyyy/MM/dd HH:mm:ss').format(dt);
      } catch (_) {
        maxDbTime = maxData.datetime;
      }
      if (kDebugMode) log('[BG] 通知送信: 最大デシベル値=$maxDb, 日時=$maxDbTime');
      final uniqueNotificationId = DateTime.now().millisecondsSinceEpoch;
      await flutterLocalNotificationsPlugin.show(
        uniqueNotificationId,
        'デシベル警告',
        '閾値${threshold}dBを超えました: 最大${maxDb.toStringAsFixed(1)}dB（$maxDbTime）',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'decibel_channel',
            'Decibel Notifications',
            channelDescription: 'デシベル閾値超え通知',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  } catch (e) {
    if (kDebugMode) log('[BG] gRPC/通知処理エラー: $e');
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await runDecibelMonitorTask();
    return Future.value(true);
  });
}

Future<void> registerAutoWatchTaskIfNeeded() async {
  final settings = SettingsService();
  final enabled = await settings.getAutoWatchEnabled();
  final interval = await settings.getAutoWatchIntervalSec();
  final minInterval = AppConfig.defaultAutoWatchIntervalSec;
  if (enabled) {
    final freq = interval < minInterval ? minInterval : interval;
    // 初回のみ即時実行
    await runDecibelMonitorTask();
    await Workmanager().registerPeriodicTask(
      'autoWatchTask',
      'autoWatchTask',
      frequency: Duration(seconds: freq),
      initialDelay: const Duration(seconds: 0),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } else {
    await Workmanager().cancelByUniqueName('autoWatchTask');
  }
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
      // ログイン成功時にバックグラウンド監視タスクを登録
      await registerAutoWatchTaskIfNeeded();
      if (!mounted) return;
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
  // 設定画面で設定された閾値（リスト表示用）
  double? _decibelThreshold;
  DateTime? _startDate;
  DateTime? _endDate;
  List<DecibelData> _decibelList = [];
  bool _showGps = false;
  ConnectionConfig? _selectedConfig;

  // デシベル範囲用
  final TextEditingController _minDecibelController = TextEditingController();
  final TextEditingController _maxDecibelController = TextEditingController();
  double? _minDecibel;
  double? _maxDecibel;

  // gRPCクライアント
  late final GrpcClient _grpcClient;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _grpcClient = createGrpcClient();
    _loadSelectedConfig();
    _loadThreshold();
    _loadShowGps();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _minDecibelController.addListener(_onMinDecibelChanged);
    _maxDecibelController.addListener(_onMaxDecibelChanged);
  }

  Future<void> _loadShowGps() async {
    final s = await SettingsService().getShowGps();
    if (mounted) {
      setState(() {
        _showGps = s ?? false;
      });
    }
  }

  Future<void> _loadThreshold() async {
    final t = await SettingsService().getDecibelThreshold();
    if (mounted) {
      setState(() {
        _decibelThreshold = t;
      });
    }
  }

  @override
  void dispose() {
    _minDecibelController.dispose();
    _maxDecibelController.dispose();
    super.dispose();
  }

  void _onMinDecibelChanged() {
    final text = _minDecibelController.text;
    setState(() {
      _minDecibel = double.tryParse(text);
    });
  }

  void _onMaxDecibelChanged() {
    final text = _maxDecibelController.text;
    setState(() {
      _maxDecibel = double.tryParse(text);
    });
  }

  Future<void> _loadSelectedConfig() async {
    final service = SettingsService();
    final configs = await service.getConfigs();
    final idx = await service.getSelectedConfigIndex();
    if (mounted) {
      setState(() {
        if (configs.isNotEmpty) {
          _selectedConfig = configs[idx.clamp(0, configs.length - 1)];
        } else {
          _selectedConfig = null; // Handle empty configs case
        }
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
        useGps: _showGps,
      );
      // デシベル範囲で絞り込み
      List<DecibelData> filtered = _filterLogsByDecibelRange(
        logs,
        _minDecibel,
        _maxDecibel,
      );
      setState(() {
        _decibelList = filtered;
      });
    } catch (e, stackTrace) {
      if (kDebugMode) {
        log(
          'Error fetching decibel logs: $e',
          stackTrace: stackTrace,
          name: '_fetchDecibelLogs',
        );
      } else {
        log('Error fetching decibel logs', name: '_fetchDecibelLogs');
      }
      setState(() {
        _error = 'データの取得に失敗しました。';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<DecibelData> _filterLogsByDecibelRange(
    List<DecibelData> logs,
    double? min,
    double? max,
  ) {
    if (min != null && max != null) {
      return logs.where((d) => d.decibel >= min && d.decibel <= max).toList();
    } else if (min != null) {
      return logs.where((d) => d.decibel >= min).toList();
    } else if (max != null) {
      return logs.where((d) => d.decibel <= max).toList();
    }
    return logs;
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
              await _loadThreshold();
              await _loadShowGps();
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
          if (_showGps)
            IconButton(
              icon: const Icon(Icons.explore),
              tooltip: '地図表示',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MapPage(decibelList: _decibelList),
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
            child: Column(
              children: [
                Row(
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('表示'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minDecibelController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '最小デシベル値',
                          hintText: '例: 40',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _maxDecibelController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: '最大デシベル値',
                          hintText: '例: 80',
                        ),
                      ),
                    ),
                  ],
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
                final threshold =
                    _decibelThreshold ?? AppConfig.defaultDecibelThreshold;
                final isOver = d.decibel > threshold;
                return ListTile(
                  title: Text(formattedDate),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.decibel.toStringAsFixed(2)} dB',
                        style: TextStyle(color: isOver ? Colors.red : null),
                      ),
                      if (_showGps && (d.latitude != 0.0 || d.longitude != 0.0))
                        Text(
                          'GPS: ${d.latitude}, ${d.longitude}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  onTap: () async {
                    String copyText =
                        '日時: $formattedDate\n'
                        'デシベル: ${d.decibel.toStringAsFixed(2)} dB';
                    if (_showGps && (d.latitude != 0.0 || d.longitude != 0.0)) {
                      copyText += '\nGPS: ${d.latitude}, ${d.longitude}';
                    }
                    await Clipboard.setData(ClipboardData(text: copyText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('コピーしました')));
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
