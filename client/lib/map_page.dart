import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';
import 'generated/decibel_logger.pb.dart';
import 'settings_service.dart';

class MapPage extends StatefulWidget {
  final List<DecibelData> decibelList;
  const MapPage({super.key, required this.decibelList});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  double _pinClusterRadius = AppConfig.defaultPinClusterRadiusMeter;
  List<_ClusteredData> _clusters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClusterRadiusAndCluster();
  }

  Future<void> _loadClusterRadiusAndCluster() async {
    final s = SettingsService();
    final radius = await s.getPinClusterRadiusMeter();
    setState(() {
      _pinClusterRadius =
          radius < AppConfig.minPinClusterRadiusMeter
              ? AppConfig.minPinClusterRadiusMeter
              : radius;
    });
    _clusterData();
  }

  void _clusterData() {
    final data =
        widget.decibelList
            .where((d) => d.latitude != 0.0 || d.longitude != 0.0)
            .toList();
    final clusters = <_ClusteredData>[];
    final used = List<bool>.filled(data.length, false);
    final dist = Distance();
    for (int i = 0; i < data.length; i++) {
      if (used[i]) continue;
      final group = <DecibelData>[data[i]];
      used[i] = true;
      for (int j = i + 1; j < data.length; j++) {
        if (used[j]) continue;
        final d1 = data[i];
        final d2 = data[j];
        final m = dist(
          LatLng(d1.latitude, d1.longitude),
          LatLng(d2.latitude, d2.longitude),
        );
        if (m <= _pinClusterRadius) {
          group.add(d2);
          used[j] = true;
        }
      }
      // 平均座標
      final avgLat =
          group.map((d) => d.latitude).reduce((a, b) => a + b) / group.length;
      final avgLng =
          group.map((d) => d.longitude).reduce((a, b) => a + b) / group.length;
      clusters.add(_ClusteredData(lat: avgLat, lng: avgLng, data: group));
    }
    setState(() {
      _clusters = clusters;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('GPSマップ表示')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final markers = <Marker>[];
    for (final cluster in _clusters) {
      markers.add(
        Marker(
          point: LatLng(cluster.lat, cluster.lng),
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('データ一覧'),
                      content: SizedBox(
                        width: 250,
                        child: ListView(
                          shrinkWrap: true,
                          children:
                              cluster.data
                                  .map(
                                    (d) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        '${d.datetime}\n${d.decibel.toStringAsFixed(2)} dB'
                                        '${d.altitude != 0.0 || d.pressure != 0.0 || d.temperature != 0.0 ? '\n${d.altitude}m, ${d.pressure}hPa, ${d.temperature}°C' : ''}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('閉じる'),
                        ),
                      ],
                    ),
              );
            },
            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
          ),
        ),
      );
    }
    final center =
        markers.isNotEmpty ? markers.first.point : LatLng(35.0, 135.0);
    return Scaffold(
      appBar: AppBar(title: const Text('GPSマップ表示')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: markers.isNotEmpty ? 15 : 5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.entangle.client',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              color: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusteredData {
  final double lat;
  final double lng;
  final List<DecibelData> data;
  _ClusteredData({required this.lat, required this.lng, required this.data});
}
