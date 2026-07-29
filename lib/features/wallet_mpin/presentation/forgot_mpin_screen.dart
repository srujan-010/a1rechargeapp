import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../providers/wallet_mpin_provider.dart';

class ForgotMpinScreen extends ConsumerStatefulWidget {
  const ForgotMpinScreen({super.key});

  @override
  ConsumerState<ForgotMpinScreen> createState() => _ForgotMpinScreenState();
}

class _ForgotMpinScreenState extends ConsumerState<ForgotMpinScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isPhoneValid = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String val) {
    final isValid = val.length == 10;
    if (_isPhoneValid != isValid) {
      setState(() => _isPhoneValid = isValid);
      if (isValid) HapticFeedback.lightImpact();
    }
  }

  Future<void> _sendOtp() async {
    if (_isPhoneValid) {
      HapticFeedback.mediumImpact();
      final success = await ref.read(walletMpinProvider.notifier).sendForgotOtp();
      if (success && mounted) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your WhatsApp number.'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _verifyOtp(String otp) async {
    if (otp.length == 6) {
      HapticFeedback.mediumImpact();
      final success = await ref.read(walletMpinProvider.notifier).verifyForgotOtp(otp: otp);
      if (success && mounted) {
        context.pushNamed(RouteNames.resetMpin);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletMpinProvider);

    final defaultPinTheme = PinTheme(
      width: 48,
      height: 56,
      textStyle: const TextStyle(fontSize: 22, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primaryBlue, width: 2),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot MPIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Wallet MPIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _otpSent
                    ? 'Enter the 6-digit OTP code sent to your registered WhatsApp mobile number.'
                    : 'Enter your registered mobile number to receive an OTP code on WhatsApp.',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              if (!_otpSent) ...[
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  onChanged: _onPhoneChanged,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    prefixText: '+91 ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    state.error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isPhoneValid && !state.isLoading ? _sendOtp : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: state.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Send OTP via WhatsApp',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ] else ...[
                Center(
                  child: Pinput(
                    controller: _otpController,
                    length: 6,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: focusedPinTheme,
                    onCompleted: _verifyOtp,
                    enabled: !state.isLoading,
                    keyboardType: TextInputType.number,
                  ),
                ),
                if (state.error != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _otpController.text.length == 6 && !state.isLoading
                        ? () => _verifyOtp(_otpController.text)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: state.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Verify OTP',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: state.isLoading ? null : _sendOtp,
                    child: const Text('Resend OTP', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
