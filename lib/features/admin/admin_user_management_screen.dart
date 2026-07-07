import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/admin_user_management_service.dart';
import 'package:unisharesync_mobile_app/core/config/constants.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends State<AdminUserManagementScreen> {
  final _service = AdminUserManagementService();
  final _searchCtrl = TextEditingController();

  List<ProfileModel> _allUsers = [];
  bool _loading = true;
  String? _error;
  UserRole? _roleFilter; // null = All

  static const _bg = Color(0xFFF4F8FF);
  static const _blue = Color(0xFF4F9EFF);

  List<ProfileModel> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allUsers.where((u) {
      final matchesRole = _roleFilter == null || u.role == _roleFilter;
      final matchesSearch = q.isEmpty ||
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.studentId?.toLowerCase().contains(q) ?? false) ||
          (u.department?.toLowerCase().contains(q) ?? false);
      return matchesRole && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final users = await _service.getAllUsers();
      if (mounted) setState(() { _allUsers = users; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openCreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const _UserFormDialog(),
    );
    if (result == true) _load();
  }

  Future<void> _openEditDialog(ProfileModel user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => _UserFormDialog(existing: user),
    );
    if (result == true) _load();
  }

  Future<void> _toggleActive(ProfileModel user) async {
    final isActive = user.isActive;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isActive ? 'Deactivate Account' : 'Reactivate Account'),
        content: Text(
          isActive
              ? 'Deactivate ${user.fullName}? They won\'t be able to sign in.'
              : 'Reactivate ${user.fullName}?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isActive ? Colors.redAccent : _blue,
              ),
              onPressed: () => Navigator.pop(_, true),
              child: Text(isActive ? 'Deactivate' : 'Reactivate')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.setActiveStatus(user.id, active: !isActive);
      _load();
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Future<void> _changeRole(ProfileModel user) async {
    UserRole selected = user.role;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Change Role — ${user.fullName}'),
          content: DropdownButton<UserRole>(
            value: selected,
            isExpanded: true,
            items: UserRole.values
                .map((r) => DropdownMenuItem(
                    value: r, child: Text(r.displayName)))
                .toList(),
            onChanged: (v) {
              if (v != null) setSt(() => selected = v);
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirm != true || selected == user.role) return;
    try {
      await _service.changeRole(user.id, selected);
      _load();
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return const Color(0xFF06B6D4);
      case UserRole.faculty:
        return const Color(0xFF8B5CF6);
      case UserRole.driver:
        return const Color(0xFF14B8A6);
      case UserRole.student:
      default:
        return _blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'User Management',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0F172A))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: _blue,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Create User'),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          if (!_loading && _error == null)
            _buildSummaryBar(filtered),
          Expanded(child: _buildBody(filtered)),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search by name, email, ID…',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: Colors.grey.shade400),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Role filter chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _RoleChip(
                  label: 'All',
                  color: const Color(0xFF64748B),
                  selected: _roleFilter == null,
                  count: _allUsers.length,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                const SizedBox(width: 6),
                ...UserRole.values.map((r) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _RoleChip(
                    label: r.displayName,
                    color: _roleColor(r),
                    selected: _roleFilter == r,
                    count: _allUsers.where((u) => u.role == r).length,
                    onTap: () => setState(() => _roleFilter = r),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(List<ProfileModel> filtered) {
    final active = filtered.where((u) => u.isActive).length;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          _StatPill(label: 'Showing', value: '${filtered.length}', color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          _StatPill(label: 'Active', value: '$active', color: const Color(0xFF10B981)),
          const SizedBox(width: 10),
          _StatPill(label: 'Inactive', value: '${filtered.length - active}', color: Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildBody(List<ProfileModel> filtered) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              const Text('Failed to load users',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded, size: 52, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _searchCtrl.text.isNotEmpty || _roleFilter != null
                  ? 'No users match your filter.'
                  : 'No users found.',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _UserTile(
        user: filtered[i],
        roleColor: _roleColor(filtered[i].role),
        onEdit: () => _openEditDialog(filtered[i]),
        onToggleActive: () => _toggleActive(filtered[i]),
        onChangeRole: () => _changeRole(filtered[i]),
      ),
    );
  }
}

// ── Summary stat pill ────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('$value $label',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ],
    );
  }
}

// ── Role filter chip ─────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.count,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
          boxShadow: selected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.3) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.roleColor,
    required this.onEdit,
    required this.onToggleActive,
    required this.onChangeRole,
  });

  final ProfileModel user;
  final Color roleColor;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onChangeRole;

  @override
  Widget build(BuildContext context) {
    final active = user.isActive;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? Colors.grey.shade200 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          // Colored role accent bar at top
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: active ? roleColor : Colors.grey.shade300,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: roleColor.withOpacity(0.12),
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16),
                            )
                          : null,
                    ),
                    if (!active)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: active
                              ? const Color(0xFF0F172A)
                              : Colors.grey.shade400,
                          decoration:
                              active ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        user.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _Badge(label: user.role.displayName, color: roleColor),
                          if (user.department != null && user.department!.isNotEmpty)
                            _Badge(label: user.department!, color: const Color(0xFF94A3B8)),
                          if (user.studentId != null && user.studentId!.isNotEmpty)
                            _Badge(label: 'ID: ${user.studentId}', color: const Color(0xFF94A3B8)),
                          if (!active)
                            const _Badge(label: 'Inactive', color: Colors.redAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade500),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'role') onChangeRole();
                    if (v == 'toggle') onToggleActive();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Profile'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'role',
                      child: Row(children: [
                        Icon(Icons.swap_horiz_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Change Role'),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(children: [
                        Icon(
                          active ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: active ? Colors.redAccent : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(active ? 'Deactivate' : 'Reactivate'),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Create / Edit dialog ──────────────────────────────────────────────────────

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({this.existing});
  final ProfileModel? existing;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _service = AdminUserManagementService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _studentIdCtrl;
  late final TextEditingController _semCtrl;
  late final TextEditingController _designationCtrl;
  late UserRole _role;

  late final List<String> _dialogDepartments;
  String? _selectedDepartment;

  bool _saving = false;
  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _nameCtrl = TextEditingController(text: u?.fullName ?? '');
    _emailCtrl = TextEditingController(text: u?.email ?? '');
    _passwordCtrl = TextEditingController();
    _selectedDepartment = u?.department;
    _studentIdCtrl = TextEditingController(text: u?.studentId ?? '');
    _semCtrl = TextEditingController(text: u?.semester ?? '');
    _designationCtrl = TextEditingController(text: u?.designation ?? '');
    _role = u?.role ?? UserRole.student;

    if (_selectedDepartment != null && _selectedDepartment!.isNotEmpty) {
      if (!AppConstants.departments.contains(_selectedDepartment)) {
        _dialogDepartments = List.from(AppConstants.departments)..add(_selectedDepartment!);
      } else {
        _dialogDepartments = List.from(AppConstants.departments);
      }
    } else {
      _dialogDepartments = List.from(AppConstants.departments);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl, _emailCtrl, _passwordCtrl,
      _studentIdCtrl, _semCtrl, _designationCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _service.updateUser(widget.existing!.copyWith(
          fullName: _nameCtrl.text.trim(),
          role: _role,
          department: _selectedDepartment,
          studentId: _studentIdCtrl.text.trim().isEmpty ? null : _studentIdCtrl.text.trim(),
          semester: _semCtrl.text.trim().isEmpty ? null : _semCtrl.text.trim(),
          designation: _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
        ));
      } else {
        await _service.createUser(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          fullName: _nameCtrl.text.trim(),
          role: _role,
          department: _selectedDepartment,
          studentId: _studentIdCtrl.text.trim().isEmpty ? null : _studentIdCtrl.text.trim(),
          semester: _semCtrl.text.trim().isEmpty ? null : _semCtrl.text.trim(),
          designation: _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim(),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_isEdit ? 'Edit User' : 'Create User',
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_nameCtrl, 'Full Name', icon: Icons.person_outline_rounded, required: true),
                if (!_isEdit) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      final email = (v ?? '').trim();
                      if (email.isEmpty) return 'Email is required';
                      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                      if (!emailRegex.hasMatch(email)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      final password = v ?? '';
                      if (password.isEmpty) return 'Password is required';
                      if (password.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 10),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: UserRole.values
                      .map((r) => DropdownMenuItem(value: r, child: Text(r.displayName)))
                      .toList(),
                  onChanged: (v) => setState(() => _role = v ?? _role),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment,
                  decoration: InputDecoration(
                    labelText: 'Department',
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: _selectedDepartment != null
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () => setState(() => _selectedDepartment = null),
                          )
                        : null,
                  ),
                  dropdownColor: Colors.white,
                  isExpanded: true,
                  hint: const Text('Select Department'),
                  items: _dialogDepartments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDepartment = v),
                ),
                const SizedBox(height: 10),
                _field(_studentIdCtrl, 'Student ID', icon: Icons.badge_outlined),
                const SizedBox(height: 10),
                _field(_semCtrl, 'Semester', icon: Icons.calendar_today_outlined),
                const SizedBox(height: 10),
                _field(_designationCtrl, 'Designation', icon: Icons.work_outline_rounded),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    required IconData icon,
    bool required = false,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
