import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/auth_service.dart';
import '../../data/models/alumni_profile_model.dart';
import '../providers/alumni_admin_provider.dart';
import '../providers/alumni_provider.dart';

class AlumniAddEditScreen extends ConsumerStatefulWidget {
  final AlumniProfile? profile;

  const AlumniAddEditScreen({super.key, this.profile});

  @override
  ConsumerState<AlumniAddEditScreen> createState() => _AlumniAddEditScreenState();
}

class _AlumniAddEditScreenState extends ConsumerState<AlumniAddEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Fields
  late String _fullName;
  int? _batchYear;
  int? _graduationYear;
  String? _studentId;
  double? _cgpa;
  String? _thesisTitle;
  String? _notableAchievements;
  String? _currentJobTitle;
  String? _currentCompany;
  AlumniIndustry? _industry;
  String? _currentLocation;
  int? _yearsOfExperience;
  String? _email;
  String? _phone;
  String? _linkedinUrl;
  String? _githubUrl;
  String? _websiteUrl;
  String? _facebookUrl;
  bool _isOpenToMentor = false;
  final List<String> _selectedMentorAreas = [];
  String? _mentorAvailability;
  bool _showEmail = false;
  bool _showPhone = false;
  bool _showLinkedin = true;
  bool _showGithub = true;

  Uint8List? _selectedImageBytes;
  bool _hasPhotoChanged = false;
  bool _saving = false;

  final List<String> _allMentorAreas = [
    "Flutter Development",
    "Machine Learning",
    "Job Interview Prep",
    "Higher Studies Abroad",
    "Startup & Entrepreneurship",
    "Cybersecurity",
    "System Architecture"
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    if (p != null) {
      _fullName = p.fullName;
      _batchYear = p.batchYear;
      _graduationYear = p.graduationYear;
      _studentId = p.studentId;
      _cgpa = p.cgpa;
      _thesisTitle = p.thesisTitle;
      _notableAchievements = p.notableAchievements;
      _currentJobTitle = p.currentJobTitle;
      _currentCompany = p.currentCompany;
      _industry = p.industry;
      _currentLocation = p.currentLocation;
      _yearsOfExperience = p.yearsOfExperience;
      _email = p.email;
      _phone = p.phone;
      _linkedinUrl = p.linkedinUrl;
      _githubUrl = p.githubUrl;
      _websiteUrl = p.websiteUrl;
      _facebookUrl = p.facebookUrl;
      _isOpenToMentor = p.isOpenToMentor;
      if (p.mentorAreas != null) {
        _selectedMentorAreas.addAll(p.mentorAreas!);
      }
      _mentorAvailability = p.mentorAvailability;
      _showEmail = p.showEmail;
      _showPhone = p.showPhone;
      _showLinkedin = p.showLinkedin;
      _showGithub = p.showGithub;
    } else {
      _fullName = '';
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _hasPhotoChanged = true;
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImageBytes = null;
      _hasPhotoChanged = true;
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final currentYear = DateTime.now().year;

    // Validation: SMUCT alumni batches are 1-29
    if (_batchYear! < 1 || _batchYear! > 29) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid batch between 1 and 29."),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    // Warning: Batch whose graduation year is in the future/present might not have graduated
    final estimatedGradYear = _batchYear! < 100 ? (2006 + _batchYear!) : (_batchYear! + 4);
    if (estimatedGradYear >= currentYear) {
      final proceed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              title: const Text('Confirm Batch Year', style: TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              content: const Text(
                'This batch may not have graduated yet. Do you want to continue?',
                style: TextStyle(color: Color(0xFF475569), fontFamily: 'Outfit'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Back', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Continue', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ) ??
          false;

      if (!proceed) return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final currentUserId = AuthService().currentUserId ?? '00000000-0000-0000-0000-000000000000';
      final currentUserProfile = await AuthService().getCurrentProfile();
      final userRoleStr = currentUserProfile?.role.value ?? 'student';

      final entrySource = widget.profile?.entrySource ??
          (userRoleStr == 'admin' ? AlumniEntrySource.adminAdded : AlumniEntrySource.facultyAdded);
      
      final isVerified = widget.profile?.isVerified ?? (userRoleStr == 'admin');
      final isPublished = widget.profile?.isPublished ?? (userRoleStr == 'admin');

      final alumniId = widget.profile?.id ?? const Uuid().v4();
      final gradYear = _graduationYear ?? (_batchYear! < 100 ? (2006 + _batchYear!) : (_batchYear! + 4));

      final profile = AlumniProfile(
        id: alumniId,
        fullName: _fullName,
        profilePhotoUrl: widget.profile?.profilePhotoUrl,
        batchYear: _batchYear!,
        studentId: _studentId,
        graduationYear: gradYear,
        cgpa: _cgpa,
        thesisTitle: _thesisTitle,
        notableAchievements: _notableAchievements,
        currentJobTitle: _currentJobTitle,
        currentCompany: _currentCompany,
        industry: _industry,
        currentLocation: _currentLocation,
        yearsOfExperience: _yearsOfExperience,
        email: _email,
        phone: _phone,
        linkedinUrl: _linkedinUrl,
        githubUrl: _githubUrl,
        websiteUrl: _websiteUrl,
        facebookUrl: _facebookUrl,
        isOpenToMentor: _isOpenToMentor,
        mentorAreas: _selectedMentorAreas.isNotEmpty ? _selectedMentorAreas : null,
        mentorAvailability: _mentorAvailability,
        showEmail: _showEmail,
        showPhone: _showPhone,
        showLinkedin: _showLinkedin,
        showGithub: _showGithub,
        entrySource: entrySource,
        isVerified: isVerified,
        isPublished: isPublished,
        linkedUserId: widget.profile?.linkedUserId,
        addedBy: widget.profile?.addedBy ?? currentUserId,
        approvedBy: widget.profile?.approvedBy,
        createdAt: widget.profile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        approvedAt: widget.profile?.approvedAt,
      );

      if (widget.profile == null) {
        // Create Mode
        await ref.read(alumniAdminProvider.notifier).addAlumni(profile, _selectedImageBytes);
      } else {
        // Edit Mode
        await ref.read(alumniAdminProvider.notifier).updateAlumni(profile, _selectedImageBytes, _hasPhotoChanged);
      }

      // Sync Public Directory
      ref.read(alumniProvider.notifier).fetchAlumni(forceRefresh: true);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.profile == null
                ? isVerified
                    ? 'Alumni profile added successfully!'
                    : 'Alumni profile submitted. Pending Admin approval.'
                : 'Alumni profile updated successfully!',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save profile: ${e.toString().replaceAll("StateError:", "").trim()}'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.profile == null ? 'Add Alumni Profile' : 'Edit Alumni Profile';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF6FF)],
          ),
        ),
        child: _saving
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo Upload Picker
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: const Color(0xFFE2E8F0),
                              backgroundImage: _selectedImageBytes != null
                                  ? MemoryImage(_selectedImageBytes!)
                                  : (widget.profile?.profilePhotoUrl != null
                                      ? NetworkImage(widget.profile!.profilePhotoUrl!)
                                      : null) as ImageProvider?,
                              child: _selectedImageBytes == null && widget.profile?.profilePhotoUrl == null
                                  ? const Icon(Icons.person_rounded, size: 48, color: Color(0xFF94A3B8))
                                  : null,
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_selectedImageBytes != null || widget.profile?.profilePhotoUrl != null)
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFEF4444),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_rounded, size: 14, color: Colors.white),
                                      onPressed: _removePhoto,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF2563EB),
                                  child: IconButton(
                                    icon: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // SECTION 1: Identity
                      _buildSectionTitle('Section 1: Identity Info'),
                      _buildInputField(
                        label: 'Full Name *',
                        initialValue: _fullName,
                        onSaved: (val) => _fullName = val ?? '',
                        validator: (val) => val == null || val.trim().isEmpty ? 'Full name is required' : null,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              label: 'Batch (1-29) *',
                              initialValue: _batchYear?.toString(),
                              keyboardType: TextInputType.number,
                              onSaved: (val) => _batchYear = int.tryParse(val ?? ''),
                              validator: (val) {
                                if (val == null || val.isEmpty) return 'Required';
                                final num = int.tryParse(val);
                                if (num == null) return 'Must be a number';
                                if (num < 1 || num > 29) return 'Batch 1-29 only';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInputField(
                              label: 'Graduation Year',
                              initialValue: _graduationYear?.toString(),
                              keyboardType: TextInputType.number,
                              onSaved: (val) => _graduationYear = int.tryParse(val ?? ''),
                              hint: 'Default batch + 4',
                            ),
                          ),
                        ],
                      ),
                      _buildInputField(
                        label: 'Student ID',
                        initialValue: _studentId,
                        onSaved: (val) => _studentId = val,
                      ),

                      // SECTION 2: Academic
                      _buildSectionTitle('Section 2: Academic Background'),
                      _buildInputField(
                        label: 'Cumulative CGPA (0.00 - 4.00)',
                        initialValue: _cgpa?.toString(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onSaved: (val) => _cgpa = double.tryParse(val ?? ''),
                        validator: (val) {
                          if (val == null || val.isEmpty) return null;
                          final parsed = double.tryParse(val);
                          if (parsed == null || parsed < 0.0 || parsed > 4.0) {
                            return 'CGPA must be between 0.00 and 4.00';
                          }
                          return null;
                        },
                      ),
                      _buildInputField(
                        label: 'Thesis / Project Title',
                        initialValue: _thesisTitle,
                        onSaved: (val) => _thesisTitle = val,
                      ),
                      _buildInputField(
                        label: 'Notable Achievements',
                        initialValue: _notableAchievements,
                        onSaved: (val) => _notableAchievements = val,
                        maxLines: 2,
                      ),

                      // SECTION 3: Professional
                      _buildSectionTitle('Section 3: Professional Info'),
                      _buildInputField(
                        label: 'Current Job Title / Role',
                        initialValue: _currentJobTitle,
                        onSaved: (val) => _currentJobTitle = val,
                        hint: 'e.g., Senior Software Engineer',
                      ),
                      _buildInputField(
                        label: 'Current Company / Organization',
                        initialValue: _currentCompany,
                        onSaved: (val) => _currentCompany = val,
                        hint: 'e.g., Brain Station 23',
                      ),
                      _buildIndustryDropdown(),
                      _buildInputField(
                        label: 'Current Location',
                        initialValue: _currentLocation,
                        onSaved: (val) => _currentLocation = val,
                        hint: 'e.g., Toronto, Canada',
                      ),
                      _buildInputField(
                        label: 'Years of Experience',
                        initialValue: _yearsOfExperience?.toString(),
                        keyboardType: TextInputType.number,
                        onSaved: (val) => _yearsOfExperience = int.tryParse(val ?? ''),
                      ),

                      // SECTION 4: Contact & Social
                      _buildSectionTitle('Section 4: Contact & Social Info'),
                      _buildInputField(
                        label: 'Personal Email',
                        initialValue: _email,
                        keyboardType: TextInputType.emailAddress,
                        onSaved: (val) => _email = val,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return null;
                          final emailReg = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                          if (!emailReg.hasMatch(val.trim())) return 'Invalid email format';
                          return null;
                        },
                      ),
                      _buildInputField(
                        label: 'Phone Number',
                        initialValue: _phone,
                        keyboardType: TextInputType.phone,
                        onSaved: (val) => _phone = val,
                      ),
                      _buildInputField(
                        label: 'LinkedIn Profile URL',
                        initialValue: _linkedinUrl,
                        onSaved: (val) => _linkedinUrl = val,
                      ),
                      _buildInputField(
                        label: 'GitHub Profile URL',
                        initialValue: _githubUrl,
                        onSaved: (val) => _githubUrl = val,
                      ),
                      _buildInputField(
                        label: 'Website / Portfolio URL',
                        initialValue: _websiteUrl,
                        onSaved: (val) => _websiteUrl = val,
                      ),
                      _buildInputField(
                        label: 'Facebook Profile URL',
                        initialValue: _facebookUrl,
                        onSaved: (val) => _facebookUrl = val,
                      ),

                      // SECTION 5: Mentorship
                      _buildSectionTitle('Section 5: Mentorship Settings'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Open to Mentorship',
                            style: TextStyle(color: Color(0xFF475569), fontFamily: 'Outfit'),
                          ),
                          Switch(
                            value: _isOpenToMentor,
                            onChanged: (val) {
                              setState(() {
                                _isOpenToMentor = val;
                              });
                            },
                            activeThumbColor: const Color(0xFFFBBF24),
                          ),
                        ],
                      ),
                      if (_isOpenToMentor) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Select Mentor Areas:',
                          style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allMentorAreas.map((area) {
                            final isSelected = _selectedMentorAreas.contains(area);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedMentorAreas.remove(area);
                                  } else {
                                    _selectedMentorAreas.add(area);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFFBBF24).withOpacity(0.1)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  area,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFFD97706) : const Color(0xFF475569),
                                    fontSize: 12,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        _buildInputField(
                          label: 'Availability Notes',
                          initialValue: _mentorAvailability,
                          onSaved: (val) => _mentorAvailability = val,
                          hint: 'e.g., Weekends only, online',
                        ),
                      ],

                      // SECTION 6: Visibility Preferences
                      _buildSectionTitle('Section 6: Visibility Preferences'),
                      _buildVisibilitySwitch(
                        label: 'Show Email publicly',
                        value: _showEmail,
                        onChanged: (val) => setState(() => _showEmail = val),
                      ),
                      _buildVisibilitySwitch(
                        label: 'Show Phone publicly',
                        value: _showPhone,
                        onChanged: (val) => setState(() => _showPhone = val),
                      ),
                      _buildVisibilitySwitch(
                        label: 'Show LinkedIn publicly',
                        value: _showLinkedin,
                        onChanged: (val) => setState(() => _showLinkedin = val),
                      ),
                      _buildVisibilitySwitch(
                        label: 'Show GitHub publicly',
                        value: _showGithub,
                        onChanged: (val) => setState(() => _showGithub = val),
                      ),

                      const SizedBox(height: 36),
                      // Save CTA
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Save Profile',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    String? initialValue,
    TextInputType? keyboardType,
    int maxLines = 1,
    FormFieldSetter<String>? onSaved,
    FormFieldValidator<String>? validator,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextFormField(
              initialValue: initialValue,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 14),
              onSaved: onSaved,
              validator: validator,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndustryDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Industry Sector',
            style: TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<AlumniIndustry>(
                initialValue: _industry,
                decoration: const InputDecoration(border: InputBorder.none),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 14),
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                onChanged: (newIndustry) {
                  setState(() {
                    _industry = newIndustry;
                  });
                },
                items: AlumniIndustry.values.map((ind) {
                  return DropdownMenuItem(
                    value: ind,
                    child: Text(ind.displayName),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilitySwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF475569), fontSize: 13, fontFamily: 'Outfit')),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF2563EB),
          ),
        ],
      ),
    );
  }
}
