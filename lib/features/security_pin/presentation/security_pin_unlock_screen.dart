import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../providers/security_pin_provider.dart';

class SecurityPinUnlockScreen extends ConsumerStatefulWidget {
  const SecurityPinUnlockScreen({super.key});

  @override
  ConsumerState<SecurityPinUnlockScreen> createState() => _SecurityPinUnlockScreenState();
}

class _SecurityPinUnlockScreenState extends ConsumerState<SecurityPinUnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _localError;
  bool _isVerifying = false;
  bool _showBiometricButton = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.info('[SECURITY_PIN] Unlock screen required', tag: 'SECURITY_PIN');
      _checkAndPromptBiometrics();
    });
  }

  Future<void> _checkAndPromptBiometrics() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final isBioEnabled = await storage.isBiometricEnabled();
      if (isBioEnabled) {
        final bioService = BiometricService();
        final capability = await bioService.checkCapability();
        if (capability == BiometricCapability.available) {
          if (mounted) setState(() => _showBiometricButton = true);
          final result = await bioService.authenticate(
            reason: 'Authenticate to unlock A1 Recharge',
          );
          if (result == BiometricAuthResult.success && mounted) {
            ref.read(securityPinProvider.notifier).unlockApp();
            context.go(RouteNames.dashboard);
          }
        }
      }
    } catch (e) {
      AppLogger.warning('Biometric prompt on unlock screen failed: $e', tag: 'SECURITY_PIN');
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePinSubmitted(String pin) async {
    if (pin.length != 6) return;

    setState(() {
      _localError = null;
      _isVerifying = true;
    });

    final success = await ref.read(securityPinProvider.notifier).verifySecurityPin(pin);

    if (!mounted) return;

    if (success) {
      context.go(RouteNames.dashboard);
    } else {
      _pinController.clear();
      setState(() {
        _isVerifying = false;
        _localError = ref.read(securityPinProvider).errorMessage ?? 'Incorrect Security PIN';
      });
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinState = ref.watch(securityPinProvider);
    final errorMessage = _localError ?? pinState.errorMessage;
    final isBusy = _isVerifying || pinState.isLoading;
    final canPopScreen = Navigator.of(context).canPop();

    return PopScope(
      canPop: false, // Prevent back-button bypass of app lock
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. TOP HEADER (Back Arrow + Shield "Security")
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          if (canPopScreen)
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
                              onPressed: isBusy ? null : () => context.pop(),
                              tooltip: 'Back',
                            )
                          else
                            const SizedBox(width: 40),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Security',
                                style: AppTextTheme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 2. A1 RECHARGE BRANDING (Large, Prominent Asset Logo)
                    Image.asset(
                      AssetPaths.appLogo,
                      width: 150,
                      height: 70,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Text(
                          'A1 RECHARGE',
                          style: AppTextTheme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryBlue,
                            letterSpacing: 1.5,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // 3. MAIN CONTENT TITLE & SUBTITLE
                    Text(
                      'Enter Security PIN',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 25,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter your 6-digit Security PIN to continue',
                      textAlign: TextAlign.center,
                      style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. PIN INPUT (6 boxes, 52x54dp)
                    PinEntryWidget(
                      controller: _pinController,
                      focusNode: _focusNode,
                      length: 6,
                      autofocus: true,
                      enabled: !isBusy,
                      errorText: errorMessage,
                      onCompleted: _handlePinSubmitted,
                      onChanged: (val) {
                        if (_localError != null) {
                          setState(() => _localError = null);
                        }
                      },
                    ),

                    const SizedBox(height: 14),

                    // Verification Loading State
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isBusy
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Verifying Security PIN...',
                                    style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    // 5. FORGOT PIN LINK & BIOMETRIC BUTTON
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: isBusy
                              ? null
                              : () {
                                  context.push(RouteNames.forgotSecurityPin);
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            minimumSize: const Size(44, 40),
                          ),
                          child: Text(
                            'Forgot Security PIN?',
                            style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                              color: isBusy ? AppColors.textDisabled : AppColors.primaryBlue,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (_showBiometricButton) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.fingerprint, size: 28, color: AppColors.primaryBlue),
                            onPressed: _checkAndPromptBiometrics,
                            tooltip: 'Unlock with Fingerprint / Face ID',
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 18),

                    // 6. SECURITY INFORMATION CARD
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueLight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primaryBlue.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your Security PIN is private and never shared with anyone.',
                              style: AppTextTheme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 7. SUBTLE FOOTER BRANDING
                    Text(
                      'A1 Recharge',
                      style: AppTextTheme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
