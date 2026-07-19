// lib/core/widgets/pin_entry_widget.dart
// 6-digit PIN entry widget using pinput package.
// Used for: MPIN entry, Transaction PIN confirmation.
// SECURITY: Pin value is never stored in widget state beyond the callback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pinput/pinput.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

class PinEntryWidget extends StatefulWidget {
  const PinEntryWidget({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.errorText,
    this.length = AppConfig.pinLength,
    this.autofocus = true,
    this.controller,
    this.focusNode,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final int length;
  final bool autofocus;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  State<PinEntryWidget> createState() => _PinEntryWidgetState();
}

class _PinEntryWidgetState extends State<PinEntryWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  PinTheme get _defaultTheme => PinTheme(
        width: 52,
        height: 56,
        textStyle: AppTextTheme.textTheme.displaySmall?.copyWith(
          fontSize: 24,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
      );

  PinTheme get _focusedTheme => _defaultTheme.copyWith(
        decoration: BoxDecoration(
          color: AppColors.primaryBlueLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBlue, width: 2),
        ),
      );

  PinTheme get _errorTheme => _defaultTheme.copyWith(
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Enter ${widget.length}-digit PIN',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pinput(
            controller: _controller,
            focusNode: _focusNode,
            length: widget.length,
            obscureText: true,
            obscuringCharacter: '●',
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            defaultPinTheme: _defaultTheme,
            focusedPinTheme: _focusedTheme,
            errorPinTheme: _errorTheme,
            forceErrorState: widget.errorText != null,
            onCompleted: widget.onCompleted,
            onChanged: widget.onChanged,
            errorText: widget.errorText,
            errorTextStyle: AppTextTheme.textTheme.bodySmall?.copyWith(
              color: AppColors.error,
            ),
            cursor: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  width: 22,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Transaction confirmation PIN bottom sheet.
/// Shows a PIN entry in a modal sheet and calls [onConfirmed] on success.
Future<String?> showTransactionPinSheet(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _TransactionPinSheet(),
  );
}

class _TransactionPinSheet extends StatefulWidget {
  const _TransactionPinSheet();

  @override
  State<_TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<_TransactionPinSheet> {
  String? _errorText;
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '🔒 Enter Transaction PIN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your 6-digit PIN to confirm this transaction',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            PinEntryWidget(
              controller: _controller,
              errorText: _errorText,
              onCompleted: (pin) {
                // Basic client-side length check only — real validation on backend
                if (pin.length != AppConfig.pinLength) {
                  setState(() => _errorText = 'Enter a valid ${AppConfig.pinLength}-digit PIN');
                  return;
                }
                Navigator.of(context).pop(pin);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
