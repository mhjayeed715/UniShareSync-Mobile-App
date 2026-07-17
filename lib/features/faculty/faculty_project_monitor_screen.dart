import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class FacultyProjectMonitorScreen extends ConsumerStatefulWidget {
  const FacultyProjectMonitorScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<FacultyProjectMonitorScreen> createState() => _FacultyProjectMonitorScreenState();
}

class _FacultyProjectMonitorScreenState extends ConsumerState<FacultyProjectMonitorScreen> {
  final TextEditingController _feedbackController = TextEditingController();
  String _reviewStatus = 'reviewed';
  List<FlSpot> _progressSpots = [];
  bool _isLoadingChart = true;

  @override
  void initState() {
    super.initState();
    _loadProgressHistory();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadProgressHistory() async {
    try {
      final response = await Supabase.instance.client
          .from('project_progress_snapshots')
          .select('progress_pct, recorded_at')
          .eq('project_id', widget.projectId)
          .order('recorded_at', ascending: true);

      final List<FlSpot> spots = [];
      int idx = 0;
      for (final row in response as List) {
        final pct = (row['progress_pct'] as num? ?? 0.0).toDouble();
        spots.add(FlSpot(idx.toDouble(), pct));
        idx++;
      }
      
      // Fallback if no history yet
      if (spots.isEmpty) {
        spots.add(const FlSpot(0, 0));
      }

      setState(() {
        _progressSpots = spots;
        _isLoadingChart = false;
      });
    } catch (_) {
      setState(() => _isLoadingChart = false);
    }
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;

    try {
      await ref.read(projectsServiceProvider).updateSupervisorFeedback(
            projectId: widget.projectId,
            feedback: text,
            reviewStatus: _reviewStatus,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supervisor feedback updated successfully.')),
      );
      ref.refresh(singleProjectProvider(widget.projectId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post feedback: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(singleProjectProvider(widget.projectId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Supervisor Panel', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(child: Text('Project not found.', style: TextStyle(color: Color(0xFF0F172A))));
          }

          // Check if current user is an assigned supervisor
          final isSupervisor = project.supervisors.any((s) => s.facultyId == currentUserId && s.status == SupervisorInviteStatus.accepted);
          
          ProjectSupervisorModel? mySupervisorRecord;
          try {
            mySupervisorRecord = project.supervisors.firstWhere((s) => s.facultyId == currentUserId && s.status == SupervisorInviteStatus.accepted);
          } catch (_) {}

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project stats card
                _buildStatsSummaryCard(project),
                const SizedBox(height: 24),

                // Progress timeline graph
                const Text(
                  'Progress Timeline',
                  style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _isLoadingChart ? const Center(child: CircularProgressIndicator()) : _buildProgressLineChart(),

                const SizedBox(height: 24),

                // Supervisor review deck (only if user is formally assigned supervisor)
                if (isSupervisor) ...[
                  const Text(
                    'Supervisor Review Actions',
                    style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildFeedbackForm(),
                  const SizedBox(height: 16),
                  
                  // Request update button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.notifications_active_outlined, color: Colors.white),
                      label: const Text('Request Progress Update', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        try {
                          await ref.read(projectsServiceProvider).requestProgressUpdate(project.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Progress update request sent to team members.')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to request update: $e')),
                          );
                        }
                      },
                    ),
                  ),

                  if (mySupervisorRecord?.feedbackNote != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Your Posted Feedback History',
                      style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        mySupervisorRecord!.feedbackNote!,
                        style: const TextStyle(color: Color(0xFF475569), fontSize: 13.5, height: 1.45),
                      ),
                    ),
                  ],
                ] else
                  const Text(
                    'You are viewing this project as a Course Monitor. Assign yourself or accept supervisor invite for grading actions.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
      ),
    );
  }

  Widget _buildStatsSummaryCard(ProjectModel project) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.title,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Course: ${project.courseCode ?? "Personal Side Project"}',
            style: const TextStyle(color: Color(0xFF64748B)),
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Progress', '${project.progressPct}%'),
              _buildStatColumn('Members', '${project.currentMembers}/${project.maxMembers}'),
              _buildStatColumn('Risk State', project.isAtRisk ? 'HIGH' : 'NORMAL'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: (label == 'Risk State' && value == 'HIGH') ? Colors.redAccent : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLineChart() {
    return Container(
      height: 220,
      padding: const EdgeInsets.only(right: 24, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return const Text('', style: TextStyle(fontSize: 10, color: Color(0xFF64748B)));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: _progressSpots.length.toDouble() - 1,
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: _progressSpots,
              isCurved: true,
              color: const Color(0xFF2563EB),
              barWidth: 4,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF2563EB).withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _feedbackController,
            style: const TextStyle(color: Color(0xFF0F172A)),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter feedback note for the team...',
              hintStyle: TextStyle(color: Color(0xFF94A3B8)),
              border: InputBorder.none,
            ),
          ),
          const Divider(color: Color(0xFFE2E8F0)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Status: ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  DropdownButton<String>(
                    value: _reviewStatus,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'reviewed', child: Text('Reviewed')),
                      DropdownMenuItem(value: 'needs_revision', child: Text('Needs Revision')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _reviewStatus = val);
                      }
                    },
                  )
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () {
                  _submitFeedback();
                  _feedbackController.clear();
                },
                child: const Text('Post Feedback', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          )
        ],
      ),
    );
  }
}
