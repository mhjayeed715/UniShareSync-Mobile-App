import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _semesterController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();

  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isSaving = false;

  Uint8List? _selectedImageBytes;
  String? _selectedImageExtension;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _departmentController.dispose();
    _semesterController.dispose();
    _studentIdController.dispose();
    _designationController.dispose();
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
    _departmentController.text = profile.department ?? '';
    _semesterController.text = profile.semester ?? '';
    _studentIdController.text = profile.studentId ?? '';
    _designationController.text = profile.designation ?? '';

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
        department: _departmentController.text.trim().isEmpty
            ? null
            : _departmentController.text.trim(),
        semester: _semesterController.text.trim().isEmpty
            ? null
            : _semesterController.text.trim(),
        studentId: _studentIdController.text.trim().isEmpty
            ? null
            : _studentIdController.text.trim(),
        designation: _designationController.text.trim().isEmpty
            ? null
            : _designationController.text.trim(),
        avatarUrl: avatarUrl,
      );

      await _profileService.updateCurrentProfile(updatedProfile);

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
        title: const Text('Profile Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'No profile found for this account yet. Complete email verification and sign in again.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 46,
                                backgroundColor: const Color(0xFF4F9EFF).withOpacity(0.15),
                                backgroundImage: _selectedImageBytes != null
                                    ? MemoryImage(_selectedImageBytes!)
                                    : (profile.avatarUrl != null
                                        ? NetworkImage(profile.avatarUrl!)
                                        : null) as ImageProvider<Object>?,
                                child: _selectedImageBytes == null && profile.avatarUrl == null
                                    ? Text(
                                        profile.fullName.isNotEmpty
                                            ? profile.fullName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 22,
                                          color: Color(0xFF2B5B94),
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              TextButton.icon(
                                onPressed: _pickPhoto,
                                icon: const Icon(Icons.upload_rounded),
                                label: const Text('Upload Profile Photo'),
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
                        _LabeledInput(
                          controller: _departmentController,
                          label: 'Department',
                          hintText: 'Department name',
                        ),
                        const SizedBox(height: 12),
                        if (profile.role == UserRole.student) ...[
                          _LabeledInput(
                            controller: _studentIdController,
                            label: 'Student ID',
                            hintText: 'Student ID',
                          ),
                          const SizedBox(height: 12),
                          _LabeledInput(
                            controller: _semesterController,
                            label: 'Semester',
                            hintText: 'Current semester',
                          ),
                        ] else ...[
                          _LabeledInput(
                            controller: _designationController,
                            label: 'Designation',
                            hintText: 'Lecturer / Professor / Admin',
                          ),
                        ],
                        const SizedBox(height: 18),
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
