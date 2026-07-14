import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/community_model.dart';
import '../../data/models/community_member_model.dart';
import '../../data/models/community_join_request_model.dart';
import '../providers/community_detail_provider.dart';
import '../providers/community_notice_provider.dart';
import '../providers/community_activity_provider.dart';
import 'community_analytics_screen.dart';
import 'community_create_edit_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommunityDetailScreen extends ConsumerStatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  ConsumerState<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends ConsumerState<CommunityDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserRole? _userRole;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _loadUserInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(communityDetailProvider.notifier).fetchCommunityDetail(widget.communityId);
      ref.read(communityNoticeProvider.notifier).fetchNotices(widget.communityId);
      ref.read(communityActivityProvider.notifier).fetchActivityPosts(widget.communityId);
    });
  }

  void _loadUserInfo() async {
    final role = await AuthService().getCurrentRole();
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (mounted) {
      setState(() {
        _userRole = role;
        _currentUserId = uid;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCreateNoticeDialog(String communityId) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String noticeType = 'announcement';
    String priority = 'normal';
    bool isPinned = false;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Post Community Notice',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: noticeType,
                  decoration: const InputDecoration(
                    labelText: 'Notice Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['announcement', 'meeting', 'reminder', 'achievement', 'urgent'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => noticeType = val);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ['normal', 'high', 'urgent'].map((prio) {
                    return DropdownMenuItem(
                      value: prio,
                      child: Text(prio.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => priority = val);
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Pin this Notice'),
                  value: isPinned,
                  onChanged: (val) {
                    if (val != null) setModalState(() => isPinned = val);
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F9EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields')),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            await ref.read(communityNoticeProvider.notifier).createNotice({
                              'community_id': communityId,
                              'title': titleController.text.trim(),
                              'body': bodyController.text.trim(),
                              'notice_type': noticeType,
                              'priority': priority,
                              'is_pinned': isPinned,
                            });
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Notice posted successfully!')),
                              );
                              ref.read(communityNoticeProvider.notifier).fetchNotices(communityId);
                            }
                          } catch (e) {
                            if (mounted) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to post notice: $e')),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Notice', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateActivityDialog(String communityId) {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String postType = 'general_update';
    bool isSubmitting = false;
    final List<Uint8List> pickedBytesList = [];
    final List<String> pickedNamesList = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Post Community Activity/Update',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Activity Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Details',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: postType,
                  decoration: const InputDecoration(
                    labelText: 'Activity Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ['achievement', 'meeting_minutes', 'project_update', 'photo_gallery', 'member_spotlight', 'general_update'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.replaceAll('_', ' ').toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => postType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      setModalState(() {
                        pickedBytesList.add(bytes);
                        pickedNamesList.add(picked.name);
                      });
                    }
                  },
                  icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF4F9EFF)),
                  label: const Text('Attach Photo', style: TextStyle(color: Color(0xFF4F9EFF), fontWeight: FontWeight.bold)),
                ),
                if (pickedNamesList.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: pickedNamesList.length,
                      itemBuilder: (context, idx) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  pickedBytesList[idx],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      pickedBytesList.removeAt(idx);
                                      pickedNamesList.removeAt(idx);
                                    });
                                  },
                                  child: const CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.black54,
                                    child: Icon(Icons.close_rounded, size: 12, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F9EFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty || bodyController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all fields')),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          try {
                            await ref.read(communityActivityProvider.notifier).createActivityPost({
                              'community_id': communityId,
                              'title': titleController.text.trim(),
                              'body': bodyController.text.trim(),
                              'post_type': postType,
                            },
                            photoBytesList: pickedBytesList,
                            photoNamesList: pickedNamesList);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Activity update posted successfully!')),
                              );
                              ref.read(communityActivityProvider.notifier).fetchActivityPosts(communityId);
                            }
                          } catch (e) {
                            if (mounted) {
                              setModalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to post activity: $e')),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Publish Update', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateMemberRole(String memberId, String newRole) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updating member role...')));
      await ref.read(communityDetailProvider.notifier).updateMemberRole(memberId, newRole);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role updated to ${newRole.toUpperCase()}!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update role: $e')));
    }
  }

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove $memberName from the community?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removing member...')));
        await ref.read(communityDetailProvider.notifier).removeMember(memberId);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(communityDetailProvider);

    return detailState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (community) {
        final isCreator = community.createdBy == _currentUserId;
        final isAdmin = _userRole == UserRole.admin;
        final canManage = isCreator || isAdmin;
        final hasControlRole = community.userMemberRole == 'president' || 
                               community.userMemberRole == 'vice_president' || 
                               community.userMemberRole == 'secretary' || 
                               community.userMemberRole == 'faculty_head';
        final canControl = isCreator || isAdmin || hasControlRole;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        community.coverPhotoUrl ?? 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: Colors.blueGrey),
                      ),
                      Container(color: Colors.black.withOpacity(0.4)),
                      if (canManage)
                        Positioned(
                          right: 16,
                          top: 56,
                          child: CircleAvatar(
                            backgroundColor: Colors.white.withOpacity(0.85),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFF4F9EFF)),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                if (file != null) {
                                  final bytes = await file.readAsBytes();
                                  try {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading cover photo...')));
                                    await ref.read(communityDetailProvider.notifier).updateCoverPhoto(community.id, bytes, file.name);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover photo updated!')));
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update cover photo: $e')));
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      Positioned(
                        left: 16,
                        bottom: 16,
                        child: Row(
                          children: [
                             Stack(
                               children: [
                                 CircleAvatar(
                                   radius: 36,
                                   backgroundImage: NetworkImage(community.logoUrl ?? 'https://images.unsplash.com/photo-1579621970795-87faff3f905d?w=200'),
                                 ),
                                 if (canManage)
                                   Positioned.fill(
                                     child: Material(
                                       color: Colors.transparent,
                                       child: InkWell(
                                         borderRadius: BorderRadius.circular(36),
                                         onTap: () async {
                                           final picker = ImagePicker();
                                           final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                                           if (file != null) {
                                             final bytes = await file.readAsBytes();
                                             try {
                                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading community logo...')));
                                               await ref.read(communityDetailProvider.notifier).updateLogo(community.id, bytes, file.name);
                                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo updated!')));
                                             } catch (e) {
                                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update logo: $e')));
                                             }
                                           }
                                         },
                                         child: Container(
                                           decoration: BoxDecoration(
                                             color: Colors.black.withOpacity(0.3),
                                             shape: BoxShape.circle,
                                           ),
                                           child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                                         ),
                                       ),
                                     ),
                                   ),
                               ],
                             ),
                             const SizedBox(width: 12),
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Text(
                                   community.name,
                                   style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                 ),
                                 Text(
                                   community.tagline,
                                   style: const TextStyle(color: Colors.white70, fontSize: 13),
                                 ),
                               ],
                             )
                           ],
                         ),
                       )
                     ],
                   ),
                 ),
                 actions: [
                   if (canManage) ...[
                     IconButton(
                       icon: const Icon(Icons.edit_rounded, color: Colors.white),
                       onPressed: () {
                         Navigator.push(context, MaterialPageRoute(
                           builder: (_) => CommunityCreateEditScreen(existingCommunity: community),
                         ));
                       },
                     ),
                     IconButton(
                       icon: const Icon(Icons.analytics_rounded, color: Colors.white),
                       onPressed: () {
                         Navigator.push(context, MaterialPageRoute(
                           builder: (_) => CommunityAnalyticsScreen(communityId: community.id),
                         ));
                       },
                     ),
                   ]
                 ],
               ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabHeaderDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: const Color(0xFF0F172A),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: const Color(0xFF4F9EFF),
                    tabs: const [
                      Tab(text: 'About'),
                      Tab(text: 'Notices'),
                      Tab(text: 'Activity'),
                      Tab(text: 'Members'),
                      Tab(text: 'Events'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildAboutTab(community),
                _buildNoticesTab(),
                _buildActivityTab(),
                _buildMembersTab(),
                _buildEventsTab(),
              ],
            ),
          ),
          floatingActionButton: (canControl && (_tabController.index == 1 || _tabController.index == 2))
              ? FloatingActionButton(
                  onPressed: () {
                    if (_tabController.index == 1) {
                      _showCreateNoticeDialog(community.id);
                    } else if (_tabController.index == 2) {
                      _showCreateActivityDialog(community.id);
                    }
                  },
                  backgroundColor: const Color(0xFF4F9EFF),
                  child: Icon(
                    _tabController.index == 1
                        ? Icons.add_comment_rounded
                        : Icons.add_a_photo_rounded,
                    color: Colors.white,
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildAboutTab(CommunityModel community) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About the Community', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(community.description, style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Members: ${community.memberCount}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Activity Score: ${community.activityScore}/100', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            ],
          ),
          const SizedBox(height: 24),
          if (community.isUserMember) ...[
            if (community.createdBy != _currentUserId && community.userMemberRole != 'faculty_head') ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Leave Community', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('Are you sure you want to leave this community?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Leave', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      try {
                        await ref.read(communityDetailProvider.notifier).leaveCommunity(community.id);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have left the community.')));
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  child: const Text('Leave Community', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ] else if (community.hasRequestPending) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor: Colors.amber.shade100,
                  disabledForegroundColor: Colors.amber.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Request Pending Approval', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F9EFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  String? message;
                  if (community.joinType == 'request') {
                    message = await showDialog<String>(
                      context: context,
                      builder: (context) {
                        final controller = TextEditingController();
                        return AlertDialog(
                          title: const Text('Join Request Message', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: TextField(
                            controller: controller,
                            decoration: const InputDecoration(
                              hintText: 'Introduce yourself (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, controller.text.trim()),
                              child: const Text('Send'),
                            ),
                          ],
                        );
                      },
                    );
                    if (message == null) return;
                  }

                  try {
                    await ref.read(communityDetailProvider.notifier).joinCommunity(community.id, joinMessage: message);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          community.joinType == 'request'
                              ? 'Request to join sent!'
                              : 'Successfully joined community!',
                        ),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to join: $e')));
                  }
                },
                child: const Text('Join Community', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildNoticesTab() {
    final noticesState = ref.watch(communityNoticeProvider);

    return noticesState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error notices: $e')),
      data: (notices) {
        if (notices.isEmpty) {
          return const Center(child: Text('No notices posted.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notices.length,
          itemBuilder: (context, index) {
            final notice = notices[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(notice.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(notice.body),
                trailing: notice.isPinned ? const Icon(Icons.push_pin, color: Colors.blue) : null,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActivityTab() {
    final activityState = ref.watch(communityActivityProvider);

    return activityState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error activities: $e')),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(child: Text('No updates posted yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(post.body, style: const TextStyle(color: Colors.grey)),
                    if (post.photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: post.photos.length,
                          itemBuilder: (context, photoIdx) {
                            final photo = post.photos[photoIdx];
                            return GestureDetector(
                              onTap: () {
                                _showFullScreenImage(context, photo.photoUrl);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    photo.photoUrl,
                                    width: 160,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 160,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMembersTab() {
    final detailState = ref.read(communityDetailProvider);
    final community = detailState.value;
    if (community == null) return const SizedBox.shrink();

    final isCreator = community.createdBy == _currentUserId;
    final isAdmin = _userRole == UserRole.admin;
    final canManage = isCreator || isAdmin;

    return FutureBuilder(
      future: Future.wait([
        ref.read(communityDetailProvider.notifier).fetchCommunityMembers(widget.communityId),
        canManage
            ? ref.read(communityDetailProvider.notifier).fetchJoinRequests(widget.communityId)
            : Future.value(<CommunityJoinRequestModel>[]),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final List<CommunityMemberModel> members = snapshot.data![0];
        final List<CommunityJoinRequestModel> requests = snapshot.data![1];

        final totalItems = (requests.isNotEmpty ? requests.length + 1 : 0) + (members.isNotEmpty ? members.length + 1 : 0);

        if (totalItems == 0) {
          return const Center(child: Text('No members or requests found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: totalItems,
          itemBuilder: (context, idx) {
            int requestSectionCount = requests.isNotEmpty ? requests.length + 1 : 0;

            if (requests.isNotEmpty && idx < requestSectionCount) {
              if (idx == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Pending Join Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                );
              }
              final req = requests[idx - 1];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: req.requesterAvatar != null ? NetworkImage(req.requesterAvatar!) : null,
                    child: req.requesterAvatar == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(req.requesterName),
                  subtitle: req.message != null && req.message!.isNotEmpty ? Text('Message: ${req.message}') : const Text('No message'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                        onPressed: () async {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approving request...')));
                            await ref.read(communityDetailProvider.notifier).reviewJoinRequest(req.id, 'approved', req.requesterId, widget.communityId);
                            setState(() {}); // refresh FutureBuilder
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request approved!')));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                        onPressed: () async {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejecting request...')));
                            await ref.read(communityDetailProvider.notifier).reviewJoinRequest(req.id, 'rejected', req.requesterId, widget.communityId);
                            setState(() {}); // refresh FutureBuilder
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected!')));
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            }

            int memberIdx = requests.isNotEmpty ? idx - requestSectionCount : idx;
            if (members.isNotEmpty) {
              if (memberIdx == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('All Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                );
              }
              final member = members[memberIdx - 1];
              final isCreatorMember = member.userId == community.createdBy;
              final isMe = member.userId == _currentUserId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: member.avatarUrl != null ? NetworkImage(member.avatarUrl!) : null,
                  child: member.avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(member.fullName),
                subtitle: Text('Role: ${member.role.replaceAll('_', ' ').toUpperCase()}'),
                trailing: (canManage && !isCreatorMember && !isMe)
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded),
                        onSelected: (value) {
                          if (value == 'remove') {
                            _removeMember(member.id, member.fullName);
                          } else {
                            _updateMemberRole(member.id, value);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'president', child: Text('Promote to President')),
                          const PopupMenuItem(value: 'vice_president', child: Text('Promote to Vice President')),
                          const PopupMenuItem(value: 'secretary', child: Text('Promote to Secretary')),
                          const PopupMenuItem(value: 'member', child: Text('Demote to Member')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove Member', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      )
                    : null,
              );
            }

            return const SizedBox.shrink();
          },
        );
      },
    );
  }

  Widget _buildEventsTab() {
    return const Center(child: Text('Past & Upcoming Community Events'));
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black87,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Could not load image', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabHeaderDelegate oldDelegate) {
    return false;
  }
}
