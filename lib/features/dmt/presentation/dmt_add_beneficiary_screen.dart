import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_button.dart';
import 'dmt_providers.dart';

class DmtAddBeneficiaryScreen extends ConsumerStatefulWidget {
  const DmtAddBeneficiaryScreen({super.key});

  @override
  ConsumerState<DmtAddBeneficiaryScreen> createState() => _DmtAddBeneficiaryScreenState();
}

class _DmtAddBeneficiaryScreenState extends ConsumerState<DmtAddBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _nameController = TextEditingController();
  final _bankController = TextEditingController();

  bool _isAdding = false;
  String? _errorMsg;

  @override
  void dispose() {
    _accountController.dispose();
    _ifscController.dispose();
    _nameController.dispose();
    _bankController.dispose();
    super.dispose();
  }

  Future<void> _addBeneficiary() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isAdding = true;
        _errorMsg = null;
      });

      try {
        final state = ref.read(dmtFlowProvider);
        if (state.currentRemitter == null) return;

        final repo = ref.read(dmtRepositoryProvider);
        final result = await repo.addBeneficiary(
          remitterId: state.currentRemitter!.id,
          accountNumber: _accountController.text.trim(),
          ifscCode: _ifscController.text.trim().toUpperCase(),
          name: _nameController.text.trim(),
          bankName: _bankController.text.trim(),
        );

        result.onSuccess((ben) {
          if (!mounted) return;
          // Refresh list
          ref.invalidate(dmtBeneficiariesProvider);
          context.pop();
        }).onFailure((e) {
          if (mounted) {
            setState(() => _errorMsg = e.toString().replaceAll('Exception: ', ''));
          }
        });
      } finally {
        if (mounted) setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add Beneficiary')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bank Details', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'Account Number'),
                  validator: (v) => v != null && v.length >= 8 ? null : 'Valid account number required',
                ),
                const SizedBox(height: AppSpacing.md),
                
                TextFormField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 11,
                  decoration: const InputDecoration(hintText: 'IFSC Code', counterText: ''),
                  validator: (v) => v != null && v.length == 11 ? null : '11-character IFSC required',
                ),
                const SizedBox(height: AppSpacing.md),

                TextFormField(
                  controller: _bankController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Bank Name'),
                  validator: (v) => v != null && v.isNotEmpty ? null : 'Bank name required',
                ),
                const SizedBox(height: AppSpacing.lg),

                Text('Beneficiary Details', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Beneficiary Name'),
                  validator: (v) => v != null && v.isNotEmpty ? null : 'Name required',
                ),
                const SizedBox(height: AppSpacing.xxl),

                if (_errorMsg != null) ...[
                  Text(
                    _errorMsg!,
                    style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                AppButton(
                  label: 'Add Beneficiary',
                  isLoading: _isAdding,
                  onPressed: _addBeneficiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
