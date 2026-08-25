import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/constants/route_names.dart';
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

class _SecurityPinUnlockScreenState extends ConsumerState<SecurityPinUnlockScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _localError;
  bool _isVerifying = false;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.info('[SECURITY_PIN] Unlock screen required', tag: 'SECURITY_PIN');
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SafeArea(
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (canPopScreen)
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
                      onPressed: isBusy ? null : () => context.pop(),
                      tooltip: 'Back',
                    )
                  else
                    const SizedBox(width: 44),
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppColors.primaryBlue.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Security',
                        style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 16,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),

                        // A1 Recharge Brand Logo
                        Image.asset(
                          AssetPaths.appLogo,
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              'A1 RECHARGE',
                              style: AppTextTheme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                                letterSpacing: 1.2,
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // Premium Security Vault Illustration
                        _SecurityVaultIllustration(animation: _floatController),

                        const SizedBox(height: 16),

                        // Main Title & Subtitle
                        Text(
                          'Enter Security PIN',
                          textAlign: TextAlign.center,
                          style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
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

                        // 6-digit PIN Input Fields
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

                        const SizedBox(height: 16),

                        // Verification State / Loading Indicator
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: isBusy
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
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
                                      const SizedBox(width: 10),
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

                        // Forgot Security PIN Tappable Link
                        TextButton(
                          onPressed: isBusy
                              ? null
                              : () {
                                  context.push(RouteNames.forgotSecurityPin);
                                },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: const Size(44, 44),
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

                        const Spacer(),
                        const SizedBox(height: 12),

                        // Security Information Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueLight.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primaryBlue.withValues(alpha: 0.15),
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

                        const SizedBox(height: 12),

                        // Subtle Bottom Branding
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'A1 Recharge',
                              style: AppTextTheme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              ' • Bank-Grade 256-bit Security',
                              style: AppTextTheme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Digital Safe Vault Security Illustration (Inspired by Third Layout in reference)
class _SecurityVaultIllustration extends StatelessWidget {
  const _SecurityVaultIllustration({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final floatOffset = Offset(0, 3 * (0.5 - (animation.value - 0.5).abs()));
        return Transform.translate(
          offset: floatOffset,
          child: child,
        );
      },
      child: SizedBox(
        width: 270,
        height: 108,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft Background Cloud/Ellipse Backdrop
            Positioned(
              top: 8,
              child: Container(
                width: 230,
                height: 86,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F6FF),
                  borderRadius: BorderRadius.all(Radius.elliptical(230, 86)),
                ),
              ),
            ),

            // Left Potted Plant Vector Accent
            Positioned(
              left: 24,
              bottom: 12,
              child: _buildPottedPlant(),
            ),

            // Right Potted Plant Vector Accent
            Positioned(
              right: 24,
              bottom: 12,
              child: _buildPottedPlant(),
            ),

            // Central Vault / Digital Safe Body
            Container(
              width: 144,
              height: 86,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A), // Dark blue vault side
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Safe Front Door Panel
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 2),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Dial Ring
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1E293B),
                            border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                          ),
                          child: Center(
                            // Inner Dial Wheel
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF0F172A),
                                border: Border.all(color: const Color(0xFF94A3B8), width: 1.5),
                              ),
                              child: Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Safe Door Hinges / Hardware
                        Positioned(
                          left: 6,
                          top: 12,
                          child: Container(
                            width: 4,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          bottom: 12,
                          child: Container(
                            width: 4,
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFF64748B),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Shield Badge on Right Door Edge
                  Positioned(
                    right: 0,
                    top: 24,
                    child: Container(
                      width: 28,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPottedPlant() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Leaves
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: 8,
              height: 18,
              decoration: const BoxDecoration(
                color: Color(0xFF059669),
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: 8,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFF34D399),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Pot
        Container(
          width: 14,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFFCBD5E1),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
          ),
        ),
      ],
    );
  }
}
