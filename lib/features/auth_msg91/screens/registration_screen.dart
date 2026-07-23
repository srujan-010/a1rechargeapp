import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../providers/registration_provider.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  final String mobile;
  final String tempSessionToken;

  const RegistrationScreen({
    super.key,
    required this.mobile,
    required this.tempSessionToken,
  });

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _stateController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _referralController = TextEditingController();

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _stateController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      FocusScope.of(context).unfocus();

      ref.read(registrationProvider.notifier).register(
        tempSessionToken: widget.tempSessionToken,
        name: _ownerNameController.text.trim(),
        shopName: _shopNameController.text.trim(),
        address: _addressController.text.trim(),
        email: _emailController.text.trim(),
        state: _stateController.text.trim(),
        district: _districtController.text.trim(),
        pincode: _pincodeController.text.trim(),
        referralCode: _referralController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(registrationProvider);

    ref.listen(registrationProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (next.isRegistered && !(previous?.isRegistered ?? false)) {
        HapticFeedback.lightImpact();
        context.go(RouteNames.dashboard);
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Registration', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome to A1 Recharge!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E56E8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please fill in your details to create your retailer account. Your verified mobile number is ${widget.mobile}.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 32),
                
                _buildTextField(
                  controller: TextEditingController(text: widget.mobile),
                  label: 'Mobile Number *',
                  icon: Icons.phone,
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _shopNameController,
                  label: 'Shop Name *',
                  icon: Icons.store,
                  validator: (val) => val == null || val.isEmpty ? 'Shop name is required' : null,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _ownerNameController,
                  label: 'Owner Name *',
                  icon: Icons.person,
                  validator: (val) => val == null || val.isEmpty ? 'Owner name is required' : null,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _emailController,
                  label: 'Email (Optional)',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                _buildTextField(
                  controller: _addressController,
                  label: 'Shop Address *',
                  icon: Icons.location_on,
                  maxLines: 2,
                  validator: (val) => val == null || val.isEmpty ? 'Address is required' : null,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _stateController,
                        label: 'State',
                        icon: Icons.map,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _districtController,
                        label: 'District',
                        icon: Icons.location_city,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _pincodeController,
                        label: 'Pincode',
                        icon: Icons.pin_drop,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: _referralController,
                        label: 'Referral Code',
                        icon: Icons.card_giftcard,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: regState.isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E56E8),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: regState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      readOnly: readOnly,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 22),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E56E8), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
    );
  }
}
