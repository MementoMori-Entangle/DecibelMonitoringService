import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'generated/decibel_logger.pbgrpc.dart';

class ChartPage extends StatelessWidget {
  final List<DecibelData> decibelList;

  const ChartPage({super.key, required this.decibelList});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('デシベルグラフ')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            decibelList.isEmpty
                ? const Center(child: Text('表示するデータがありません。'))
                : LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots:
                            decibelList
                                .asMap()
                                .entries
                                .map(
                                  (e) =>
                                      FlSpot(e.key.toDouble(), e.value.decibel),
                                )
                                .toList(),
                        isCurved: true,
                        color: Colors.blue,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    gridData: FlGridData(show: true),
                  ),
                ),
      ),
    );
  }
}
