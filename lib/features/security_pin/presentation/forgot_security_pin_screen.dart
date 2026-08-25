import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/security_pin_provider.dart';

class ForgotSecurityPinScreen extends ConsumerStatefulWidget {
  const ForgotSecurityPinScreen({super.key});

  @override
  ConsumerState<ForgotSecurityPinScreen> createState() => _ForgotSecurityPinScreenState();
}

class _ForgotSecurityPinScreenState extends ConsumerState<ForgotSecurityPinScreen> {
  final _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final success = await ref.read(securityPinProvider.notifier).sendForgotOtp();
    if (mounted) {
      if (success) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent to your registered mobile number.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final error = ref.read(securityPinProvider).errorMessage ?? 'Failed to send OTP';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 6-digit OTP'), backgroundColor: AppColors.error),
      );
      return;
    }

    final success = await ref.read(securityPinProvider.notifier).verifyForgotOtp(otp);
    if (mounted) {
      if (success) {
        context.push(RouteNames.resetSecurityPin);
      } else {
        final error = ref.read(securityPinProvider).errorMessage ?? 'OTP verification failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinState = ref.watch(securityPinProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Forgot Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigation.pop(context, fallbackRoute: RouteNames.securityPin),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.phonelink_lock, size: 48, color: AppColors.primaryBlue),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Reset Security PIN',
                textAlign: TextAlign.center,
                style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _otpSent
                    ? 'Enter the 6-digit OTP sent to your registered mobile number.'
                    : 'We will send a 6-digit OTP to your registered mobile number to reset your Security PIN.',
                textAlign: TextAlign.center,
                style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (!_otpSent) ...[
                AppButton(
                  label: 'Send OTP to Registered Mobile',
                  isLoading: pinState.isLoading,
                  onPressed: _handleSendOtp,
                ),
              ] else ...[
                AppTextField(
                  label: 'Enter 6-Digit OTP',
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Verify OTP',
                  isLoading: pinState.isLoading,
                  onPressed: _handleVerifyOtp,
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: pinState.isLoading ? null : _handleSendOtp,
                  child: const Text('Resend OTP', style: TextStyle(color: AppColors.primaryBlue)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
