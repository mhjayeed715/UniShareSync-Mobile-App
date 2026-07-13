import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class SupervisorAssignmentScreen extends ConsumerStatefulWidget {
  const SupervisorAssignmentScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<SupervisorAssignmentScreen> createState() => _SupervisorAssignmentScreenState();
}

class _SupervisorAssignmentScreenState extends ConsumerState<SupervisorAssignmentScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _facultyList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _searchFaculty();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchFaculty([String query = '']) async {
    setState(() => _isLoading = true);
    try {
      var req = Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'faculty');

      if (query.isNotEmpty) {
        req = req.ilike('full_name', '%$query%');
      }

      final response = await req.order('full_name');
      setState(() {
        _facultyList = (response as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _invite(String facultyId, String facultyName) async {
    try {
      await ref.read(projectsServiceProvider).inviteSupervisor(widget.projectId, facultyId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invitation sent successfully to $facultyName')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send invitation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(singleProjectProvider(widget.projectId));
    final supervisors = projectAsync.valueOrNull?.supervisors ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Invite Supervisor', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          // Light gradient background
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.88),
                        border: Border.all(color: Colors.white.withOpacity(0.95)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Color(0xFF0F172A)),
                        onChanged: (val) => _searchFaculty(val.trim()),
                        decoration: const InputDecoration(
                          hintText: 'Search faculty by name...',
                          hintStyle: TextStyle(color: Color(0xFF64748B)),
                          prefixIcon: Icon(Icons.search, color: Color(0xFF64748B)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Faculty grid list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _facultyList.isEmpty
                        ? const Center(child: Text('No faculty found.', style: TextStyle(color: Color(0xFF64748B))))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _facultyList.length,
                            itemBuilder: (context, index) {
                              final f = _facultyList[index];
                              final name = f['full_name'] as String? ?? 'Faculty';
                              final id = f['id'] as String;
                              final dept = f['department'] as String? ?? 'Department';
                              final designation = f['designation'] as String? ?? 'Professor';

                              // Find if this faculty is already a supervisor
                              final svRecord = supervisors.any((s) => s.facultyId == id)
                                  ? supervisors.firstWhere((s) => s.facultyId == id)
                                  : null;

                              Widget trailingWidget;
                              if (svRecord != null) {
                                if (svRecord.status == SupervisorInviteStatus.pending) {
                                  trailingWidget = ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade700,
                                      disabledBackgroundColor: Colors.amber.shade700.withOpacity(0.5),
                                    ),
                                    onPressed: null, // Disabled
                                    child: const Text('Pending', style: TextStyle(color: Colors.white)),
                                  );
                                } else if (svRecord.status == SupervisorInviteStatus.accepted) {
                                  trailingWidget = ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      disabledBackgroundColor: Colors.green.shade700.withOpacity(0.5),
                                    ),
                                    onPressed: null, // Disabled
                                    child: const Text('Joined', style: TextStyle(color: Colors.white)),
                                  );
                                } else {
                                  // declined or resigned, we can allow re-invitation
                                  trailingWidget = ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
                                    onPressed: () => _invite(id, name),
                                    child: const Text('Invite', style: TextStyle(color: Colors.white)),
                                  );
                                }
                              } else {
                                trailingWidget = ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
                                  onPressed: () => _invite(id, name),
                                  child: const Text('Invite', style: TextStyle(color: Colors.white)),
                                );
                              }

                              return ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.88),
                                    border: Border.all(color: Colors.white.withOpacity(0.95)),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF2563EB),
                                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                                    ),
                                    title: Text(name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                                    subtitle: Text('$designation, $dept', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                                    trailing: trailingWidget,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
