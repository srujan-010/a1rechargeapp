import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../../../core/config/app_config.dart';
import '../provider/auth_provider.dart';
import '../models/auth_state.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  final String phone;
  final String firebaseUid;

  const RegistrationScreen({
    super.key,
    required this.phone,
    required this.firebaseUid,
  });

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1: Personal
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Step 2: Shop
  final _shopNameController = TextEditingController();
  
  // Hidden values for Smart Address extraction
  String _selectedAddress = '';
  String _extractedCity = '';
  String _extractedState = '';
  String _extractedPincode = '';
  String? _addressError;

  // Step 3: Security
  final _mpinController = TextEditingController();
  final _confirmMpinController = TextEditingController();
  String? _mpinError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _shopNameController.dispose();
    _mpinController.dispose();
    _confirmMpinController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    
    if (_currentStep == 1) {
      if (_selectedAddress.isEmpty) {
        setState(() => _addressError = 'Please search and select a business address');
        return;
      } else {
        setState(() => _addressError = null);
      }
    }
    
    if (_currentStep == 2) {
      final mpin = _mpinController.text;
      final confirm = _confirmMpinController.text;

      if (mpin.length != AppConfig.pinLength) {
        setState(() => _mpinError = 'Enter a ${AppConfig.pinLength}-digit MPIN');
        return;
      }
      if (RegExp(r'^(\d)\1+$').hasMatch(mpin)) {
        setState(() => _mpinError = 'MPIN cannot contain repeating digits');
        return;
      }
      const sequentialAsc = '0123456789';
      const sequentialDesc = '9876543210';
      if (sequentialAsc.contains(mpin) || sequentialDesc.contains(mpin)) {
        setState(() => _mpinError = 'MPIN cannot be sequential');
        return;
      }
      if (mpin != confirm) {
        setState(() => _mpinError = 'MPINs do not match');
        return;
      }
      setState(() => _mpinError = null);
      _submit();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.selectionClick();
      setState(() => _currentStep--);
    } else {
      context.pop();
    }
  }

  void _submit() {
    final formData = {
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'shopName': _shopNameController.text.trim(),
      'shopAddress': _selectedAddress,
      'city': _extractedCity,
      'state': _extractedState,
      'pincode': _extractedPincode,
      'mpin': _mpinController.text.trim(),
      'aadhaarNumber': 'PENDING',
      'panNumber': 'PENDING',
      'gstNumber': 'PENDING',
      'bank': {
        'bankName': 'PENDING',
        'accountNumber': 'PENDING',
        'ifsc': 'PENDING',
        'accountHolderName': 'PENDING',
      }
    };

    HapticFeedback.mediumImpact();
    ref.read(authNotifierProvider.notifier).submitRegistration(formData);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthStateLoading;

    ref.listen(authNotifierProvider, (previous, next) {
      if (next is AuthStateError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: AppColors.error),
        );
      } else if (next is AuthStateAuthenticated) {
        context.go(RouteNames.dashboard);
      }
    });

    final progressPercent = ((_currentStep + 1) / 3 * 100).toInt();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: _prevStep,
        ),
        title: Column(
          children: [
            const Text('Complete Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text('Step ${_currentStep + 1} of 3', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$progressPercent%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / 3,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can update these details later from Profile Settings.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          onPressed: isLoading ? null : _prevStep,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Previous', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: isLoading ? null : _nextStep,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _currentStep == 2 ? 'Finish Setup' : 'Continue',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: _buildStepContent(_currentStep),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return _PersonalStep(
          key: const ValueKey(0),
          phone: widget.phone,
          nameController: _nameController,
          emailController: _emailController,
        );
      case 1:
        return _ShopStep(
          key: const ValueKey(1),
          shopNameController: _shopNameController,
          addressError: _addressError,
          onAddressSelected: (addr, city, state, pin) {
            _selectedAddress = addr;
            _extractedCity = city;
            _extractedState = state;
            _extractedPincode = pin;
            if (_addressError != null) setState(() => _addressError = null);
          },
        );
      case 2:
        return _SecurityStep(
          key: const ValueKey(2),
          mpinController: _mpinController,
          confirmMpinController: _confirmMpinController,
          mpinError: _mpinError,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Steps
// ─────────────────────────────────────────────────────────────────────────────

class _PersonalStep extends StatelessWidget {
  final String phone;
  final TextEditingController nameController;
  final TextEditingController emailController;

  const _PersonalStep({
    super.key,
    required this.phone,
    required this.nameController,
    required this.emailController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About You', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text('We\'ll use these details to create your retailer account.', style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        const Text('Estimated time: Less than 1 minute.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
        const SizedBox(height: 32),
        
        _FilledTextField(
          controller: nameController,
          label: 'Full Name',
          validator: (v) => v!.isEmpty ? 'Name is required' : null,
          autoFocus: true,
        ),
        const SizedBox(height: 16),
        
        _VerifiedPhoneField(phone: phone),
        const SizedBox(height: 16),
        
        _FilledTextField(
          controller: emailController,
          label: 'Email Address (Optional)',
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
  }
}

class _ShopStep extends StatelessWidget {
  final TextEditingController shopNameController;
  final String? addressError;
  final Function(String address, String city, String state, String pin) onAddressSelected;

  const _ShopStep({
    super.key,
    required this.shopNameController,
    this.addressError,
    required this.onAddressSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Business', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text('Tell us about your shop.', style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        const Text('Estimated time: Less than 1 minute.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
        const SizedBox(height: 32),
        
        _FilledTextField(
          controller: shopNameController,
          label: 'Shop Name',
          validator: (v) => v!.isEmpty ? 'Shop name is required' : null,
          autoFocus: true,
        ),
        const SizedBox(height: 16),
        
        _MockGooglePlacesAutocomplete(
          errorText: addressError,
          onSelected: onAddressSelected,
        ),
      ],
    );
  }
}

class _SecurityStep extends StatelessWidget {
  final TextEditingController mpinController;
  final TextEditingController confirmMpinController;
  final String? mpinError;

  const _SecurityStep({
    super.key,
    required this.mpinController,
    required this.confirmMpinController,
    this.mpinError,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Secure Your Account', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Text('Create a 6-digit MPIN for secure transactions.', style: TextStyle(fontSize: 14, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        const Text('Estimated time: Less than 1 minute.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8))),
        const SizedBox(height: 32),
        
        const Text('Create MPIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        PinEntryWidget(
          controller: mpinController,
          length: 6,
          errorText: mpinError,
          onCompleted: (_) => HapticFeedback.lightImpact(),
        ),
        
        const SizedBox(height: 32),
        
        const Text('Confirm MPIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        PinEntryWidget(
          controller: confirmMpinController,
          length: 6,
          onCompleted: (_) => HapticFeedback.lightImpact(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared Fields
// ─────────────────────────────────────────────────────────────────────────────

class _FilledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool readOnly;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool autoFocus;

  const _FilledTextField({
    required this.controller,
    required this.label,
    this.readOnly = false,
    this.keyboardType,
    this.validator,
    this.autoFocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      autofocus: autoFocus,
      style: TextStyle(
        fontSize: 15, 
        fontWeight: FontWeight.w500, 
        color: readOnly ? const Color(0xFF64748B) : const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        floatingLabelStyle: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
      ),
    );
  }
}

class _VerifiedPhoneField extends StatelessWidget {
  final String phone;

  const _VerifiedPhoneField({required this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verified Mobile Number', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(phone, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 4),
                const Text('Verified', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock Google Places Autocomplete
// ─────────────────────────────────────────────────────────────────────────────

class _MockAddress {
  final String fullAddress;
  final String city;
  final String state;
  final String pincode;

  _MockAddress(this.fullAddress, this.city, this.state, this.pincode);
}

class _MockGooglePlacesAutocomplete extends StatefulWidget {
  final String? errorText;
  final Function(String, String, String, String) onSelected;

  const _MockGooglePlacesAutocomplete({this.errorText, required this.onSelected});

  @override
  State<_MockGooglePlacesAutocomplete> createState() => _MockGooglePlacesAutocompleteState();
}

class _MockGooglePlacesAutocompleteState extends State<_MockGooglePlacesAutocomplete> {
  final List<_MockAddress> _mockDatabase = [
    _MockAddress('12/A MG Road, Indiranagar, Bengaluru', 'Bengaluru', 'Karnataka', '560038'),
    _MockAddress('Shop 4, Linking Road, Bandra West, Mumbai', 'Mumbai', 'Maharashtra', '400050'),
    _MockAddress('45 Connaught Place, Block C, New Delhi', 'New Delhi', 'Delhi', '110001'),
    _MockAddress('Sector 17 Market, Near Fountain, Chandigarh', 'Chandigarh', 'Chandigarh', '160017'),
    _MockAddress('T Nagar, Near Silk House, Chennai', 'Chennai', 'Tamil Nadu', '600017'),
  ];

  @override
  Widget build(BuildContext context) {
    return Autocomplete<_MockAddress>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<_MockAddress>.empty();
        }
        return _mockDatabase.where((addr) => 
          addr.fullAddress.toLowerCase().contains(textEditingValue.text.toLowerCase())
        );
      },
      onSelected: (_MockAddress selection) {
        HapticFeedback.lightImpact();
        widget.onSelected(selection.fullAddress, selection.city, selection.state, selection.pincode);
      },
      displayStringForOption: (option) => option.fullAddress,
      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onEditingComplete: onEditingComplete,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            labelText: 'Business Address',
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            floatingLabelStyle: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w600),
            hintText: 'Search address',
            hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
            errorText: widget.errorText,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 200, 
                maxWidth: MediaQuery.of(context).size.width - 48,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(option.fullAddress, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A))),
                          const SizedBox(height: 4),
                          Text('${option.city}, ${option.state} ${option.pincode}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
