import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/club_model.dart';
import 'package:unisharesync_mobile_app/services/clubs_service.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/create_club_dialog.dart';
import 'package:unisharesync_mobile_app/features/events_clubs/club_members_screen.dart';

class ClubManagementScreen extends StatefulWidget {
  const ClubManagementScreen({super.key});

  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> {
  final ClubsService _clubsService = ClubsService();
  List<ClubModel> _myClubs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMyClubs();
  }

  Future<void> _loadMyClubs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allClubs = await _clubsService.fetchClubs();
      final userId = _clubsService.currentUserId;
      
      final myClubs = allClubs.where((club) => club.ownerId == userId).toList();

      if (!mounted) return;
      setState(() {
        _myClubs = myClubs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  void _showJoinRequests(ClubModel club) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubJoinRequestsScreen(club: club),
      ),
    ).then((_) => _loadMyClubs());
  }

  Future<void> _createClub() async {
    final draft = await showDialog<ClubDraft>(
      context: context,
      builder: (_) => const CreateClubDialog(),
    );

    if (draft == null) return;

    try {
      await _clubsService.createClub(
        name: draft.name,
        description: draft.description,
        category: draft.category,
      );
      if (!mounted) return;
      await _loadMyClubs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club created successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create club: $error')),
      );
    }
  }

  Future<void> _editClub(ClubModel club) async {
    final draft = await showDialog<ClubDraft>(
      context: context,
      builder: (_) => CreateClubDialog(existingClub: club),
    );

    if (draft == null) return;

    try {
      await _clubsService.updateClub(
        clubId: club.id,
        name: draft.name,
        description: draft.description,
        category: draft.category,
      );
      if (!mounted) return;
      await _loadMyClubs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club updated successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update club: $error')),
      );
    }
  }

  Future<void> _deleteClub(ClubModel club) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Club'),
        content: Text('Are you sure you want to delete "${club.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _clubsService.deleteClub(club.id);
      if (!mounted) return;
      await _loadMyClubs();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Club deleted successfully')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete club: $error')),
      );
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
        title: const Text(
          'My Clubs',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FBFF),
                    Color(0xFFEAF6FF),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : _myClubs.isEmpty
                        ? const Center(child: Text('No clubs found'))
                        : RefreshIndicator(
                            onRefresh: _loadMyClubs,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _myClubs.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final club = _myClubs[index];
                                return _ClubManagementCard(
                                  club: club,
                                  onManageTap: () => _showJoinRequests(club),
                                  onEdit: () => _editClub(club),
                                  onDelete: () => _deleteClub(club),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createClub,
        backgroundColor: const Color(0xFFFF6B9D),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _ClubManagementCard extends StatelessWidget {
  const _ClubManagementCard({
    required this.club,
    required this.onManageTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ClubModel club;
  final VoidCallback onManageTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onManageTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B9D).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          club.name.isNotEmpty ? club.name[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: Color(0xFFFF6B9D),
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            club.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${club.memberCount} members',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'members') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClubMembersScreen(club: club),
                            ),
                          );
                        } else if (value == 'requests') {
                          onManageTap();
                        } else if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'members',
                          child: Row(
                            children: [
                              Icon(Icons.people, size: 18),
                              SizedBox(width: 8),
                              Text('Members'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'requests',
                          child: Row(
                            children: [
                              Icon(Icons.people_outline, size: 18),
                              SizedBox(width: 8),
                              Text('Join Requests'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_rounded, size: 18, color: Color(0xFFEF4444)),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ClubJoinRequestsScreen extends StatefulWidget {
  const ClubJoinRequestsScreen({super.key, required this.club});

  final ClubModel club;

  @override
  State<ClubJoinRequestsScreen> createState() => _ClubJoinRequestsScreenState();
}

class _ClubJoinRequestsScreenState extends State<ClubJoinRequestsScreen> {
  final ClubsService _clubsService = ClubsService();
  List<ClubJoinRequest> _requests = [];
  bool _isLoading = true;
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
      final requests = await _clubsService.fetchJoinRequests(widget.club.id);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _reviewRequest(ClubJoinRequest request, bool approve) async {
    try {
      await _clubsService.reviewJoinRequest(
        requestId: request.id,
        approve: approve,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Request approved' : 'Request rejected'),
        ),
      );
      _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = _requests.where((r) => r.isPending).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.club.name,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FBFF),
                    Color(0xFFEAF6FF),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : pendingRequests.isEmpty
                        ? const Center(child: Text('No pending requests'))
                        : RefreshIndicator(
                            onRefresh: _loadRequests,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: pendingRequests.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final request = pendingRequests[index];
                                return _JoinRequestCard(
                                  request: request,
                                  onApprove: () => _reviewRequest(request, true),
                                  onReject: () => _reviewRequest(request, false),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _JoinRequestCard extends StatelessWidget {
  const _JoinRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final ClubJoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFFF6B9D).withOpacity(0.15),
                backgroundImage: request.requesterAvatar != null
                    ? NetworkImage(request.requesterAvatar!)
                    : null,
                child: request.requesterAvatar == null
                    ? Text(
                        request.requesterName.isNotEmpty
                            ? request.requesterName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          color: Color(0xFFFF6B9D),
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.requesterName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(request.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onApprove,
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.35),
                      ),
                    ),
                    child: const Text(
                      'Approve',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onReject,
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.35),
                      ),
                    ),
                    child: const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
