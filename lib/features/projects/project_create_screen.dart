import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';
import 'package:unisharesync_mobile_app/providers/project_hub_providers.dart';

class ProjectCreateScreen extends ConsumerStatefulWidget {
  const ProjectCreateScreen({super.key, this.existingProject});

  final ProjectModel? existingProject;

  @override
  ConsumerState<ProjectCreateScreen> createState() => _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends ConsumerState<ProjectCreateScreen> {
  int _currentStep = 0;
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _skillsController;
  late TextEditingController _maxMembersController;
  
  // Selection States
  int _semesterNo = 1;
  ProjectType _projectType = ProjectType.courseProject;
  ProjectCategory _category = ProjectCategory.other;
  ProjectVisibility _visibility = ProjectVisibility.public;
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  List<String> _skillsList = [];
  
  // Course Selector States (from routines)
  String? _selectedCourseCode;
  String? _selectedCourseName;
  List<Map<String, String>> _fetchedCourses = [];
  bool _isLoadingCourses = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingProject;
    _titleController = TextEditingController(text: p?.title ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _skillsController = TextEditingController();
    _maxMembersController = TextEditingController(text: p?.maxMembers.toString() ?? '5');

    if (p != null) {
      _semesterNo = p.semesterNo;
      _projectType = p.projectType;
      _category = p.category;
      _visibility = p.visibility;
      _deadline = p.deadline;
      _skillsList = List.from(p.requiredSkills);
      _selectedCourseCode = p.courseCode;
      _selectedCourseName = p.courseName;
    }

    _loadRoutinesCourses();
  }

  Future<void> _loadRoutinesCourses() async {
    setState(() => _isLoadingCourses = true);
    try {
      final response = await Supabase.instance.client
          .from('routines')
          .select('course_code, course_title')
          .order('course_code');
      
      final Set<String> codes = {};
      final List<Map<String, String>> list = [];
      for (final row in response as List) {
        final code = row['course_code']?.toString();
        final title = row['course_title']?.toString() ?? row['course_display']?.toString() ?? 'Unknown Course';
        if (code != null && !codes.contains(code)) {
          codes.add(code);
          list.add({'code': code, 'title': title});
        }
      }
      setState(() {
        _fetchedCourses = list;
        _isLoadingCourses = false;
      });
    } catch (_) {
      setState(() => _isLoadingCourses = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    _maxMembersController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_projectType == ProjectType.courseProject && _selectedCourseCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course Code is required for Course Project type.')),
      );
      return;
    }

    final draft = ProjectDraft(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _category,
      semesterNo: _semesterNo,
      maxMembers: int.tryParse(_maxMembersController.text) ?? 5,
      requiredSkills: _skillsList,
      deadline: _deadline,
      courseCode: _selectedCourseCode,
      courseName: _selectedCourseName,
      projectType: _projectType,
      visibility: _visibility,
    );

    try {
      final service = ref.read(projectsServiceProvider);
      if (widget.existingProject == null) {
        await service.createProject(draft);
      } else {
        await service.updateProject(projectId: widget.existingProject!.id, draft: draft);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save project: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentStep > 0) {
          setState(() {
            _currentStep--;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FF),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: Text(
            widget.existingProject == null ? 'Create Project' : 'Edit Project',
            style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          leading: BackButton(
            onPressed: () {
              if (_currentStep > 0) {
                setState(() {
                  _currentStep--;
                });
              } else {
                Navigator.of(context).pop();
              }
            },
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
            Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF2563EB),
                  secondary: const Color(0xFF2563EB),
                ),
              ),
              child: Stepper(
                type: StepperType.horizontal,
                currentStep: _currentStep,
                onStepTapped: (step) {
                  // Validate intermediate steps if jumping forward
                  if (step > _currentStep) {
                    if (_currentStep == 0) {
                      if (!(_formKey1.currentState?.validate() ?? false)) return;
                    } else if (_currentStep == 1) {
                      if (!(_formKey2.currentState?.validate() ?? false)) return;
                    }
                  }
                  setState(() => _currentStep = step);
                },
                onStepContinue: () {
                  if (_currentStep == 0) {
                    if (_formKey1.currentState?.validate() ?? false) {
                      setState(() => _currentStep++);
                    }
                  } else if (_currentStep == 1) {
                    if (_formKey2.currentState?.validate() ?? false) {
                      setState(() => _currentStep++);
                    }
                  } else if (_currentStep < 3) {
                    setState(() => _currentStep++);
                  } else {
                    _save();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep--);
                  }
                },
                controlsBuilder: (BuildContext context, ControlsDetails details) {
                  final isLastStep = _currentStep == 3;
                  return Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Row(
                      children: [
                        if (_currentStep > 0) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: details.onStepCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_back, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Back',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: ElevatedButton(
                            onPressed: details.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLastStep ? (widget.existingProject == null ? 'Create' : 'Save') : 'Next',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (!isLastStep) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Details', style: TextStyle(color: Color(0xFF0F172A))),
                    isActive: _currentStep >= 0,
                    content: _buildStep1Form(),
                  ),
                  Step(
                    title: const Text('Course', style: TextStyle(color: Color(0xFF0F172A))),
                    isActive: _currentStep >= 1,
                    content: _buildStep2Form(),
                  ),
                  Step(
                    title: const Text('Team', style: TextStyle(color: Color(0xFF0F172A))),
                    isActive: _currentStep >= 2,
                    content: _buildStep3Form(),
                  ),
                  Step(
                    title: const Text('Preview', style: TextStyle(color: Color(0xFF0F172A))),
                    isActive: _currentStep >= 3,
                    content: _buildStep4Preview(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Form() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _titleController,
            label: 'Project Title',
            validator: (val) => (val == null || val.length < 3) ? 'Title must be at least 3 chars' : null,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _descriptionController,
            label: 'Description',
            maxLines: 4,
            validator: (val) => (val == null || val.length < 10) ? 'Description must be at least 10 chars' : null,
          ),
          const SizedBox(height: 16),
          const Text('Category', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildGlassDropdown<ProjectCategory>(
            value: _category,
            items: ProjectCategory.values.map((cat) {
              return DropdownMenuItem(value: cat, child: Text(cat.displayName));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _category = val);
            },
          ),
          const SizedBox(height: 16),
          const Text('Project Deadline', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDeadlinePicker(),
        ],
      ),
    );
  }

  Widget _buildStep2Form() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Semester (1 - 12)', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildGlassDropdown<int>(
            value: _semesterNo,
            items: List.generate(12, (index) => index + 1).map((sem) {
              return DropdownMenuItem(value: sem, child: Text('Semester $sem'));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _semesterNo = val);
            },
          ),
          const SizedBox(height: 16),
          const Text('Project Type', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildGlassDropdown<ProjectType>(
            value: _projectType,
            items: ProjectType.values.map((type) {
              return DropdownMenuItem(value: type, child: Text(type.displayName));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _projectType = val);
            },
          ),
          const SizedBox(height: 16),

          if (_projectType == ProjectType.courseProject) ...[
            const Text('Select Course Code', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _isLoadingCourses
                ? const LinearProgressIndicator()
                : _buildGlassDropdown<String>(
                    value: _selectedCourseCode,
                    items: _fetchedCourses.map((course) {
                      return DropdownMenuItem(
                        value: course['code'],
                        child: Text('${course['code']} - ${course['title']}'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      final details = _fetchedCourses.firstWhere((c) => c['code'] == val);
                      setState(() {
                        _selectedCourseCode = val;
                        _selectedCourseName = details['title'];
                      });
                    },
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _maxMembersController,
          label: 'Max Team Size (1 - 10)',
          keyboardType: TextInputType.number,
          validator: (val) {
            final parsed = int.tryParse(val ?? '');
            if (parsed == null || parsed < 1 || parsed > 10) return 'Size must be between 1 and 10';
            return null;
          },
        ),
        const SizedBox(height: 16),
        const Text('Project Visibility', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildGlassDropdown<ProjectVisibility>(
          value: _visibility,
          items: ProjectVisibility.values.map((vis) {
            return DropdownMenuItem(value: vis, child: Text(vis.displayName));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _visibility = val);
          },
        ),
        const SizedBox(height: 16),
        const Text('Required Skills', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _skillsController,
                label: 'Add skill tag (e.g. Flutter)',
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF2563EB), size: 32),
              onPressed: () {
                final skill = _skillsController.text.trim();
                if (skill.isNotEmpty && !_skillsList.contains(skill)) {
                  setState(() {
                    _skillsList.add(skill);
                    _skillsController.clear();
                  });
                }
              },
            )
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _skillsList.map((skill) {
            return Chip(
              label: Text(skill, style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF2563EB).withOpacity(0.12),
              deleteIconColor: Colors.redAccent,
              side: BorderSide(color: const Color(0xFF2563EB).withOpacity(0.2)),
              onDeleted: () {
                setState(() => _skillsList.remove(skill));
              },
            );
          }).toList(),
        )
      ],
    );
  }

  Widget _buildStep4Preview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreviewItem('Title', _titleController.text),
        _buildPreviewItem('Description', _descriptionController.text),
        _buildPreviewItem('Semester', 'Semester $_semesterNo'),
        _buildPreviewItem('Category', _category.displayName),
        _buildPreviewItem('Project Type', _projectType.displayName),
        if (_selectedCourseCode != null) _buildPreviewItem('Course Code', '$_selectedCourseCode - $_selectedCourseName'),
        _buildPreviewItem('Max Team Size', _maxMembersController.text),
        _buildPreviewItem('Visibility', _visibility.displayName),
        _buildPreviewItem('Deadline', '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}'),
        _buildPreviewItem('Skills Required', _skillsList.join(', ')),
      ],
    );
  }

  Widget _buildPreviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 15)),
            TextSpan(text: value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDropdown<T>({
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            dropdownColor: Colors.white,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
            underline: Container(),
            isExpanded: true,
            iconEnabledColor: const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildDeadlinePicker() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w500),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Color(0xFF2563EB),
                            onPrimary: Colors.white,
                            onSurface: Color(0xFF0F172A),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() => _deadline = picked);
                  }
                },
                child: const Text(
                  'Choose Date',
                  style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
