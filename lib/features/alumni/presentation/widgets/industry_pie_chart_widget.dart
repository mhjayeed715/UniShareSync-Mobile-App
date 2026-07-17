import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../data/models/alumni_profile_model.dart';

class IndustryPieChartWidget extends StatelessWidget {
  final Map<String, int> data;

  const IndustryPieChartWidget({super.key, required this.data});

  Color _getIndustryColor(String rawVal) {
    final ind = AlumniIndustry.fromString(rawVal);
    switch (ind) {
      case AlumniIndustry.softwareDevelopment:
        return const Color(0xFF2563EB); // Electric Blue
      case AlumniIndustry.dataScienceAi:
        return const Color(0xFF10B981); // Emerald
      case AlumniIndustry.cybersecurity:
        return const Color(0xFFEF4444); // Red
      case AlumniIndustry.hardwareEmbedded:
        return const Color(0xFFEC4899); // Pink
      case AlumniIndustry.academiaResearch:
        return const Color(0xFF8B5CF6); // Purple
      case AlumniIndustry.entrepreneurship:
        return const Color(0xFFF59E0B); // Amber
      case AlumniIndustry.governmentPublicSector:
        return const Color(0xFF06B6D4); // Cyan
      case AlumniIndustry.financeFintech:
        return const Color(0xFF14B8A6); // Teal
      case AlumniIndustry.healthcareTech:
        return const Color(0xFF34D399); // Mint
      case AlumniIndustry.other:
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No industry data available',
            style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
          ),
        ),
      );
    }

    final total = data.values.fold<int>(0, (prev, val) => prev + val);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        // Pie Chart
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sortedEntries.map((e) {
                final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';
                final isBig = (e.value / total) > 0.15;
                return PieChartSectionData(
                  color: _getIndustryColor(e.key),
                  value: e.value.toDouble(),
                  title: isBig ? '$pct%' : '',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Legend
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedEntries.length,
          itemBuilder: (context, index) {
            final entry = sortedEntries[index];
            final indName = AlumniIndustry.fromString(entry.key).displayName;
            final count = entry.value;
            final color = _getIndustryColor(entry.key);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      indName,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
