import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/features/feedback/feedback_model.dart';
import 'package:unisharesync_mobile_app/features/feedback/feedback_service.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({
    super.key,
    this.initialRole,
    this.isLocalAdmin,
  });

  final UserRole? initialRole;
  final bool? isLocalAdmin;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final AuthService _authService = AuthService();
  final FeedbackService _service = FeedbackService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _responseController = TextEditingController();

  UserRole _role = UserRole.student;
  bool _isLocalAdmin = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSavingResponse = false;
  String? _currentUserId;
  int _selectedRating = 5;
  bool _isAnonymous = false;
  FeedbackCategory _selectedCategory = FeedbackCategory.general;
  FeedbackStatus? _selectedStatusFilter;
  String _selectedCategoryFilter = 'All Categories';

  late final Stream<List<FeedbackEntry>> _feedbackStream;

  @override
  void initState() {
    super.initState();
    _feedbackStream = _service.watchFeedback(limit: 200).asBroadcastStream();
    _bootstrap();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final role = widget.initialRole ?? await _authService.getCurrentRole();
      final isLocalAdmin =
          widget.isLocalAdmin ?? await _authService.isLocalAdminSession();

      if (!mounted) {
        return;
      }

      setState(() {
        _role = role ?? UserRole.student;
        _isLocalAdmin = isLocalAdmin;
        _currentUserId = _service.currentUserId;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentUserId = _service.currentUserId;
        _isLoading = false;
      });
    }
  }

  bool get _isAdmin => _role == UserRole.admin && !_isLocalAdmin;

  bool get _canSubmit => _currentUserId != null && !_isLocalAdmin;

  List<FeedbackEntry> _filterEntries(List<FeedbackEntry> entries) {
    final query = _searchController.text.trim().toLowerCase();

    return entries.where((entry) {
      final matchesQuery = query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          entry.content.toLowerCase().contains(query) ||
          entry.status.label.toLowerCase().contains(query) ||
          entry.category.label.toLowerCase().contains(query) ||
          entry.displayName.toLowerCase().contains(query) ||
          (entry.hasAdminResponse &&
              entry.adminResponse!.toLowerCase().contains(query));

      final matchesCategory = _selectedCategoryFilter == 'All Categories' ||
          entry.category.label == _selectedCategoryFilter;
      final matchesStatus = _selectedStatusFilter == null ||
          entry.status == _selectedStatusFilter;

      return matchesQuery && matchesCategory && matchesStatus;
    }).toList(growable: false);
  }

  Future<void> _submitFeedback() async {
    if (!_canSubmit) {
      _showSnackBar(
        _isLocalAdmin
            ? 'Feedback needs a Supabase-backed student or faculty session.'
            : 'Please sign in before submitting feedback.',
      );
      return;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      _showSnackBar('Add a title and details before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _service.createFeedback(
        draft: FeedbackDraft(
          category: _selectedCategory,
          title: title,
          content: content,
          rating: _selectedRating,
          isAnonymous: _isAnonymous,
        ),
      );

      _titleController.clear();
      _contentController.clear();
      setState(() {
        _selectedCategory = FeedbackCategory.general;
        _selectedRating = 5;
        _isAnonymous = false;
      });

      if (!mounted) {
        return;
      }

      _showSnackBar('Feedback submitted successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to submit feedback: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _respondToFeedback(FeedbackEntry entry) async {
    if (!_isAdmin) {
      return;
    }

    _responseController.text = entry.adminResponse ?? '';
    FeedbackStatus selectedStatus = entry.status == FeedbackStatus.pending
        ? FeedbackStatus.responded
        : entry.status;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  18,
                  18,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.95)),
                ),
                child: StatefulBuilder(
                  builder: (context, setSheetState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Respond to Feedback',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.title,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<FeedbackStatus>(
                          initialValue: selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: FeedbackStatus.values
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status.label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setSheetState(() {
                              selectedStatus = value;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _responseController,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Admin response',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            const Spacer(),
                            FilledButton(
                              onPressed: _isSavingResponse
                                  ? null
                                  : () async {
                                      final response =
                                          _responseController.text.trim();
                                      if (response.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Add a response before saving.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() {
                                        _isSavingResponse = true;
                                      });

                                      try {
                                        await _service.respondToFeedback(
                                          feedbackId: entry.id,
                                          response: response,
                                          status: selectedStatus,
                                        );
                                        if (context.mounted) {
                                          Navigator.of(context).pop(true);
                                        }
                                      } catch (error) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Unable to save response: $error',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isSavingResponse = false;
                                          });
                                        }
                                      }
                                    },
                              child: _isSavingResponse
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save Response'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    if (saved == true && mounted) {
      _showSnackBar('Response saved.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        title: const Text(
          'Feedback & Suggestions',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
      ),
      backgroundColor: const Color(0xFFF4F8FF),
      body: Stack(
        children: [
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
          Positioned(
            top: -90,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(0.08),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: _isAdmin ? _buildAdminView() : _buildUserView(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserView() {
    return StreamBuilder<List<FeedbackEntry>>(
      stream: _feedbackStream,
      builder: (context, snapshot) {
        final feedback = snapshot.data ?? const <FeedbackEntry>[];
        final myFeedback = feedback
            .where((entry) => entry.submitterId == _currentUserId)
            .toList(growable: false);
        final respondedCount =
            feedback.where((entry) => entry.status != FeedbackStatus.pending).length;
        final avgRating = feedback.isEmpty
            ? 0.0
            : feedback.map((entry) => entry.rating).reduce((a, b) => a + b) /
                feedback.length;
        final filteredMyFeedback = _filterEntries(myFeedback);
        final filteredCommunity = _filterEntries(feedback);

        return DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: _HeaderBlock(
                  title: 'Feedback & Suggestions',
                  subtitle:
                      'Share thoughts, track replies, and help improve the university experience.',
                  icon: Icons.forum_rounded,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = constraints.maxWidth < 700
                        ? (constraints.maxWidth - 10) / 2
                        : (constraints.maxWidth - 30) / 4;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _StatCard(
                            title: 'Total Feedback',
                            value: feedback.length.toString(),
                            icon: Icons.rate_review_outlined,
                            color: const Color(0xFF4F9EFF),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _StatCard(
                            title: 'My Feedback',
                            value: myFeedback.length.toString(),
                            icon: Icons.person_outline_rounded,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _StatCard(
                            title: 'Responded',
                            value: respondedCount.toString(),
                            icon: Icons.reply_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _StatCard(
                            title: 'Avg Rating',
                            value: avgRating.toStringAsFixed(1),
                            icon: Icons.star_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.84),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.95)),
                      ),
                      child: const TabBar(
                        isScrollable: true,
                        labelColor: Color(0xFF0F172A),
                        unselectedLabelColor: Color(0xFF64748B),
                        indicatorColor: Color(0xFF4F9EFF),
                        tabs: [
                          Tab(text: 'Submit Feedback'),
                          Tab(text: 'My Feedback'),
                          Tab(text: 'Community Feedback'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildSubmitTab(),
                    _buildFeedbackList(
                      entries: filteredMyFeedback,
                      emptyTitle: 'No feedback submitted yet',
                      emptySubtitle:
                          'Submit your first note, suggestion, or issue report.',
                    ),
                    _buildCommunityTab(filteredCommunity),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubmitTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.96)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submit Feedback',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Academic, Technical, or General feedback can be shared with or without your name.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Feedback title',
                    hintText: 'Brief title for your feedback',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FeedbackCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: FeedbackCategory.values
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'Rating',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (index) {
                    final rating = index + 1;
                    return IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedRating = rating;
                        });
                      },
                      icon: Icon(
                        rating <= _selectedRating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFF59E0B),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _contentController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Feedback details',
                    hintText: 'Please provide detailed feedback...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isAnonymous,
                  onChanged: (value) {
                    setState(() {
                      _isAnonymous = value;
                    });
                  },
                  title: const Text('Submit anonymously'),
                  subtitle: const Text(
                    'Your identity will be hidden in community views.',
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit Feedback'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityTab(List<FeedbackEntry> entries) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search feedback...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _buildFeedbackList(
            entries: entries,
            emptyTitle: 'No feedback found',
            emptySubtitle: 'No feedback matches your current filters.',
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackList({
    required List<FeedbackEntry> entries,
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    final filtered = _filterEntries(entries);

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFCBD5E1).withOpacity(0.25),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 36,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                emptyTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = filtered[index];
        return _FeedbackCard(
          entry: entry,
          isAdmin: _isAdmin,
          onRespond: _isAdmin ? () => _respondToFeedback(entry) : null,
        );
      },
    );
  }

  Widget _buildAdminView() {
    return StreamBuilder<List<FeedbackEntry>>(
      stream: _feedbackStream,
      builder: (context, snapshot) {
        final feedback = snapshot.data ?? const <FeedbackEntry>[];
        final respondedCount =
            feedback.where((entry) => entry.status != FeedbackStatus.pending).length;
        final anonymousCount = feedback.where((entry) => entry.isAnonymous).length;
        final avgRating = feedback.isEmpty
            ? 0.0
            : feedback.map((entry) => entry.rating).reduce((a, b) => a + b) /
                feedback.length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: _HeaderBlock(
                title: 'Feedback Management',
                subtitle: 'Monitor and respond to student feedback and suggestions.',
                icon: Icons.admin_panel_settings_rounded,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth < 700
                      ? (constraints.maxWidth - 10) / 2
                      : (constraints.maxWidth - 30) / 4;

                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: 'Total Feedback',
                          value: feedback.length.toString(),
                          icon: Icons.rate_review_outlined,
                          color: const Color(0xFF4F9EFF),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: 'Responded',
                          value: respondedCount.toString(),
                          icon: Icons.reply_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: 'Avg Rating',
                          value: avgRating.toStringAsFixed(1),
                          icon: Icons.star_rounded,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _StatCard(
                          title: 'Anonymous',
                          value: anonymousCount.toString(),
                          icon: Icons.visibility_off_rounded,
                          color: const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 720;

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.84),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white.withOpacity(0.95)),
                        ),
                        child: isCompact
                            ? Column(
                                children: [
                                  TextField(
                                    controller: _searchController,
                                    onChanged: (_) => setState(() {}),
                                    decoration: const InputDecoration(
                                      hintText: 'Search feedback...',
                                      prefixIcon: Icon(Icons.search_rounded),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    initialValue: _selectedCategoryFilter,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'All Categories',
                                        child: Text('All Categories'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Academic',
                                        child: Text('Academic'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Technical',
                                        child: Text('Technical'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'General',
                                        child: Text('General'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) {
                                        return;
                                      }
                                      setState(() {
                                        _selectedCategoryFilter = value;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<FeedbackStatus?>(
                                    initialValue: _selectedStatusFilter,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text('All Status'),
                                      ),
                                      DropdownMenuItem(
                                        value: FeedbackStatus.pending,
                                        child: Text('Pending'),
                                      ),
                                      DropdownMenuItem(
                                        value: FeedbackStatus.responded,
                                        child: Text('Responded'),
                                      ),
                                      DropdownMenuItem(
                                        value: FeedbackStatus.resolved,
                                        child: Text('Resolved'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedStatusFilter = value;
                                      });
                                    },
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (_) => setState(() {}),
                                      decoration: const InputDecoration(
                                        hintText: 'Search feedback...',
                                        prefixIcon: Icon(Icons.search_rounded),
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 170,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedCategoryFilter,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'All Categories',
                                          child: Text('All Categories'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Academic',
                                          child: Text('Academic'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Technical',
                                          child: Text('Technical'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'General',
                                          child: Text('General'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _selectedCategoryFilter = value;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 160,
                                    child: DropdownButtonFormField<FeedbackStatus?>(
                                      initialValue: _selectedStatusFilter,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text('All Status'),
                                        ),
                                        DropdownMenuItem(
                                          value: FeedbackStatus.pending,
                                          child: Text('Pending'),
                                        ),
                                        DropdownMenuItem(
                                          value: FeedbackStatus.responded,
                                          child: Text('Responded'),
                                        ),
                                        DropdownMenuItem(
                                          value: FeedbackStatus.resolved,
                                          child: Text('Resolved'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedStatusFilter = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _buildFeedbackList(
                entries: feedback,
                emptyTitle: 'No feedback found',
                emptySubtitle: 'No feedback matches your current filters.',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.96)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4F9EFF), Color(0xFF6366F1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.84),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.entry,
    required this.isAdmin,
    this.onRespond,
  });

  final FeedbackEntry entry;
  final bool isAdmin;
  final VoidCallback? onRespond;

  Color get _statusColor {
    switch (entry.status) {
      case FeedbackStatus.pending:
        return const Color(0xFFF59E0B);
      case FeedbackStatus.responded:
        return const Color(0xFF4F9EFF);
      case FeedbackStatus.resolved:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.96)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Pill(
                              label: entry.category.label,
                              color: const Color(0xFF6366F1),
                            ),
                            _Pill(
                              label: entry.status.label,
                              color: _statusColor,
                            ),
                            if (entry.isAnonymous)
                              _Pill(
                                label: 'Anonymous',
                                color: const Color(0xFF64748B),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          entry.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          entry.content,
                          style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin && onRespond != null)
                    TextButton.icon(
                      onPressed: onRespond,
                      icon: const Icon(Icons.reply_rounded),
                      label: const Text('Respond'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _RatingDisplay(rating: entry.rating),
                  const Spacer(),
                  Text(
                    entry.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDate(entry.createdAt),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              if (entry.hasAdminResponse) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Response',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.adminResponse!,
                        style: const TextStyle(height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _RatingDisplay extends StatelessWidget {
  const _RatingDisplay({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFF59E0B),
          size: 18,
        );
      }),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '${local.month}/${local.day}/${local.year} $hour:$minute $suffix';
}
