import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/wallet_mpin_provider.dart';

class VerifyMpinDialog extends ConsumerStatefulWidget {
  final String amount;
  
  const VerifyMpinDialog({super.key, required this.amount});

  static Future<String?> show(BuildContext context, {required String amount}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: VerifyMpinDialog(amount: amount),
      ),
    );
    return result;
  }

  @override
  ConsumerState<VerifyMpinDialog> createState() => _VerifyMpinDialogState();
}

class _VerifyMpinDialogState extends ConsumerState<VerifyMpinDialog> {
  final _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCompleted(String pin) async {
    final success = await ref.read(walletMpinProvider.notifier).verifyMpin(pin);
    if (success && mounted) {
      context.pop(pin); // Return pin on success
    } else {
      _pinController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletMpinProvider);

    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(fontSize: 24, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 48, color: AppColors.primaryBlue),
          const SizedBox(height: 16),
          const Text(
            'Enter Wallet MPIN',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'To authorize payment of ₹${widget.amount}',
            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          if (state.isLoading)
            const CircularProgressIndicator()
          else
            Pinput(
              length: 6,
              controller: _pinController,
              focusNode: _focusNode,
              defaultPinTheme: defaultPinTheme,
              obscureText: true,
              obscuringCharacter: '●',
              forceErrorState: state.error != null,
              onChanged: (v) {
                if (state.error != null) {
                  ref.read(walletMpinProvider.notifier).clearError();
                }
              },
              onCompleted: _onCompleted,
            ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          // Biometric could go here in future
        ],
      ),
    );
  }
}
