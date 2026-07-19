import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// We'll just use an icon if lottie isn't available, but we can simulate success.
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import 'change_mpin_provider.dart';

class ChangeMpinScreen extends ConsumerStatefulWidget {
  const ChangeMpinScreen({super.key});

  @override
  ConsumerState<ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

class _ChangeMpinScreenState extends ConsumerState<ChangeMpinScreen> {
  final PageController _pageController = PageController();
  final _newMpinController = TextEditingController();
  final _confirmMpinController = TextEditingController();

  String? _newMpinError;

  @override
  void dispose() {
    _pageController.dispose();
    _newMpinController.dispose();
    _confirmMpinController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _handleMpinSubmit() {
    final newMpin = _newMpinController.text;
    final confirm = _confirmMpinController.text;

    if (newMpin.length != AppConfig.pinLength) {
      setState(() => _newMpinError = 'Enter a ${AppConfig.pinLength}-digit MPIN');
      return;
    }
    if (RegExp(r'^(\d)\1+$').hasMatch(newMpin)) {
      setState(() => _newMpinError = 'MPIN cannot contain repeating digits');
      return;
    }
    const sequentialAsc = '0123456789';
    const sequentialDesc = '9876543210';
    if (sequentialAsc.contains(newMpin) || sequentialDesc.contains(newMpin)) {
      setState(() => _newMpinError = 'MPIN cannot be sequential');
      return;
    }
    if (newMpin != confirm) {
      setState(() => _newMpinError = 'MPINs do not match');
      return;
    }

    setState(() => _newMpinError = null);
    ref.read(changeMpinProvider.notifier).updateMpin(newMpin);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changeMpinProvider);
    final sessionAsync = ref.watch(sessionProvider);
    final user = sessionAsync.valueOrNull;

    ref.listen<ChangeMpinStateModel>(changeMpinProvider, (previous, next) {
      if (next.status == ChangeMpinState.error && next.errorMsg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMsg!), backgroundColor: AppColors.error),
        );
      } else if (next.status == ChangeMpinState.otpSent) {
        if (_pageController.page == 0) _nextPage();
      } else if (next.status == ChangeMpinState.otpVerified) {
        if (_pageController.page == 1) _nextPage();
      } else if (next.status == ChangeMpinState.success) {
        if (_pageController.page == 2) _nextPage();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Change MPIN'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextTheme.textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSendOtpStep(user, state),
            _buildVerifyOtpStep(state),
            _buildNewMpinStep(state),
            _buildSuccessStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendOtpStep(SessionUser? user, ChangeMpinStateModel state) {
    final isLoading = state.status == ChangeMpinState.sendingOtp;
    final phone = user?.phone ?? '';
    final maskedPhone = phone.length >= 10 ? '+91 XXXXXXX${phone.substring(phone.length - 3)}' : phone;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          const Icon(Icons.security, size: 64, color: AppColors.primaryBlue),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Secure MPIN Update',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'To protect your account, we will verify your registered mobile number.',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  'Registered Mobile',
                  style: AppTextTheme.textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  maskedPhone,
                  style: AppTextTheme.textTheme.titleLarge?.copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: isLoading || phone.isEmpty ? null : () {
              ref.read(changeMpinProvider.notifier).sendOtp(phone);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppColors.primaryBlue,
            ),
            child: isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyOtpStep(ChangeMpinStateModel state) {
    final isLoading = state.status == ChangeMpinState.verifyingOtp;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            'Verify OTP',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the 6-digit OTP sent to your registered mobile number.',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          PinEntryWidget(
            length: 6,
            autofocus: true,
            onCompleted: (code) {
              ref.read(changeMpinProvider.notifier).verifyOtp(code);
            },
          ),
          const SizedBox(height: 32),
          if (isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildNewMpinStep(ChangeMpinStateModel state) {
    final isLoading = state.status == ChangeMpinState.updatingMpin;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Create New MPIN',
              textAlign: TextAlign.center,
              style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Set a secure 6-digit MPIN for your transactions.',
              textAlign: TextAlign.center,
              style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            const Text(
              'New MPIN',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            PinEntryWidget(
              controller: _newMpinController,
              length: AppConfig.pinLength,
              errorText: _newMpinError,
              onCompleted: (_) {},
            ),
            const SizedBox(height: 32),
            const Text(
              'Confirm New MPIN',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            PinEntryWidget(
              controller: _confirmMpinController,
              length: AppConfig.pinLength,
              onCompleted: (_) {},
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: isLoading ? null : _handleMpinSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: AppColors.primaryBlue,
              ),
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save MPIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppColors.successLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 80, color: AppColors.success),
          ),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            'MPIN Updated Successfully',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your transaction PIN has been updated successfully and is ready to use.',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () {
              ref.read(changeMpinProvider.notifier).reset();
              context.pop();
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppColors.primaryBlue,
            ),
            child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}