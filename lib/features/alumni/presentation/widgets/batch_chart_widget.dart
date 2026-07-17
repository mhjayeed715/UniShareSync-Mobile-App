import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class BatchChartWidget extends StatelessWidget {
  final Map<int, int> data;

  const BatchChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No batch data available',
            style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
          ),
        ),
      );
    }

    // Sort batch years ascending
    final sortedBatches = data.keys.toList()..sort();
    final maxCount = data.values.fold<int>(0, (prev, val) => val > prev ? val : prev);

    // Dynamic width based on the number of batches to support horizontal scroll
    final double chartWidth = (sortedBatches.length * 50.0).clamp(MediaQuery.of(context).size.width - 32, 1000.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxCount + 2).toDouble(),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => const Color(0xFF0F172A),
                tooltipPadding: const EdgeInsets.all(6),
                tooltipMargin: 8,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${rod.toY.toInt()} Alumni',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (double value, TitleMeta meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < sortedBatches.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${sortedBatches[index]}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (maxCount / 4).clamp(1.0, 100.0),
                  getTitlesWidget: (double value, TitleMeta meta) {
                    return Text(
                      value.toInt().toString(),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 9,
                        fontFamily: 'Outfit',
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) {
                return const FlLine(
                  color: Color(0xFFE2E8F0),
                  strokeWidth: 1,
                );
              },
            ),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(sortedBatches.length, (index) {
              final batch = sortedBatches[index];
              final count = data[batch] ?? 0;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: count.toDouble(),
                    color: const Color(0xFF2563EB),
                    width: 16,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: (maxCount + 2).toDouble(),
                      color: const Color(0xFFF1F5F9),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
