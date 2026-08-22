import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';
import 'package:unisharesync_mobile_app/services/profile_service.dart';

class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() => _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final ProfileService _profileService = ProfileService();
  final ImagePicker _imagePicker = ImagePicker();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _groupController = TextEditingController();

  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  Uint8List? _selectedImageBytes;
  String? _selectedImageExtension;

  bool _canChangeSemester = true;
  String? _semesterLockMessage;
  String? _selectedSemester;

  static const List<String> _semesterOptions = [
    'Semester 1',
    'Semester 2',
    'Semester 3',
    'Semester 4',
    'Semester 5',
    'Semester 6',
    'Semester 7',
    'Semester 8',
    'Semester 9',
    'Semester 10',
    'Semester 11',
    'Semester 12',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _designationController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getCurrentProfile();

    if (!mounted) {
      return;
    }

    if (profile == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    _fullNameController.text = profile.fullName;
    _designationController.text = profile.designation ?? '';

    if (profile.semester != null && profile.semester!.isNotEmpty) {
      final sem = profile.semester!.trim();
      if (_semesterOptions.contains(sem)) {
        _selectedSemester = sem;
      } else {
        final digits = sem.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isNotEmpty) {
          final matched = 'Semester $digits';
          _selectedSemester = _semesterOptions.contains(matched) ? matched : sem;
        } else {
          _selectedSemester = sem;
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final group = prefs.getString('preferred_routine_group') ?? '';
    _groupController.text = group;

    final lastChangeStr = prefs.getString('last_semester_change_${profile.id}');
    if (lastChangeStr != null) {
      final lastChange = DateTime.tryParse(lastChangeStr);
      if (lastChange != null) {
        final daysPassed = DateTime.now().difference(lastChange).inDays;
        if (daysPassed < 180) {
          final daysRemaining = 180 - daysPassed;
          final nextDate = lastChange.add(const Duration(days: 180));
          _canChangeSemester = false;
          _semesterLockMessage =
              'Semester can only be changed once every 6 months. Next change available in $daysRemaining days (${nextDate.day}/${nextDate.month}/${nextDate.year}).';
        }
      }
    }

    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<void> _pickPhoto() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();
    final ext = image.path.contains('.') ? image.path.split('.').last : 'jpg';

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageExtension = ext;
    });
  }

  Future<void> _saveProfile() async {
    final profile = _profile;
    if (profile == null) {
      return;
    }

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final isSemesterChanged = (profile.semester ?? '').trim() != (_selectedSemester ?? '').trim();
    if (profile.role == UserRole.student && isSemesterChanged && !_canChangeSemester) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_semesterLockMessage ?? 'Semester can only be changed once every 6 months.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? avatarUrl = profile.avatarUrl;

      if (_selectedImageBytes != null && _selectedImageExtension != null) {
        avatarUrl = await _profileService.uploadProfilePhoto(
          bytes: _selectedImageBytes!,
          fileExtension: _selectedImageExtension!,
        );
      }

      final updatedProfile = profile.copyWith(
        fullName: _fullNameController.text.trim(),
        department: profile.department,
        semester: profile.role == UserRole.student ? _selectedSemester : null,
        studentId: profile.studentId,
        designation: _designationController.text.trim().isEmpty
            ? null
            : _designationController.text.trim(),
        avatarUrl: avatarUrl,
      );

      await _profileService.updateCurrentProfile(updatedProfile);

      final prefs = await SharedPreferences.getInstance();
      if (_groupController.text.trim().isNotEmpty) {
        await prefs.setString('preferred_routine_group', _groupController.text.trim().toUpperCase());
      }
      if (profile.role == UserRole.student && isSemesterChanged) {
        await prefs.setString('last_semester_change_${profile.id}', DateTime.now().toIso8601String());
        _canChangeSemester = false;
        final nextDate = DateTime.now().add(const Duration(days: 180));
        _semesterLockMessage =
            'Semester can only be changed once every 6 months. Next change available in 180 days (${nextDate.day}/${nextDate.month}/${nextDate.year}).';
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _profile = updatedProfile;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Profile Settings',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const _ProfileSkeleton()
          : profile == null
              ? const Center(child: Text('Profile not available.'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFF4F9EFF).withOpacity(0.16),
                                backgroundImage: _selectedImageBytes != null
                                    ? MemoryImage(_selectedImageBytes!)
                                    : (profile.avatarUrl != null
                                        ? NetworkImage(profile.avatarUrl!)
                                        : null) as ImageProvider?,
                                child: _selectedImageBytes == null && profile.avatarUrl == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 46,
                                        color: Color(0xFF4F9EFF),
                                      )
                                    : null,
                              ),
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _pickPhoto,
                                    customBorder: const CircleBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _LabeledInput(
                          controller: _fullNameController,
                          label: 'Full Name',
                          hintText: 'Your full name',
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _ReadOnlyInfoTile(
                          label: 'Email',
                          value: profile.email,
                        ),
                        const SizedBox(height: 12),
                        _ReadOnlyInfoTile(
                          label: 'Role',
                          value: profile.role.displayName,
                        ),
                        const SizedBox(height: 12),
                        _ReadOnlyInfoTile(
                          label: 'Department (Locked)',
                          value: profile.department?.isNotEmpty == true
                              ? profile.department!
                              : 'Not assigned',
                        ),
                        const SizedBox(height: 12),
                        if (profile.role == UserRole.student) ...[
                          _ReadOnlyInfoTile(
                            label: 'Student ID (Locked)',
                            value: profile.studentId?.isNotEmpty == true
                                ? profile.studentId!
                                : 'Not assigned',
                          ),
                          const SizedBox(height: 12),
                          if (!_canChangeSemester) ...[
                            _ReadOnlyInfoTile(
                              label: 'Semester (Locked - 6mo Cooldown)',
                              value: profile.semester ?? 'Not assigned',
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_clock_rounded, size: 16, color: Colors.amber.shade900),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _semesterLockMessage ?? 'Semester can only be changed once every 6 months.',
                                      style: TextStyle(
                                        color: Colors.amber.shade900,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Semester',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _semesterOptions.contains(_selectedSemester)
                                      ? _selectedSemester
                                      : null,
                                  decoration: InputDecoration(
                                    hintText: 'Select your current semester',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.82),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: const Color(0xFF4F9EFF).withOpacity(0.2),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: const Color(0xFF4F9EFF).withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                                  items: _semesterOptions
                                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedSemester = val;
                                    });
                                  },
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Note: Semester can only be changed once every 6 months.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          _LabeledInput(
                            controller: _groupController,
                            label: 'Default Routine Group / Section',
                            hintText: 'e.g. 10A, 10B, 9A, A, B',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your routine scheduler will automatically filter for this group by default.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ] else ...[
                          _LabeledInput(
                            controller: _designationController,
                            label: 'Designation',
                            hintText: 'Lecturer / Professor / Admin',
                          ),
                        ],
                        const SizedBox(height: 20),
                        _PrimaryButton(
                          onTap: _isSaving ? null : _saveProfile,
                          isLoading: _isSaving,
                          label: 'Save Changes',
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(width: 92, height: 92, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), shape: BoxShape.circle)),
                const SizedBox(height: 10),
                Container(width: 140, height: 14, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 80, height: 13, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(width: double.infinity, height: 48, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(14))),
              ],
            ),
          )),
          Container(width: double.infinity, height: 52, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(14))),
        ],
      ),
    );
  }
}

class _LabeledInput extends StatelessWidget {
  const _LabeledInput({
    required this.controller,
    required this.label,
    required this.hintText,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: Colors.white.withOpacity(0.82),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: const Color(0xFF4F9EFF).withOpacity(0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: const Color(0xFF4F9EFF).withOpacity(0.2),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xFF4F9EFF), width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyInfoTile extends StatelessWidget {
  const _ReadOnlyInfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4F9EFF).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.onTap,
    required this.label,
    required this.isLoading,
  });

  final VoidCallback? onTap;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onTap == null
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade300])
              : const LinearGradient(
                  colors: [Color(0xFF4F9EFF), Color(0xFF2DD4BF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
