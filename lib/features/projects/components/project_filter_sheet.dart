import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class ProjectFilterSheet extends ConsumerWidget {
  const ProjectFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(projectHubFiltersProvider);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      child: const Text('Reset All', style: TextStyle(color: Color(0xFF06B6D4))),
                      onPressed: () {
                        ref.read(projectHubFiltersProvider.notifier).state =
                            const ProjectHubFilters();
                      },
                    ),
                  ],
                ),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                // Semester Selector Grid
                const Text(
                  'Semester (1 - 12)',
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(12, (index) {
                    final sem = index + 1;
                    final isSelected = filters.semesterNo == sem;
                    return ChoiceChip(
                      label: Text('Sem $sem'),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569)),
                      onSelected: (selected) {
                        ref.read(projectHubFiltersProvider.notifier).state =
                            filters.copyWith(
                              semesterNo: selected ? sem : null,
                              clearSemester: !selected,
                            );
                      },
                    );
                  }),
                ),

                const SizedBox(height: 18),

                // Project Type Selector
                const Text(
                  'Project Type',
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ProjectType.values.map((type) {
                    final isSelected = filters.projectType == type;
                    return ChoiceChip(
                      label: Text(type.displayName),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569)),
                      onSelected: (selected) {
                        ref.read(projectHubFiltersProvider.notifier).state =
                            filters.copyWith(projectType: selected ? type : null);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Project Category
                const Text(
                  'Category',
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ProjectCategory.values.map((cat) {
                    final isSelected = filters.category == cat;
                    return ChoiceChip(
                      label: Text(cat.displayName),
                      selected: isSelected,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF475569)),
                      onSelected: (selected) {
                        ref.read(projectHubFiltersProvider.notifier).state =
                            filters.copyWith(category: selected ? cat : null);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                // Apply Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontSize: 16)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
