import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/wallet_mpin_provider.dart';

class ChangeMpinScreen extends ConsumerStatefulWidget {
  const ChangeMpinScreen({super.key});

  @override
  ConsumerState<ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

class _ChangeMpinScreenState extends ConsumerState<ChangeMpinScreen> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  String? _newPinError;
  String? _confirmPinError;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  String? _validateMpin(String mpin) {
    if (mpin.length != 6) return 'Enter exactly 6 digits';
    if (RegExp(r'^(\d)\1{5}$').hasMatch(mpin)) return 'Avoid repeated digits';
    bool asc = true, desc = true;
    for (int i = 1; i < mpin.length; i++) {
      int curr = int.parse(mpin[i]);
      int prev = int.parse(mpin[i-1]);
      if (curr != prev + 1) asc = false;
      if (curr != prev - 1) desc = false;
    }
    if (asc || desc) return 'Avoid sequential digits';
    return null;
  }

  void _submit() async {
    setState(() {
      _newPinError = _validateMpin(_newPinController.text);
      _confirmPinError = _newPinController.text != _confirmPinController.text 
          ? 'MPINs do not match' 
          : null;
    });

    if (_currentPinController.text.length != 6) return;
    if (_newPinError != null || _confirmPinError != null) return;

    final success = await ref.read(walletMpinProvider.notifier).changeMpin(
      _currentPinController.text, 
      _newPinController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet MPIN changed successfully!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletMpinProvider);

    final defaultPinTheme = PinTheme(
      width: 45,
      height: 55,
      textStyle: const TextStyle(fontSize: 20, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change MPIN'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current MPIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Pinput(
                length: 6,
                controller: _currentPinController,
                defaultPinTheme: defaultPinTheme,
                obscureText: true,
                obscuringCharacter: '●',
              ),
              const SizedBox(height: 32),
              
              const Text('New MPIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Pinput(
                length: 6,
                controller: _newPinController,
                defaultPinTheme: defaultPinTheme,
                obscureText: true,
                obscuringCharacter: '●',
                errorText: _newPinError,
                forceErrorState: _newPinError != null,
                onChanged: (v) {
                  if (_newPinError != null) setState(() => _newPinError = null);
                },
              ),
              const SizedBox(height: 32),
              
              const Text('Confirm New MPIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Pinput(
                length: 6,
                controller: _confirmPinController,
                defaultPinTheme: defaultPinTheme,
                obscureText: true,
                obscuringCharacter: '●',
                errorText: _confirmPinError,
                forceErrorState: _confirmPinError != null,
                onChanged: (v) {
                  if (_confirmPinError != null) setState(() => _confirmPinError = null);
                },
              ),
              
              if (state.error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Change MPIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
