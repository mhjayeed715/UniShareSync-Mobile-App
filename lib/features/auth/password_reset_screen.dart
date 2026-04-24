import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

enum _ResetStep {
  request,
  verify,
  update,
  done,
}

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({
    super.key,
    this.prefilledEmail,
  });

  final String? prefilledEmail;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final AuthService _authService = AuthService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  StreamSubscription<AuthState>? _authStateSubscription;
  Timer? _resendTimer;

  _ResetStep _step = _ResetStep.request;
  bool _isSubmitting = false;
  bool _deepLinkVerified = false;
  int _resendSecondsLeft = 0;
  _PasswordCriteria _passwordCriteria = const _PasswordCriteria();

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.prefilledEmail?.trim() ?? '';

    _otpControllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    _otpFocusNodes = List<FocusNode>.generate(6, (_) => FocusNode());

    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthStateChanged);
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _resendTimer?.cancel();

    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    for (final controller in _otpControllers) {
      controller.dispose();
    }
    for (final node in _otpFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  void _onAuthStateChanged(AuthState authState) {
    if (!mounted) {
      return;
    }

    if (authState.event == AuthChangeEvent.passwordRecovery) {
      setState(() {
        _deepLinkVerified = true;
        _step = _ResetStep.update;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery link verified. Set your new password now.'),
        ),
      );
    }
  }

  bool _isLikelyEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  String get _otpValue {
    return _otpControllers.map((controller) => controller.text.trim()).join();
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }

    final criteria = _evaluatePassword(password);

    if (!criteria.hasMinimumLength) {
      return 'Password must be at least 6 characters';
    }
    if (!criteria.hasLowercase) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!criteria.hasUppercase) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!criteria.hasDigit) {
      return 'Password must contain at least one digit';
    }
    if (!criteria.hasSymbol) {
      return 'Password must contain at least one symbol';
    }

    return null;
  }

  _PasswordCriteria _evaluatePassword(String password) {
    return _PasswordCriteria(
      hasMinimumLength: password.length >= 6,
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasDigit: RegExp(r'[0-9]').hasMatch(password),
      hasSymbol: RegExp(r'[^A-Za-z0-9]').hasMatch(password),
    );
  }

  void _updatePasswordStrength(String value) {
    setState(() {
      _passwordCriteria = _evaluatePassword(value);
    });
  }

  void _clearOtpFields() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
  }

  void _fillOtpFromPasted(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    for (int i = 0; i < _otpControllers.length; i++) {
      _otpControllers[i].text = i < digits.length ? digits[i] : '';
    }

    final firstEmptyIndex = _otpControllers.indexWhere((controller) => controller.text.isEmpty);
    final focusIndex = firstEmptyIndex == -1 ? _otpControllers.length - 1 : firstEmptyIndex;
    _otpFocusNodes[focusIndex].requestFocus();

    // Auto proceed if all digits are filled
    if (_otpValue.length == 6) {
      _verifyOtp();
    }
  }

  void _onOtpDigitChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 1) {
      _fillOtpFromPasted(digits);
      return;
    }

    if (digits.isNotEmpty && index < _otpFocusNodes.length - 1) {
      _otpFocusNodes[index + 1].requestFocus();
    }

    // Auto proceed if all digits are filled
    if (_otpValue.length == 6) {
      _verifyOtp();
    }
  }

  void _startResendCountdown([int startSeconds = 60]) {
    _resendTimer?.cancel();

    setState(() {
      _resendSecondsLeft = startSeconds;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSecondsLeft <= 1) {
        timer.cancel();
        setState(() {
          _resendSecondsLeft = 0;
        });
        return;
      }

      setState(() {
        _resendSecondsLeft -= 1;
      });
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      throw StateError('Please enter your email address first.');
    }

    if (!_isLikelyEmail(email)) {
      throw StateError('Please enter a valid email address.');
    }

    await _authService.sendPasswordResetOtp(email);

    _clearOtpFields();
    _startResendCountdown();

    if (!mounted) {
      return;
    }

    setState(() {
      _deepLinkVerified = false;
      _step = _ResetStep.verify;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Verification email sent. Enter the 6-digit OTP. If you only receive a link, update Supabase Recovery template to include Token.',
        ),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    final otp = _otpValue;

    if (email.isEmpty) {
      throw StateError('Email is missing. Go back to step 1.');
    }

    if (otp.length != 6) {
      throw StateError('Please enter the full 6-digit OTP.');
    }

    await _authService.verifyPasswordResetOtp(email: email, otp: otp);

    if (!mounted) {
      return;
    }

    setState(() {
      _step = _ResetStep.update;
    });
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final password = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      throw StateError('Passwords do not match.');
    }

    await _authService.updatePassword(password);

    if (!mounted) {
      return;
    }

    setState(() {
      _step = _ResetStep.done;
    });
  }

  Future<void> _runStepAction() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      switch (_step) {
        case _ResetStep.request:
          await _sendOtp();
          break;
        case _ResetStep.verify:
          await _verifyOtp();
          break;
        case _ResetStep.update:
          await _setNewPassword();
          break;
        case _ResetStep.done:
          if (mounted) {
            Navigator.of(context).maybePop();
          }
          break;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_isSubmitting || _resendSecondsLeft > 0) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _authService.resendPasswordResetOtp(email);
      _clearOtpFields();
      _startResendCountdown();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A fresh OTP has been sent to your email.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not resend OTP: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _actionLabel() {
    switch (_step) {
      case _ResetStep.request:
        return 'Send Reset Code';
      case _ResetStep.verify:
        return 'Verify Code';
      case _ResetStep.update:
        return 'Update Password';
      case _ResetStep.done:
        return 'Back to Login';
    }
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
                opacity: 0.36,
                child: CustomPaint(
                  painter: _ResetDotGridPainter(
                    color: Color(0x334F9EFF),
                    spacing: 22,
                    radius: 1.15,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -size.height * 0.16,
            left: -size.width * 0.14,
            child: Container(
              width: size.width * 0.74,
              height: size.width * 0.74,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x664F9EFF), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.18,
            right: -size.width * 0.18,
            child: Container(
              width: size.width * 0.86,
              height: size.width * 0.86,
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
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _ResetTopBar(
                        step: _step,
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.66),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: Colors.white.withOpacity(0.9)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F9EFF).withOpacity(0.16),
                                  blurRadius: 30,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 280),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: _buildStepContent(),
                            ),
                          ),
                        ),
                      ),
                      if (_step == _ResetStep.verify) ...[
                        const SizedBox(height: 16),
                        _ResendFooter(
                          secondsLeft: _resendSecondsLeft,
                          onResend: _resendOtp,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _ResetStep.request:
        return _buildRequestStep();
      case _ResetStep.verify:
        return _buildVerifyStep();
      case _ResetStep.update:
        return _buildUpdateStep();
      case _ResetStep.done:
        return _buildDoneStep();
    }
  }

  Widget _buildRequestStep() {
    return Column(
      key: const ValueKey<String>('request-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeroIcon(
          icon: Icons.lock_outline_rounded,
          accentIcon: Icons.mail_outline_rounded,
        ),
        const SizedBox(height: 12),
        const Text(
          'Forgot Password?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter your university email and we will send a 6-digit verification code.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        _GlassInput(
          controller: _emailController,
          hintText: 'yourname@university.edu',
          prefixIcon: Icons.alternate_email_rounded,
          keyboardType: TextInputType.emailAddress,
          enabled: true,
        ),
        const SizedBox(height: 18),
        _GradientButton(
          onTap: _isSubmitting ? null : _runStepAction,
          isLoading: _isSubmitting,
          label: _actionLabel(),
        ),
      ],
    );
  }

  Widget _buildVerifyStep() {
    return Column(
      key: const ValueKey<String>('verify-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeroIcon(
          icon: Icons.mail_lock_outlined,
          accentIcon: Icons.verified_user_outlined,
        ),
        const SizedBox(height: 12),
        const Text(
          'Check Your Email',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to ${_emailController.text.trim()}.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF4F9EFF).withOpacity(0.09),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4F9EFF).withOpacity(0.2)),
          ),
          child: Text(
            'If email shows only a recovery link, set Supabase Recovery template to use Token and keep link as fallback.',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List<Widget>.generate(
            6,
            (index) => _OtpDigitField(
              controller: _otpControllers[index],
              focusNode: _otpFocusNodes[index],
              onChanged: (value) => _onOtpDigitChanged(index, value),
              onBackspaceAtEmpty: () {
                if (index > 0) {
                  _otpFocusNodes[index - 1].requestFocus();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        _GradientButton(
          onTap: _isSubmitting ? null : _runStepAction,
          isLoading: _isSubmitting,
          label: _actionLabel(),
        ),
      ],
    );
  }

  Widget _buildUpdateStep() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey<String>('update-step'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _StepHeroIcon(
            icon: Icons.lock_reset_rounded,
            accentIcon: Icons.shield_outlined,
          ),
          const SizedBox(height: 12),
          const Text(
            'Set New Password',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _deepLinkVerified
                ? 'Your recovery link has been verified. Set your new password below.'
                : 'Code verified. Set your new password below.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _newPasswordController,
            obscureText: true,
            validator: _validatePassword,
            onChanged: _updatePasswordStrength,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'New password',
              hintStyle: const TextStyle(color: Color(0xFF9AA9BE)),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF8090A6)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.62),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.15)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: Color(0xFF4F9EFF), width: 1.2),
              ),
            ),
          ),
          if (_newPasswordController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _PasswordStrengthIndicator(criteria: _passwordCriteria),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Confirm new password',
              hintStyle: const TextStyle(color: Color(0xFF9AA9BE)),
              prefixIcon: const Icon(Icons.lock_person_outlined, color: Color(0xFF8090A6)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.62),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.15)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: Color(0xFF4F9EFF), width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _GradientButton(
            onTap: _isSubmitting ? null : _runStepAction,
            isLoading: _isSubmitting,
            label: _actionLabel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    return Column(
      key: const ValueKey<String>('done-step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StepHeroIcon(
          icon: Icons.check_circle_outline_rounded,
          accentIcon: Icons.verified_rounded,
        ),
        const SizedBox(height: 12),
        const Text(
          'Password Updated',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your password has been reset successfully. Sign in with your new password.',
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        _GradientButton(
          onTap: _isSubmitting ? null : _runStepAction,
          isLoading: _isSubmitting,
          label: _actionLabel(),
        ),
      ],
    );
  }
}

class _ResetTopBar extends StatelessWidget {
  const _ResetTopBar({
    required this.step,
    required this.onBack,
  });

  final _ResetStep step;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final activeIndex = switch (step) {
      _ResetStep.request => 0,
      _ResetStep.verify => 1,
      _ResetStep.update => 2,
      _ResetStep.done => 2,
    };

    const labels = ['Email', 'Verify', 'Reset'];

    return Column(
      children: [
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onBack,
                child: Ink(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.95)),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1F2937)),
                ),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: List<Widget>.generate(labels.length, (index) {
            final isActive = index <= activeIndex;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
                child: Column(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(100),
                        gradient: isActive
                            ? const LinearGradient(
                                colors: [Color(0xFF4F9EFF), Color(0xFF2DD4BF)],
                              )
                            : null,
                        color: isActive ? null : const Color(0xFFD7E2F0),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: isActive ? const Color(0xFF2B5B94) : const Color(0xFF8A99AE),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ResendFooter extends StatelessWidget {
  const _ResendFooter({
    required this.secondsLeft,
    required this.onResend,
  });

  final int secondsLeft;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final canResend = secondsLeft == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.58),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.92)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Did not receive it?',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          if (canResend)
            GestureDetector(
              onTap: onResend,
              child: const Text(
                'Resend OTP',
                style: TextStyle(
                  color: Color(0xFF2B5B94),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else
            Text(
              'Resend in 00:${secondsLeft.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: Color(0xFF2B5B94),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _StepHeroIcon extends StatelessWidget {
  const _StepHeroIcon({
    required this.icon,
    required this.accentIcon,
  });

  final IconData icon;
  final IconData accentIcon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4F9EFF).withOpacity(0.2),
                  const Color(0xFF2DD4BF).withOpacity(0.2),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.9)),
            ),
            child: Icon(icon, size: 42, color: const Color(0xFF2B5B94)),
          ),
          Positioned(
            bottom: -6,
            right: -8,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F9EFF).withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(accentIcon, size: 20, color: const Color(0xFF4F9EFF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassInput extends StatelessWidget {
  const _GlassInput({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    required this.enabled,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: false,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF9AA9BE)),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF8090A6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.62),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.15)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: Color(0xFF4F9EFF), width: 1.2),
        ),
      ),
    );
  }
}

class _OtpDigitField extends StatelessWidget {
  const _OtpDigitField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspaceAtEmpty,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspaceAtEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspaceAtEmpty();
            return KeyEventResult.handled;
          }

          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 1,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white.withOpacity(0.72),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: const Color(0xFF4F9EFF).withOpacity(0.4)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: Color(0xFF4F9EFF), width: 1.4),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
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
          borderRadius: BorderRadius.circular(16),
          gradient: onTap == null
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade300])
              : const LinearGradient(
                  colors: [Color(0xFF4F9EFF), Color(0xFF2DD4BF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F9EFF).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
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

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({
    required this.criteria,
  });

  final _PasswordCriteria criteria;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('At least 6 characters', criteria.hasMinimumLength),
      ('Lowercase letter', criteria.hasLowercase),
      ('Uppercase letter', criteria.hasUppercase),
      ('Number', criteria.hasDigit),
      ('Special character', criteria.hasSymbol),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F9EFF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Password Requirements',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Text(
                '${criteria.score}/5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF2B5B94).withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: criteria.score / 5,
            minHeight: 6,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              criteria.score < 2
                  ? Colors.red
                  : criteria.score < 4
                      ? Colors.orange
                      : Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: items.map((item) {
              final label = item.$1;
              final isMet = item.$2;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMet ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 14,
                    color: isMet ? Colors.green : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMet ? Colors.green.shade700 : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _PasswordCriteria {
  const _PasswordCriteria({
    this.hasMinimumLength = false,
    this.hasLowercase = false,
    this.hasUppercase = false,
    this.hasDigit = false,
    this.hasSymbol = false,
  });

  final bool hasMinimumLength;
  final bool hasLowercase;
  final bool hasUppercase;
  final bool hasDigit;
  final bool hasSymbol;

  int get score => [
        hasMinimumLength,
        hasLowercase,
        hasUppercase,
        hasDigit,
        hasSymbol,
      ].where((item) => item).length;
}

class _ResetDotGridPainter extends CustomPainter {
  const _ResetDotGridPainter({
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
  bool shouldRepaint(covariant _ResetDotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}
