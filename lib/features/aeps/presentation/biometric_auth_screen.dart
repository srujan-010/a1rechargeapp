import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import 'aeps_providers.dart';

class BiometricAuthScreen extends ConsumerStatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  ConsumerState<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends ConsumerState<BiometricAuthScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _statusMessage = 'Place your finger on the scanner...';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _simulateScan() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning...';
    });

    // Simulate 2 seconds of scan
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _statusMessage = 'Authenticating with UIDAI...';
    });

    try {
      final result = await ref.read(aepsFlowProvider.notifier).processTransaction();
      if (!mounted) return;
      
      setState(() {
        _statusMessage = 'Success!';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      
      context.go(RouteNames.dashboard);
      context.push(RouteNames.aepsReceipt, extra: result);
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _statusMessage = 'Failed: ${e.toString().replaceAll('Exception: ', '')}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Biometric Authentication')),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _simulateScan,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlueLight.withValues(alpha: 0.3),
                      ),
                    ),
                    if (_isProcessing)
                      FadeTransition(
                        opacity: _controller,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryBlue.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    Icon(
                      Icons.fingerprint,
                      size: 80,
                      color: _isProcessing ? AppColors.primaryBlue : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                _statusMessage,
                style: AppTextTheme.textTheme.titleMedium?.copyWith(
                  color: _statusMessage.startsWith('Failed') ? AppColors.error : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!_isProcessing)
                const Text('Tap the fingerprint icon to simulate scan', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
