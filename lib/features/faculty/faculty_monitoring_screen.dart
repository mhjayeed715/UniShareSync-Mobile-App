import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/features/faculty/faculty_project_monitor_screen.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class FacultyMonitoringScreen extends ConsumerStatefulWidget {
  const FacultyMonitoringScreen({super.key});

  @override
  ConsumerState<FacultyMonitoringScreen> createState() => _FacultyMonitoringScreenState();
}

class _FacultyMonitoringScreenState extends ConsumerState<FacultyMonitoringScreen> {
  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(facultyMonitoredProjectsProvider);

    return projectsAsync.when(
      data: (projects) {
        if (projects.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'You are not currently teaching any courses with active projects, or no projects have been created for your courses.',
                style: TextStyle(color: Colors.white60, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return _buildMonitoredCard(project);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading projects: $err', style: const TextStyle(color: Colors.redAccent))),
    );
  }

  Widget _buildMonitoredCard(ProjectModel project) {
    final hasRisk = project.isAtRisk;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasRisk ? Colors.redAccent.withOpacity(0.8) : Colors.white.withOpacity(0.05),
              width: hasRisk ? 1.5 : 1.0,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  project.projectCode,
                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        project.courseCode ?? 'Course Project',
                        style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Semester ${project.semesterNo}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Progress: ${project.progressPct}%', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    SizedBox(
                      width: 80,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: project.progressPct / 100,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            hasRisk ? Colors.redAccent : const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FacultyProjectMonitorScreen(projectId: project.id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
