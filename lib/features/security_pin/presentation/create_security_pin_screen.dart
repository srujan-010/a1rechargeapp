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

class CreateSecurityPinScreen extends ConsumerStatefulWidget {
  const CreateSecurityPinScreen({super.key});

  @override
  ConsumerState<CreateSecurityPinScreen> createState() => _CreateSecurityPinScreenState();
}

class _CreateSecurityPinScreenState extends ConsumerState<CreateSecurityPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (pin != confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Security PINs do not match. Please re-enter.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await ref.read(securityPinProvider.notifier).createSecurityPin(pin);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Security PIN created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        AppNavigation.pop(context, fallbackRoute: RouteNames.securityPin);
      } else {
        final error = ref.read(securityPinProvider).errorMessage ?? 'Failed to create Security PIN';
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
        title: const Text('Set Up Security PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                const Icon(Icons.security, size: 48, color: AppColors.primaryBlue),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Create 6-Digit Security PIN',
                  textAlign: TextAlign.center,
                  style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your Security PIN protects access to your A1 Recharge account and app settings.',
                  textAlign: TextAlign.center,
                  style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppTextField(
                  label: 'Enter 6-Digit Security PIN',
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter 6-digit PIN';
                    if (v.length != 6 || !RegExp(r'^\d+$').hasMatch(v)) return 'PIN must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  label: 'Confirm 6-Digit Security PIN',
                  controller: _confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm 6-digit PIN';
                    if (v != _pinController.text) return 'PINs do not match';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Save Security PIN',
                  isLoading: pinState.isLoading,
                  onPressed: _handleCreate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
