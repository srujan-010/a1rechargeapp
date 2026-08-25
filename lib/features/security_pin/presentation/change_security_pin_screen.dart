import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../providers/security_pin_provider.dart';

class ChangeSecurityPinScreen extends ConsumerStatefulWidget {
  const ChangeSecurityPinScreen({super.key});

  @override
  ConsumerState<ChangeSecurityPinScreen> createState() => _ChangeSecurityPinScreenState();
}

class _ChangeSecurityPinScreenState extends ConsumerState<ChangeSecurityPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleChange() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPin = _currentPinController.text.trim();
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (newPin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New Security PINs do not match. Please re-enter.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await ref.read(securityPinProvider.notifier).changeSecurityPin(currentPin, newPin);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security PIN changed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        AppNavigation.pop(context, fallbackRoute: RouteNames.securityPin);
      } else {
        final error = ref.read(securityPinProvider).errorMessage ?? 'Failed to change Security PIN';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
          ),
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
        title: const Text('Change Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, size: 48, color: AppColors.primaryBlue),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Change Your Security PIN',
                  textAlign: TextAlign.center,
                  style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Update your 6-digit Security PIN used to protect your app access.',
                  textAlign: TextAlign.center,
                  style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'Current Security PIN',
                  controller: _currentPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter current PIN';
                    if (v.length != 6) return 'PIN must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'New 6-Digit Security PIN',
                  controller: _newPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new PIN';
                    if (v.length != 6 || !RegExp(r'^\d+$').hasMatch(v)) return 'PIN must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Confirm New Security PIN',
                  controller: _confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm new PIN';
                    if (v != _newPinController.text) return 'PINs do not match';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Update Security PIN',
                  isLoading: pinState.isLoading,
                  onPressed: _handleChange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
