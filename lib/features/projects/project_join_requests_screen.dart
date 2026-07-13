import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unisharesync_mobile_app/data/models/project_join_request.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class ProjectJoinRequestsScreen extends ConsumerStatefulWidget {
  const ProjectJoinRequestsScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectJoinRequestsScreen> createState() => _ProjectJoinRequestsScreenState();
}

class _ProjectJoinRequestsScreenState extends ConsumerState<ProjectJoinRequestsScreen> {
  bool _isLoading = false;
  List<ProjectJoinRequest> _requests = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(projectsServiceProvider);
      final list = await service.fetchJoinRequests(widget.projectId);
      if (mounted) {
        setState(() {
          _requests = list.where((r) => r.isPending).toList();
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

  Future<void> _respond(String requestId, bool approve, String requesterName) async {
    try {
      final service = ref.read(projectsServiceProvider);
      await service.reviewJoinRequest(requestId: requestId, approve: approve);
      
      // Invalidate project providers to update members count
      ref.invalidate(singleProjectProvider(widget.projectId));
      ref.invalidate(discoverProjectsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Approved $requesterName\'s request successfully!'
                  : 'Declined $requesterName\'s request.',
            ),
          ),
        );
        _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to respond to request: $e')),
        );
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
          'Join Requests',
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
                  : _requests.isEmpty
                      ? const Center(
                          child: Text(
                            'No pending join requests.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _requests.length,
                          itemBuilder: (context, index) {
                            final req = _requests[index];
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
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF2563EB),
                                      child: Text(req.requesterName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                                    ),
                                    title: Text(
                                      req.requesterName,
                                      style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'Requested on ${_formatDateTime(req.requestedAt)}',
                                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Reject button
                                        IconButton(
                                          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                                          tooltip: 'Decline',
                                          onPressed: () => _respond(req.id, false, req.requesterName),
                                        ),
                                        const SizedBox(width: 8),
                                        // Approve button
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          onPressed: () => _respond(req.id, true, req.requesterName),
                                          child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ],
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

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
