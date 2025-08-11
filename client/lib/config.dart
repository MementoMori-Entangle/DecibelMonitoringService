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
  // AndroidのDownloadディレクトリ
  static const String downloadPath = 'Download';
  static const Map<String, String> downloadPathMap = {
    'Download': '/storage/emulated/0/Download',
  };
}
