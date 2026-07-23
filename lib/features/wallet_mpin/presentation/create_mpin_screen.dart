import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';

class CreateMpinScreen extends StatefulWidget {
  const CreateMpinScreen({super.key});

  @override
  State<CreateMpinScreen> createState() => _CreateMpinScreenState();
}

class _CreateMpinScreenState extends State<CreateMpinScreen> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _validateMpin(String mpin) {
    if (mpin.length != 6) return 'Enter exactly 6 digits';
    if (RegExp(r'^(\d)\1{5}$').hasMatch(mpin)) {
      return 'Avoid repeated digits (e.g. 111111)';
    }
    
    bool asc = true, desc = true;
    for (int i = 1; i < mpin.length; i++) {
      int curr = int.parse(mpin[i]);
      int prev = int.parse(mpin[i-1]);
      if (curr != prev + 1) asc = false;
      if (curr != prev - 1) desc = false;
    }
    if (asc || desc) {
      return 'Avoid sequential digits (e.g. 123456)';
    }
    return null;
  }

  void _onCompleted(String pin) {
    final error = _validateMpin(pin);
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _pinController.clear();
      });
      _focusNode.requestFocus();
    } else {
      setState(() => _errorMessage = null);
      // Navigate to confirm
      context.pushNamed(
        RouteNames.confirmMpin,
        extra: pin,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Create Wallet MPIN'),
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
                Icons.security_rounded,
                size: 64,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Set Your Secure MPIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Create a 6-digit MPIN to secure your wallet transactions.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Pinput(
                length: 6,
                controller: _pinController,
                focusNode: _focusNode,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: focusedPinTheme,
                errorPinTheme: errorPinTheme,
                forceErrorState: _errorMessage != null,
                obscureText: true,
                obscuringCharacter: '●',
                onChanged: (v) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
                onCompleted: _onCompleted,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              const Text(
                'Note: Avoid simple sequences like 123456 or 111111.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
