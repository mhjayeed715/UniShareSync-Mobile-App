import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/features/dashboard/role_home_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';

class VerifySignupOtpScreen extends StatefulWidget {
  const VerifySignupOtpScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<VerifySignupOtpScreen> createState() => _VerifySignupOtpScreenState();
}

class _VerifySignupOtpScreenState extends State<VerifySignupOtpScreen> {
  final AuthService _authService = AuthService();

  late final List<TextEditingController> _otpControllers;
  late final List<FocusNode> _otpFocusNodes;

  Timer? _resendTimer;

  bool _isVerifying = false;
  int _resendSecondsLeft = 0;

  @override
  void initState() {
    super.initState();

    _otpControllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
    );
    _otpFocusNodes = List<FocusNode>.generate(6, (_) => FocusNode());

    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();

    for (final controller in _otpControllers) {
      controller.dispose();
    }

    for (final node in _otpFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  String get _otpValue {
    return _otpControllers.map((controller) => controller.text.trim()).join();
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

  Future<void> _verifyOtp() async {
    final otp = _otpValue;

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 6-digit OTP.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
    });

    try {
      final session = await _authService.verifySignupOtp(
        email: widget.email,
        otp: otp,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => RoleHomeScreen(
            initialRole: session.role,
            isLocalAdmin: session.isLocalAdmin,
          ),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OTP verification failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isVerifying || _resendSecondsLeft > 0) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      _clearOtpFields();
      _startResendCountdown();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A fresh OTP has been sent to your email.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resend OTP: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
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
                  painter: _VerifyDotGridPainter(
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
                      _VerifyTopBar(
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _StepHeroIcon(
                                  icon: Icons.mail_lock_outlined,
                                  accentIcon: Icons.verified_user_outlined,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Verify Your Email',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'We sent a 6-digit code to ${widget.email}.',
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
                                    'Use the verification code from your inbox to activate your account securely.',
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
                                  onTap: _isVerifying ? null : _verifyOtp,
                                  isLoading: _isVerifying,
                                  label: 'Verify and Continue',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ResendFooter(
                        secondsLeft: _resendSecondsLeft,
                        onResend: _resendCode,
                      ),
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
}

class _VerifyTopBar extends StatelessWidget {
  const _VerifyTopBar({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const labels = ['Signup', 'Verify'];

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
                  'Verify Signup OTP',
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
            final isActive = true;

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

class _VerifyDotGridPainter extends CustomPainter {
  const _VerifyDotGridPainter({
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
  bool shouldRepaint(covariant _VerifyDotGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}
