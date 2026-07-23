import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../providers/msg91_auth_provider.dart';

class Msg91OtpScreen extends ConsumerStatefulWidget {
  final String phone;

  const Msg91OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<Msg91OtpScreen> createState() => _Msg91OtpScreenState();
}

class _Msg91OtpScreenState extends ConsumerState<Msg91OtpScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  bool _hasError = false;
  int _secondsRemaining = 30;
  Timer? _timer;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startTimer() {
    _secondsRemaining = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _verifyOtp(String otp) {
    if (otp.length >= 4) { // MSG91 token / OTP input
      setState(() => _hasError = false);
      HapticFeedback.mediumImpact();
      _focusNode.unfocus();
      ref.read(msg91AuthProvider.notifier).verifyAccessToken(otp);
    }
  }

  void _triggerErrorAnimation() {
    setState(() => _hasError = true);
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);
    _otpController.clear();
    _focusNode.requestFocus();
  }

  String _maskPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length >= 10) {
      final last10 = cleaned.substring(cleaned.length - 10);
      final first5 = last10.substring(0, 5);
      return '+91 ${first5}XXXXX';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(msg91AuthProvider);
    final isLoading = authState.isLoading;

    ref.listen(msg91AuthProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        _triggerErrorAnimation();
      } else if (next.isVerified && !(previous?.isVerified ?? false)) {
        HapticFeedback.lightImpact();
        context.go(RouteNames.dashboard);
      }
    });

    final defaultPinTheme = PinTheme(
      width: 52,
      height: 60,
      textStyle: const TextStyle(fontSize: 24, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFF2563EB), width: 2),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: const Color(0xFFEF4444), width: 2),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: Column(
                  children: [
                    const Spacer(flex: 1),
                    
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (0.2 * value),
                          child: Opacity(
                            opacity: value,
                            child: Container(
                              width: 80,
                              height: 80,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: Image.network(
                                  'https://res.cloudinary.com/dixbhnqnf/image/upload/v1783948537/ChatGPT_Image_Jul_13_2026_06_44_20_PM-Photoroom_crnosm.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.security, size: 40, color: Color(0xFF2563EB)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    const Text(
                      'Verify Your Phone',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Enter the verification code sent to your mobile number via MSG91.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '📱 ${_maskPhone(widget.phone)}',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(width: 12),
                          Container(width: 1, height: 16, color: const Color(0xFFCBD5E1)),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.pop();
                            },
                            child: const Text(
                              'Change Number',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final shake = 4.0 * math.sin(_shakeController.value * 4 * math.pi);
                        return Transform.translate(offset: Offset(shake, 0), child: child);
                      },
                      child: Pinput(
                        controller: _otpController,
                        focusNode: _focusNode,
                        length: 6, // Wait, some providers use 4 or 6. We'll set to 6. MSG91 standard is 4 or 6. We'll leave 6 to match Firebase UI initially. The user will input and submit.
                        defaultPinTheme: _hasError ? errorPinTheme : defaultPinTheme,
                        focusedPinTheme: _hasError ? errorPinTheme : focusedPinTheme,
                        submittedPinTheme: _hasError ? errorPinTheme : defaultPinTheme,
                        errorPinTheme: errorPinTheme,
                        onChanged: (val) {
                          if (_hasError) setState(() => _hasError = false);
                          HapticFeedback.lightImpact();
                          setState(() {}); 
                        },
                        onCompleted: _verifyOtp,
                        enabled: !isLoading,
                        keyboardType: TextInputType.number,
                        animationCurve: Curves.easeOutCubic,
                        animationDuration: const Duration(milliseconds: 200),
                        pinAnimationType: PinAnimationType.scale,
                        autofillHints: const [AutofillHints.oneTimeCode],
                      ),
                    ),
                    
                    if (_hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          (authState.error != null && authState.error!.contains('expire')) 
                            ? 'Code expired. Request a new OTP.' 
                            : (authState.error ?? 'Incorrect verification code. Please try again.'),
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    
                    const SizedBox(height: 32),
                    
                    Container(
                      height: 52,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: _otpController.text.length >= 4 && !isLoading 
                            ? const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)])
                            : null,
                        color: _otpController.text.length < 4 || isLoading ? const Color(0xFFE2E8F0) : null,
                        boxShadow: _otpController.text.length >= 4 && !isLoading ? [
                          BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
                        ] : [],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _otpController.text.length >= 4 && !isLoading 
                              ? () => _verifyOtp(_otpController.text) 
                              : null,
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0))
                                : Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _otpController.text.length >= 4 ? Colors.white : const Color(0xFF94A3B8))),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    _secondsRemaining > 0
                        ? Text.rich(
                            TextSpan(
                              text: 'Didn\'t receive the code? ',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
                              children: [
                                TextSpan(
                                  text: 'Resend in 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          )
                        : InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _otpController.clear();
                              _startTimer();
                              ref.read(msg91AuthProvider.notifier).sendOtp(widget.phone);
                            },
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          
                    const Spacer(flex: 2),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.lock, size: 12, color: Color(0xFF64748B)),
                        SizedBox(width: 6),
                        Text(
                          'OTP secured login • Bank-grade encryption',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    InkWell(
                      onTap: () => context.push(RouteNames.support),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('Need Help? ', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                          Text('Contact Support →', style: TextStyle(fontSize: 14, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
