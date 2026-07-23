import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../../auth_msg91/screens/msg91_webview_screen.dart';
import '../providers/wallet_mpin_provider.dart';

class ForgotMpinScreen extends ConsumerStatefulWidget {
  const ForgotMpinScreen({super.key});

  @override
  ConsumerState<ForgotMpinScreen> createState() => _ForgotMpinScreenState();
}

class _ForgotMpinScreenState extends ConsumerState<ForgotMpinScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isPhoneValid = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String val) {
    final isValid = val.length == 10;
    if (_isPhoneValid != isValid) {
      setState(() => _isPhoneValid = isValid);
      if (isValid) HapticFeedback.lightImpact();
    }
  }

  void _launchMsg91Widget(String phone) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Msg91WebViewScreen(
          phone: phone,
          onSuccess: (accessToken) async {
            Navigator.of(ctx).pop(); // pop webview
            
            final success = await ref.read(walletMpinProvider.notifier).verifyForgotOtp(accessToken: accessToken);
            if (success && mounted) {
              // Navigate to Reset MPIN screen
              context.pushNamed(RouteNames.resetMpin);
            }
          },
          onFailure: (error) {
            Navigator.of(ctx).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: AppColors.error),
            );
          },
        ),
      ),
    );
  }

  void _submit() {
    if (_isPhoneValid) {
      _launchMsg91Widget(_phoneController.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(walletMpinProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot MPIN'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Wallet MPIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter your registered mobile number to verify your identity via OTP.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                onChanged: _onPhoneChanged,
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  prefixText: '+91 ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isPhoneValid && !state.isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Send OTP',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
