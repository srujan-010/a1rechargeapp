import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../domain/models/bank_details.dart';
import 'bank_details_provider.dart';

class AddBankScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extraData; // { 'bank': BankDetails, 'mpin': '123456' }

  const AddBankScreen({super.key, this.extraData});

  @override
  ConsumerState<AddBankScreen> createState() => _AddBankScreenState();
}

class _AddBankScreenState extends ConsumerState<AddBankScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _holderNameController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountNumberController;
  late TextEditingController _confirmAccountController;
  late TextEditingController _ifscController;
  late TextEditingController _branchController;
  late TextEditingController _cityController;
  late TextEditingController _upiController;

  String _accountType = 'Savings';
  bool _isFetchingIfsc = false;
  String? _ifscError;
  String? _documentUrl; // Mocked document url

  @override
  void initState() {
    super.initState();
    final bank = widget.extraData?['bank'] as BankDetails?;
    
    _holderNameController = TextEditingController(text: bank?.accountHolderName ?? '');
    _bankNameController = TextEditingController(text: bank?.bankName ?? '');
    _accountNumberController = TextEditingController(text: bank != null ? 'XXXXXXXX' : ''); // Can't edit masked, force re-entry if editing
    _confirmAccountController = TextEditingController(text: bank != null ? 'XXXXXXXX' : '');
    _ifscController = TextEditingController(text: bank?.ifsc ?? '');
    _branchController = TextEditingController(text: bank?.branch ?? '');
    _cityController = TextEditingController(text: bank?.city ?? '');
    _upiController = TextEditingController(text: bank?.upiId ?? '');
    
    if (bank != null) {
      _accountType = bank.accountType;
      _documentUrl = bank.documentUrl;
    }
  }

  @override
  void dispose() {
    _holderNameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _confirmAccountController.dispose();
    _ifscController.dispose();
    _branchController.dispose();
    _cityController.dispose();
    _upiController.dispose();
    super.dispose();
  }

  void _onIfscChanged(String value) async {
    if (value.length == 11) {
      setState(() {
        _isFetchingIfsc = true;
        _ifscError = null;
      });

      final data = await ref.read(bankDetailsProvider.notifier).lookupIfsc(value.toUpperCase());

      setState(() {
        _isFetchingIfsc = false;
        if (data != null) {
          _bankNameController.text = data['BANK'] ?? '';
          _branchController.text = data['BRANCH'] ?? '';
          _cityController.text = data['CITY'] ?? '';
        } else {
          _ifscError = 'Invalid IFSC code';
        }
      });
    } else {
      setState(() {
        _ifscError = null;
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_ifscError != null) return;

    final details = BankDetails(
      accountHolderName: _holderNameController.text.trim(),
      bankName: _bankNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      ifsc: _ifscController.text.trim().toUpperCase(),
      branch: _branchController.text.trim(),
      city: _cityController.text.trim(),
      accountType: _accountType,
      upiId: _upiController.text.trim(),
      documentUrl: _documentUrl,
    );

    final mpin = widget.extraData?['mpin'] as String?;

    final success = await ref.read(bankDetailsProvider.notifier).saveBankDetails(details, mpin: mpin);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank account saved successfully'), backgroundColor: AppColors.success),
      );
      context.pop();
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool required = true,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int? maxLength,
    void Function(String)? onChanged,
    Widget? suffixIcon,
    String? errorText,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        maxLength: maxLength,
        onChanged: onChanged,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          counterText: '',
          suffixIcon: suffixIcon,
          errorText: errorText,
          filled: readOnly,
          fillColor: readOnly ? Colors.grey.shade100 : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        validator: validator ?? (value) {
          if (required && (value == null || value.trim().isEmpty)) {
            return 'Please enter $label';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankDetailsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.extraData?['bank'] != null ? 'Edit Bank Account' : 'Add Bank Account'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextTheme.textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  label: 'Account Holder Name',
                  controller: _holderNameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter account holder name';
                    if (val.trim().length < 3) return 'Name must be at least 3 characters';
                    return null;
                  },
                ),

                _buildTextField(
                  label: 'IFSC Code',
                  controller: _ifscController,
                  maxLength: 11,
                  errorText: _ifscError,
                  onChanged: _onIfscChanged,
                  suffixIcon: _isFetchingIfsc 
                    ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2)) 
                    : null,
                  validator: (val) {
                    if (val == null || val.trim().length != 11) return 'Enter valid 11-digit IFSC';
                    return null;
                  },
                ),

                _buildTextField(
                  label: 'Bank Name',
                  controller: _bankNameController,
                ),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'Branch Name',
                        controller: _branchController,
                        required: false,
                        readOnly: _bankNameController.text.isNotEmpty, // Make read-only if fetched
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildTextField(
                        label: 'City',
                        controller: _cityController,
                        required: false,
                        readOnly: _bankNameController.text.isNotEmpty,
                      ),
                    ),
                  ],
                ),

                _buildTextField(
                  label: 'Account Number',
                  controller: _accountNumberController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter account number';
                    if (val.trim().length < 6) return 'Invalid account number';
                    return null;
                  },
                ),

                _buildTextField(
                  label: 'Confirm Account Number',
                  controller: _confirmAccountController,
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Confirm account number';
                    if (val != _accountNumberController.text) return 'Account numbers do not match';
                    return null;
                  },
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account Type *', style: AppTextTheme.textTheme.labelLarge),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Savings'),
                              value: 'Savings',
                              groupValue: _accountType,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _accountType = val!),
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Current'),
                              value: 'Current',
                              groupValue: _accountType,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _accountType = val!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _buildTextField(
                  label: 'UPI ID',
                  controller: _upiController,
                  required: false,
                  validator: (val) {
                    if (val != null && val.isNotEmpty && !val.contains('@')) {
                      return 'Invalid UPI ID';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.lg),
                Text('Document Verification (Optional)', style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Text('Upload Cancelled Cheque or Bank Passbook First Page', style: AppTextTheme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.md),

                InkWell(
                  onTap: () {
                    // MOCK UPLOAD
                    setState(() {
                      _documentUrl = 'https://mock.upload.url/document.jpg';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document uploaded (Mock)')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _documentUrl != null ? Icons.check_circle : Icons.upload_file,
                          color: _documentUrl != null ? AppColors.success : AppColors.primaryBlue,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _documentUrl != null ? 'Document Uploaded' : 'Tap to Upload Document',
                          style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),

                ElevatedButton(
                  onPressed: state.isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppColors.primaryBlue,
                  ),
                  child: state.isSaving
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text(
                          'Save Bank Details',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
