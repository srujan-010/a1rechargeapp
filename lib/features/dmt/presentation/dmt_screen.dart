import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import 'dmt_providers.dart';

class DmtScreen extends ConsumerStatefulWidget {
  const DmtScreen({super.key});

  @override
  ConsumerState<DmtScreen> createState() => _DmtScreenState();
}

class _DmtScreenState extends ConsumerState<DmtScreen> {
  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpController = TextEditingController();
  
  bool _isSearching = false;
  bool _isRegistering = false;
  bool _showRegistration = false;
  String? _errorMsg;

  @override
  void dispose() {
    _mobileController.dispose();
    _nameController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _searchRemitter() async {
    final mobile = _mobileController.text.trim();
    if (mobile.length != 10) {
      setState(() => _errorMsg = 'Enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMsg = null;
      _showRegistration = false;
    });

    await ref.read(dmtFlowProvider.notifier).searchRemitter(mobile);
    
    if (!mounted) return;
    
    setState(() => _isSearching = false);
    
    final state = ref.read(dmtFlowProvider);
    if (state.currentRemitter != null) {
      context.push(RouteNames.dmtBeneficiaries);
    } else {
      setState(() {
        _showRegistration = true;
        _errorMsg = 'Remitter not found. Please register.';
      });
    }
  }

  Future<void> _registerRemitter() async {
    final name = _nameController.text.trim();
    final otp = _otpController.text.trim();
    
    if (name.isEmpty || otp.length != 6) {
      setState(() => _errorMsg = 'Please provide valid name and 6-digit OTP');
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMsg = null;
    });

    try {
      await ref.read(dmtFlowProvider.notifier).registerRemitter(name, otp);
      if (!mounted) return;
      
      context.push(RouteNames.dmtBeneficiaries);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Domestic Money Transfer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Remitter Login', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: 'Enter Remitter Mobile Number',
                        prefixIcon: Icon(Icons.phone_android),
                        counterText: '',
                      ),
                      onChanged: (v) {
                        if (_showRegistration) {
                          setState(() => _showRegistration = false);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Verify Remitter',
                      isLoading: _isSearching,
                      onPressed: _mobileController.text.length == 10 ? _searchRemitter : null,
                    ),
                  ],
                ),
              ),
              
              if (_showRegistration) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Register New Remitter', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Full Name as per Bank',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: 'Enter 6-digit OTP',
                          prefixIcon: Icon(Icons.message),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'A verification OTP has been sent to the mobile number. Use 123456 for testing.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Register & Continue',
                        isLoading: _isRegistering,
                        onPressed: _registerRemitter,
                      ),
                    ],
                  ),
                ),
              ],
              
              if (_errorMsg != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
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