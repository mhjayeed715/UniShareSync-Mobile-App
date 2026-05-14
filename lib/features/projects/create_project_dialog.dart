import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/data/models/project_model.dart';

class CreateProjectDialog extends StatefulWidget {
  const CreateProjectDialog({super.key, this.existingProject});

  final ProjectModel? existingProject;

  @override
  State<CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skillsController = TextEditingController();

  int? _selectedSemesterNo;
  String? _selectedCategory;
  int _maxMembers = 5;
  DateTime _deadline = DateTime.now().add(const Duration(days: 30));
  List<String> _skills = [];

  final _semesters = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
  ];

  final _categories = [
    'Mobile Development',
    'Web Development',
    'Desktop Application',
    'AI & Machine Learning',
    'Data Science',
    'Game Development',
    'IoT',
    'Cloud Computing',
    'DevOps',
    'Other',
  ];

  bool get _isEditing => widget.existingProject != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingProject;
    if (existing == null) {
      return;
    }

    _titleController.text = existing.title;
    _descriptionController.text = existing.description;
    _selectedCategory = existing.category;
    _selectedSemesterNo = existing.semesterNo;
    _maxMembers = existing.maxMembers;
    _deadline = existing.deadline;
    _skills = List<String>.from(existing.requiredSkills);
  }

  void _addSkill() {
    if (_skillsController.text.trim().isNotEmpty) {
      setState(() {
        _skills.add(_skillsController.text.trim());
        _skillsController.clear();
      });
    }
  }

  void _removeSkill(int index) {
    setState(() {
      _skills.removeAt(index);
    });
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() &&
        _selectedSemesterNo != null &&
        _selectedCategory != null) {
      final draft = ProjectDraft(
        id: widget.existingProject?.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        semesterNo: _selectedSemesterNo!,
        maxMembers: _maxMembers,
        requiredSkills: _skills,
        deadline: _deadline,
      );

      Navigator.pop(context, draft);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.95)),
            ),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  _isEditing ? 'Edit Project' : 'Create New Project',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                leading: CloseButton(
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Project Title'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _titleController,
                          hintText: 'Enter project title',
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Project title is required';
                            }
                            if (value!.length < 3) {
                              return 'Title must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Description'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _descriptionController,
                          hintText: 'Describe your project',
                          maxLines: 3,
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Description is required';
                            }
                            if (value!.length < 10) {
                              return 'Description must be at least 10 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Category'),
                        const SizedBox(height: 8),
                        _buildDropdown<String>(
                          value: _selectedCategory,
                          hint: 'Select category',
                          items: _categories,
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Semester'),
                        const SizedBox(height: 8),
                        _buildDropdown<int>(
                          value: _selectedSemesterNo,
                          hint: 'Select semester',
                          items: _semesters,
                          onChanged: (value) {
                            setState(() {
                              _selectedSemesterNo = value;
                            });
                          },
                          labelBuilder: (value) => 'Semester $value',
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a semester';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Maximum Members'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: _maxMembers.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Max members',
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _maxMembers =
                                            int.tryParse(value) ?? 5;
                                      });
                                    },
                                    validator: (value) {
                                      final num = int.tryParse(value ?? '');
                                      if (num == null || num < 2 || num > 20) {
                                        return 'Enter 2-20 members';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Deadline'),
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _selectDeadline,
                            borderRadius: BorderRadius.circular(10),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${_deadline.day}/${_deadline.month}/${_deadline.year}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_rounded,
                                    color: Color(0xFF4F9EFF),
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Required Skills'),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _skillsController,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Add skill and press button',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _addSkill,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Ink(
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Color(0xFF4F9EFF),
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_skills.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _skills.asMap().entries.map((entry) {
                              final index = entry.key;
                              final skill = entry.value;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF4F9EFF).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: const Color(0xFF4F9EFF)
                                        .withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      skill,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            _removeSkill(index),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => Navigator.pop(context),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _submitForm,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Ink(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F9EFF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _isEditing
                                            ? 'Save Changes'
                                            : 'Create Project',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 13,
          color: Color(0xFF94A3B8),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color(0xFF4F9EFF),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T value)? labelBuilder,
    String? Function(T?)? validator,
  }) {
    return FormField<T>(
      initialValue: value,
      validator: validator,
      builder: (FormFieldState<T> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: state.hasError
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFFE2E8F0),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButton<T>(
                value: state.value,
                hint: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                isExpanded: true,
                underline: const SizedBox(),
                onChanged: (T? newValue) {
                  state.didChange(newValue);
                  onChanged(newValue);
                },
                items: items.map<DropdownMenuItem<T>>((T item) {
                  final label = labelBuilder?.call(item) ?? item.toString();
                  return DropdownMenuItem<T>(
                    value: item,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(label),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  state.errorText ?? '',
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

