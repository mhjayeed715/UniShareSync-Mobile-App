import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import '../../data/models/community_model.dart';
import '../providers/communities_provider.dart';
import '../providers/community_detail_provider.dart';

class CommunityCreateEditScreen extends ConsumerStatefulWidget {
  final CommunityModel? existingCommunity;

  const CommunityCreateEditScreen({super.key, this.existingCommunity});

  @override
  ConsumerState<CommunityCreateEditScreen> createState() => _CommunityCreateEditScreenState();
}

class _CommunityCreateEditScreenState extends ConsumerState<CommunityCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _taglineController;
  late TextEditingController _descriptionController;
  late TextEditingController _maxMembersController;
  late TextEditingController _tagsController;

  String _selectedType = 'programming_club';
  String _selectedJoinType = 'open';
  String _selectedVisibility = 'public';
  bool _isLoading = false;

  UserRole? _userRole;
  List<Map<String, dynamic>> _facultyOptions = [];
  String? _selectedFacultyHeadId;

  final List<String> _communityTypes = [
    'programming_club',
    'robotics_club',
    'cybersecurity_club',
    'ai_ml_club',
    'photography_club',
    'debate_club',
    'cultural_club',
    'sports_club',
    'research_group',
    'ieee_chapter',
    'acm_chapter',
    'other'
  ];

  final List<String> _joinTypes = ['open', 'request', 'invite_only'];
  final List<String> _visibilityTypes = ['public', 'private'];

  @override
  void initState() {
    super.initState();
    final comm = widget.existingCommunity;
    _nameController = TextEditingController(text: comm?.name ?? '');
    _taglineController = TextEditingController(text: comm?.tagline ?? 'Connect with our community');
    _descriptionController = TextEditingController(text: comm?.description ?? '');
    _maxMembersController = TextEditingController(text: comm?.maxMembers.toString() ?? '200');
    _tagsController = TextEditingController(text: comm?.tags.join(', ') ?? '');

    if (comm != null) {
      _selectedType = comm.type;
      _selectedJoinType = comm.joinType;
      _selectedVisibility = comm.visibility;
    }

    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await AuthService().getCurrentRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }

    if (role == UserRole.admin) {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name')
            .eq('role', 'faculty');
        if (mounted) {
          setState(() {
            _facultyOptions = List<Map<String, dynamic>>.from(res as List);
            if (widget.existingCommunity != null) {
              _loadCurrentFacultyHead();
            }
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _loadCurrentFacultyHead() async {
    try {
      final res = await Supabase.instance.client
          .from('community_members')
          .select('user_id')
          .eq('community_id', widget.existingCommunity!.id)
          .eq('role', 'faculty_head')
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _selectedFacultyHeadId = res['user_id']?.toString();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _descriptionController.dispose();
    _maxMembersController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final tagsList = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final Map<String, dynamic> data = {
      'name': _nameController.text.trim(),
      'tagline': _taglineController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': 'Other',
      'type': 'other',
      'join_type': 'open',
      'visibility': 'public',
      'max_members': int.tryParse(_maxMembersController.text) ?? 200,
      'tags': tagsList,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (_userRole == UserRole.admin && _selectedFacultyHeadId != null) {
      data['faculty_head_id'] = _selectedFacultyHeadId;
    }

    try {
      if (widget.existingCommunity != null) {
        // Update
        await ref.read(communitiesProvider.notifier).updateCommunity(widget.existingCommunity!.id, data);
        ref.invalidate(communityDetailProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community updated successfully!')));
          Navigator.pop(context);
        }
      } else {
        // Create
        data['created_by'] = Supabase.instance.client.auth.currentUser!.id;
        data['created_at'] = DateTime.now().toIso8601String();
        await ref.read(communitiesProvider.notifier).createCommunity(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community created successfully!')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCommunity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Community', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete "${widget.existingCommunity!.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await ref.read(communitiesProvider.notifier).deleteCommunity(widget.existingCommunity!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Community deleted successfully.')));
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingCommunity != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Text(
          isEdit ? 'Edit Community' : 'Create Community',
          style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      extendBodyBehindAppBar: false,
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
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Community Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _taglineController,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Tagline',
                          border: OutlineInputBorder(),
                          helperText: 'Short description (max 100 chars)',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Tagline is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Detailed Description',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Description is required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxMembersController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Members Limit',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          final num = int.tryParse(val);
                          if (num == null || num <= 0) return 'Must be positive number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. AI, Cyber, Web3',
                        ),
                      ),
                      if (_userRole == UserRole.admin && _facultyOptions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedFacultyHeadId,
                          decoration: const InputDecoration(
                            labelText: 'Faculty Head / Advisor',
                            border: OutlineInputBorder(),
                          ),
                          items: _facultyOptions.map((f) {
                            return DropdownMenuItem<String>(
                              value: f['id'].toString(),
                              child: Text(f['full_name']?.toString() ?? 'Faculty'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedFacultyHeadId = val;
                            });
                          },
                          validator: (val) => val == null ? 'Faculty Head is required' : null,
                        ),
                      ],
                      const SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F9EFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submit,
                        child: Text(
                          isEdit ? 'Save Changes' : 'Create Community',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 24),
                        const Divider(color: Colors.redAccent),
                        const SizedBox(height: 12),
                        const Text(
                          'Danger Zone',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Delete Community', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _deleteCommunity,
                        ),
                      ],
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
