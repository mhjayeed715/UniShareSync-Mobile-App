import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:unisharesync_mobile_app/features/auth/legal_documents_screen.dart';

enum AccountRole { student, faculty }

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const String _logoAsset = 'lib/assets/logos/unisharesync.png';

  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _designationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  AccountRole _role = AccountRole.student;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  bool _isSubmitting = false;

  String? _selectedDepartment;
  String? _selectedSemester;

  final List<String> _departments = const [
    'Computer Science and Engineering (CSE)',
    'Business Administration (BBA)',
    'English (ENG)',
    'Interior Architecture (IA)',
    'Fashion Design and Technology (FDT)',
    'Graphic Design & Multimedia (GDM)'
  ];

  final List<String> _semesters = const [
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
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _studentIdController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isUniversityEmail(String email) {
    final value = email.trim().toLowerCase();
    final pattern = RegExp(
      r'^[a-z]+(?:\.[a-z]+)*(?:\.\d+)?@[a-z][a-z0-9-]*\.ac\.bd$',
    );
    return pattern.hasMatch(value);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept Terms of Service and Privacy Policy.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration UI is ready. Connect backend next.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
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
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.44,
                child: CustomPaint(
                  painter: _SignupDotGridPainter(
                    color: Color(0x334F9EFF),
                    spacing: 24,
                    radius: 1.1,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.2,
            left: -size.width * 0.18,
            child: Container(
              width: size.width * 0.76,
              height: size.width * 0.76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x664F9EFF), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.22,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.84,
              height: size.width * 0.84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x662DD4BF), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.74),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white.withOpacity(0.9)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4F9EFF).withOpacity(0.14),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).maybePop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF466287),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                                label: const Text(
                                  'Back to Home',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.white.withOpacity(0.9)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F9EFF).withOpacity(0.2),
                                        blurRadius: 22,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ShaderMask(
                                    blendMode: BlendMode.srcIn,
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Color(0xFF4F9EFF), Color(0xFF2DD4BF)],
                                    ).createShader(bounds),
                                    child: Image.asset(
                                      _logoAsset,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.image_not_supported_rounded, size: 56),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Center(
                                child: Text(
                                  'Create your account',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Join the UniShareSync community today',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              _RoleSelector(
                                role: _role,
                                onChanged: (newRole) {
                                  setState(() {
                                    _role = newRole;
                                  });
                                },
                              ),
                              const SizedBox(height: 18),
                              _AuthInput(
                                label: 'Full Name',
                                hintText: _role == AccountRole.faculty
                                    ? 'Shad Al Kaiser'
                                    : 'Mehrab Hossain',
                                controller: _fullNameController,
                                prefixIcon: Icons.person_outline_rounded,
                                validator: (value) {
                                  if ((value ?? '').trim().isEmpty) {
                                    return 'Full name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _AuthInput(
                                label: 'Email Address',
                                hintText: _role == AccountRole.faculty
                                    ? 'shadalkaiser000@smuct.ac.bd'
                                    : 'jayeed.223071033@smuct.ac.bd',
                                controller: _emailController,
                                prefixIcon: Icons.mail_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final email = (value ?? '').trim();
                                  if (email.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!_isUniversityEmail(email)) {
                                    return 'Use: studentname(.id optional)@universityname.ac.bd';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              _DropdownField(
                                label: 'Department',
                                value: _selectedDepartment,
                                hint: 'Select Department',
                                items: _departments,
                                icon: Icons.apartment_rounded,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDepartment = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Department is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              if (_role == AccountRole.student) ...[
                                _AuthInput(
                                  label: 'Student ID',
                                  hintText: '223071033',
                                  controller: _studentIdController,
                                  prefixIcon: Icons.badge_outlined,
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Student ID is required for student account';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                _DropdownField(
                                  label: 'Current Semester',
                                  value: _selectedSemester,
                                  hint: 'Select Semester',
                                  items: _semesters,
                                  icon: Icons.calendar_month_outlined,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedSemester = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Semester is required';
                                    }
                                    return null;
                                  },
                                ),
                              ] else ...[
                                _AuthInput(
                                  label: 'Designation',
                                  hintText: 'Lecturer',
                                  controller: _designationController,
                                  prefixIcon: Icons.work_outline_rounded,
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Designation is required for faculty account';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final useColumn = constraints.maxWidth < 460;
                                  if (useColumn) {
                                    return Column(
                                      children: [
                                        _AuthInput(
                                          label: 'Password',
                                          hintText: '••••••••',
                                          controller: _passwordController,
                                          prefixIcon: Icons.lock_outline_rounded,
                                          obscureText: _obscurePassword,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_rounded
                                                  : Icons.visibility_off_rounded,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          validator: (value) {
                                            final v = value ?? '';
                                            if (v.isEmpty) {
                                              return 'Password is required';
                                            }
                                            if (v.length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 14),
                                        _AuthInput(
                                          label: 'Confirm Password',
                                          hintText: '••••••••',
                                          controller: _confirmPasswordController,
                                          prefixIcon: Icons.lock_outline_rounded,
                                          obscureText: _obscureConfirmPassword,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword = !_obscureConfirmPassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_rounded
                                                  : Icons.visibility_off_rounded,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          validator: (value) {
                                            if ((value ?? '').isEmpty) {
                                              return 'Confirm your password';
                                            }
                                            if (value != _passwordController.text) {
                                              return 'Passwords do not match';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: _AuthInput(
                                          label: 'Password',
                                          hintText: '••••••••',
                                          controller: _passwordController,
                                          prefixIcon: Icons.lock_outline_rounded,
                                          obscureText: _obscurePassword,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword = !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_rounded
                                                  : Icons.visibility_off_rounded,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          validator: (value) {
                                            final v = value ?? '';
                                            if (v.isEmpty) {
                                              return 'Password is required';
                                            }
                                            if (v.length < 6) {
                                              return 'Min 6 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _AuthInput(
                                          label: 'Confirm Password',
                                          hintText: '••••••••',
                                          controller: _confirmPasswordController,
                                          prefixIcon: Icons.lock_outline_rounded,
                                          obscureText: _obscureConfirmPassword,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscureConfirmPassword = !_obscureConfirmPassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_rounded
                                                  : Icons.visibility_off_rounded,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          validator: (value) {
                                            if ((value ?? '').isEmpty) {
                                              return 'Confirm required';
                                            }
                                            if (value != _passwordController.text) {
                                              return 'Mismatch';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _acceptedTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _acceptedTerms = value ?? false;
                                      });
                                    },
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Wrap(
                                        children: [
                                          Text(
                                            'I agree to the ',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => const TermsOfServiceScreen(),
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              'Terms of Service',
                                              style: TextStyle(
                                                color: Color(0xFF2B5B94),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            ' and ',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => const PrivacyPolicyScreen(),
                                                ),
                                              );
                                            },
                                            child: const Text(
                                              'Privacy Policy',
                                              style: TextStyle(
                                                color: Color(0xFF2B5B94),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '.',
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _GradientPrimaryButton(
                                onPressed: _isSubmitting ? null : _submit,
                                isLoading: _isSubmitting,
                                label: 'Create Account',
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account?',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).maybePop(),
                                      child: const Text(
                                        'Login',
                                        style: TextStyle(
                                          color: Color(0xFF2B5B94),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
          ),
        ],
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.role, required this.onChanged});

  final AccountRole role;
  final ValueChanged<AccountRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.86)),
      ),
      child: Row(
        children: [
          _RoleButton(
            label: 'Student',
            selected: role == AccountRole.student,
            onTap: () => onChanged(AccountRole.student),
          ),
          const SizedBox(width: 6),
          _RoleButton(
            label: 'Faculty',
            selected: role == AccountRole.faculty,
            onTap: () => onChanged(AccountRole.faculty),
          ),
        ],
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Ink(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF4F9EFF), Color(0xFF2DD4BF)],
                    )
                  : null,
              color: selected ? null : Colors.white.withOpacity(0.4),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF324F73),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthInput extends StatelessWidget {
  const _AuthInput({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.prefixIcon,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData prefixIcon;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: Icon(prefixIcon, color: Colors.grey.shade500),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white.withOpacity(0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF4F9EFF), width: 1.3),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.icon,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final String? value;
  final String hint;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          validator: validator,
          dropdownColor: Colors.white,
          isExpanded: true,
          icon: Icon(Icons.expand_more_rounded, color: Colors.grey.shade600),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.grey.shade500),
            filled: true,
            fillColor: Colors.white.withOpacity(0.72),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF4F9EFF), width: 1.3),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade300),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade400),
            ),
          ),
          hint: Text(
            hint,
            style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
          ),
          style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
          items: items
              .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _GradientPrimaryButton extends StatelessWidget {
  const _GradientPrimaryButton({
    required this.onPressed,
    required this.label,
    required this.isLoading,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: onPressed == null
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade300])
              : const LinearGradient(
                  colors: [Color(0xFF4F9EFF), Color(0xFF2DD4BF)],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F9EFF).withOpacity(0.24),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onPressed,
          child: SizedBox(
            height: 54,
            width: double.infinity,
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
                        fontSize: 17,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignupDotGridPainter extends CustomPainter {
  const _SignupDotGridPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  final Color color;
  final double spacing;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (double y = 0; y <= size.height; y += spacing) {
      for (double x = 0; x <= size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignupDotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}
