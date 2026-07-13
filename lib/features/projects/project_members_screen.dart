import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class ProjectMembersScreen extends ConsumerStatefulWidget {
  const ProjectMembersScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectMembersScreen> createState() => _ProjectMembersScreenState();
}

class _ProjectMembersScreenState extends ConsumerState<ProjectMembersScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _members = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(projectsServiceProvider);
      final list = await service.fetchProjectMembersWithProfiles(widget.projectId);
      if (mounted) {
        setState(() {
          _members = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '$e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removeMember(String userId, String memberName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove $memberName from the project?'),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final service = ref.read(projectsServiceProvider);
        await service.removeMember(widget.projectId, userId);

        ref.invalidate(singleProjectProvider(widget.projectId));
        ref.invalidate(discoverProjectsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Removed $memberName from the project.')),
          );
          _loadMembers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove member: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Manage Members',
          style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.redAccent)))
                  : _members.isEmpty
                      ? const Center(
                          child: Text(
                            'No members found.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final m = _members[index];
                            final role = m['role']?.toString() ?? 'member';
                            final profile = m['profiles'] as Map<String, dynamic>?;
                            final name = profile?['full_name']?.toString() ?? 'Student';
                            final email = profile?['email']?.toString() ?? '';
                            final userId = m['user_id']?.toString() ?? '';
                            final isOwner = role == 'owner';

                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.88),
                                    border: Border.all(color: Colors.white.withOpacity(0.95)),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: CircleAvatar(
                                      backgroundColor: isOwner ? const Color(0xFF06B6D4) : const Color(0xFF2563EB),
                                      child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                        ),
                                        if (isOwner) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF06B6D4).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'OWNER',
                                              style: TextStyle(color: Color(0xFF0284C7), fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Text(
                                      email,
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    ),
                                    trailing: isOwner
                                        ? null
                                        : IconButton(
                                            icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent),
                                            tooltip: 'Remove from Project',
                                            onPressed: () => _removeMember(userId, name),
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ],
      ),
    );
  }
}
