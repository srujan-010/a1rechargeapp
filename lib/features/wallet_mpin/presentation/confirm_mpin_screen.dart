import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/wallet_mpin_provider.dart';

class ConfirmMpinScreen extends ConsumerStatefulWidget {
  final String originalMpin;

  const ConfirmMpinScreen({
    super.key,
    required this.originalMpin,
  });

  @override
  ConsumerState<ConfirmMpinScreen> createState() => _ConfirmMpinScreenState();
}

class _ConfirmMpinScreenState extends ConsumerState<ConfirmMpinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCompleted(String pin) async {
    if (pin != widget.originalMpin) {
      setState(() {
        _errorMessage = 'MPIN does not match. Try again.';
        _pinController.clear();
      });
      _focusNode.requestFocus();
      return;
    }

    setState(() => _errorMessage = null);

    final success = await ref.read(walletMpinProvider.notifier).createMpin(pin);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet MPIN created successfully!')),
      );
      // Pop twice to return to previous flow (Home or Security)
      if (context.canPop()) context.pop();
      if (context.canPop()) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletMpinProvider);

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 24,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primaryBlue, width: 2),
    );

    final errorPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.error, width: 2),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm MPIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 64,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Confirm Your MPIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Please enter your 6-digit MPIN again to confirm.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (state.isLoading)
                const CircularProgressIndicator()
              else
                Pinput(
                  length: 6,
                  controller: _pinController,
                  focusNode: _focusNode,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  errorPinTheme: errorPinTheme,
                  forceErrorState: _errorMessage != null || state.error != null,
                  obscureText: true,
                  obscuringCharacter: '●',
                  autofocus: true,
                  onChanged: (v) {
                    if (_errorMessage != null || state.error != null) {
                      setState(() => _errorMessage = null);
                      ref.read(walletMpinProvider.notifier).clearError();
                    }
                  },
                  onCompleted: _onCompleted,
                ),
              if (_errorMessage != null || state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? state.error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
