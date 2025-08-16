/// アプリのデフォルト設定値を一元管理
class AppConfig {
  static const double defaultPinClusterRadiusMeter = 5.0;
  static const double minPinClusterRadiusMeter = 5.0;
  static const double defaultDecibelThreshold = 70.0;
  static const int defaultAutoWatchIntervalSec =
      900; // 15分(Android WorkManagerの最小値)

  static const String defaultHost = '10.0.2.2';
  static const int defaultPort = 50051;
  static const String defaultAccessToken = '';

  static const String title = 'Decibel Log Viewer';
  static const String dateTimeFormat = 'yyyy/MM/dd HH:mm:ss';
  static const String inputCalendarFormat = 'yyyy/MM/dd HH:mm';
  static const int expectedCsvColumns = 4;
  static const String csvFileName = 'decibel_data';
  static const String csvFileExp = 'csv';
  static const String exportFileName = 'settings';
  static const String jsonFileExp = 'json';
  // AndroidのDownloadディレクトリ
  static const String downloadPath = 'Download';
  static const Map<String, String> downloadPathMap = {
    'Download': '/storage/emulated/0/Download',
  };

  // 暗号化キー（32文字=256bit）: 環境変数 DECIBEL_ENCRYPTION_KEY から取得
  static const int encryptionKeyLength = 32;
  static String get encryptionKey {
    const defaultKey = ''; // 暗号化キー空は平文処理
    final envKey = const String.fromEnvironment('DECIBEL_ENCRYPTION_KEY');
    if (envKey.isNotEmpty && envKey.length >= encryptionKeyLength) {
      return envKey.substring(0, encryptionKeyLength);
    }
    return defaultKey;
  }
}
