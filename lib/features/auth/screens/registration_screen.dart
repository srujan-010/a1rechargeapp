import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_names.dart';
import '../provider/auth_provider.dart';
import '../models/auth_state.dart';

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
  // Wizard Step Index: 0 = Account Type, 1 = Form Details, 2 = Review Details, 3 = Terms & Complete
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Selected Account Type: 'PERSONAL' or 'RETAILER'
  String _accountType = 'PERSONAL';

  // Common Fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Retailer Specific Fields
  final _shopNameController = TextEditingController();
  bool _hasPhysicalShop = true;
  String _selectedBusinessType = 'Mobile Recharge Shop';

  final List<String> _businessTypes = [
    'Mobile Recharge Shop',
    'General Store',
    'Electronics Shop',
    'CSC / Digital Service Center',
    'Travel Agency',
    'Other',
  ];

  // Address fields
  final _addressController = TextEditingController();
  String _selectedAddress = '';
  String _extractedCity = '';
  String _extractedState = '';
  String _extractedPincode = '';

  // Terms Acceptance
  bool _termsAccepted = false;
  String? _termsError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep = 1);
      return;
    }

    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) return;
      if (_accountType == 'RETAILER' && _hasPhysicalShop) {
        final addrStr = _addressController.text.trim().isNotEmpty 
          ? _addressController.text.trim() 
          : _selectedAddress;
        if (addrStr.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please provide your shop address for physical shop.')),
          );
          return;
        }
      }
      HapticFeedback.lightImpact();
      setState(() => _currentStep = 2);
      return;
    }

    if (_currentStep == 2) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep = 3);
      return;
    }

    if (_currentStep == 3) {
      if (!_termsAccepted) {
        setState(() => _termsError = 'You must accept the Terms & Conditions to complete onboarding.');
        return;
      }
      _submit();
    }
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
    HapticFeedback.mediumImpact();
    final addr = _addressController.text.trim().isNotEmpty 
      ? _addressController.text.trim() 
      : _selectedAddress;

    ref.read(authNotifierProvider.notifier).submitRegistration(
      tempSessionToken: widget.tempSessionToken,
      accountType: _accountType,
      name: _nameController.text.trim(),
      shopName: _accountType == 'RETAILER' ? _shopNameController.text.trim() : null,
      hasPhysicalShop: _accountType == 'RETAILER' ? _hasPhysicalShop : false,
      businessType: _accountType == 'RETAILER' ? _selectedBusinessType : null,
      address: addr.isNotEmpty ? addr : null,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      state: _extractedState.isNotEmpty ? _extractedState : null,
      district: _extractedCity.isNotEmpty ? _extractedCity : null,
      pincode: _extractedPincode.isNotEmpty ? _extractedPincode : null,
      termsAccepted: _termsAccepted,
    );
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

    final progressPercent = ((_currentStep + 1) / 4 * 100).toInt();

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
            const Text('A1 Recharge Onboarding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text('Step ${_currentStep + 1} of 4', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                    value: (_currentStep + 1) / 4,
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Fast, secure registration. Account details can be managed in profile later.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
                          child: const Text('Back', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: (isLoading || (_currentStep == 3 && !_termsAccepted)) ? null : _nextStep,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                _currentStep == 3 ? 'Complete Onboarding' : 'Continue',
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
              child: Form(
                key: _formKey,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: _buildStepContent(_currentStep),
                ),
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
        return _buildAccountTypeStep();
      case 1:
        return _accountType == 'PERSONAL' ? _buildPersonalFormStep() : _buildRetailerFormStep();
      case 2:
        return _buildReviewStep();
      case 3:
        return _buildTermsStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 0: Account Type Selection
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAccountTypeStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'How do you want to use A1 Recharge?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose the account type that best matches your needs.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 24),

        // Personal Card
        _AccountTypeCard(
          title: '👤 Personal Account',
          subtitle: 'Recharge for yourself & your family.',
          features: const ['Mobile Recharge', 'DTH Recharge', 'Electricity Payments'],
          isSelected: _accountType == 'PERSONAL',
          onTap: () => setState(() => _accountType = 'PERSONAL'),
        ),
        const SizedBox(height: 16),

        // Retailer Card
        _AccountTypeCard(
          title: '🏪 Retailer Account',
          subtitle: 'Recharge for customers and earn commissions.',
          features: const ['Business Wallet', 'Customer Recharges', 'Commission', 'Transaction Reports'],
          isSelected: _accountType == 'RETAILER',
          onTap: () => setState(() => _accountType = 'RETAILER'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 1A: Personal Form
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildPersonalFormStep() {
    return Column(
      key: const ValueKey('PERSONAL_FORM'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Personal Details',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your basic details to create your Personal Account.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 24),

        _FilledTextField(
          controller: _nameController,
          label: 'Full Name *',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
          autoFocus: true,
        ),
        const SizedBox(height: 16),

        _VerifiedPhoneField(phone: widget.mobile),
        const SizedBox(height: 16),

        _FilledTextField(
          controller: _emailController,
          label: 'Email Address (Optional)',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 1B: Retailer Form
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRetailerFormStep() {
    return Column(
      key: const ValueKey('RETAILER_FORM'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Business Details',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tell us about your business to setup your Retailer Account.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 24),

        _FilledTextField(
          controller: _nameController,
          label: 'Owner / Full Name *',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Owner Name is required' : null,
          autoFocus: true,
        ),
        const SizedBox(height: 16),

        _FilledTextField(
          controller: _shopNameController,
          label: 'Business / Shop Name *',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Business Name is required' : null,
        ),
        const SizedBox(height: 16),

        // Physical Shop Toggle
        const Text('Physical Shop? *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _hasPhysicalShop = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _hasPhysicalShop ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _hasPhysicalShop ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.storefront, size: 18, color: _hasPhysicalShop ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('YES (Physical Shop)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _hasPhysicalShop ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _hasPhysicalShop = false),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_hasPhysicalShop ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: !_hasPhysicalShop ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.language, size: 18, color: !_hasPhysicalShop ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text('NO (Online / Direct)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: !_hasPhysicalShop ? const Color(0xFF2563EB) : const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Business Type Dropdown
        DropdownButtonFormField<String>(
          value: _selectedBusinessType,
          decoration: InputDecoration(
            labelText: 'Business Type *',
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: _businessTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedBusinessType = val);
          },
        ),
        const SizedBox(height: 16),

        if (_hasPhysicalShop) ...[
          _FilledTextField(
            controller: _addressController,
            label: 'Shop Address *',
            validator: (v) => (_hasPhysicalShop && (v == null || v.trim().isEmpty)) ? 'Address is required for Physical Shop' : null,
          ),
          const SizedBox(height: 16),
        ],

        _VerifiedPhoneField(phone: widget.mobile),
        const SizedBox(height: 16),

        _FilledTextField(
          controller: _emailController,
          label: 'Email Address (Optional)',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 2: Review Details
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildReviewStep() {
    final isRetailer = _accountType == 'RETAILER';
    final addrStr = _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : _selectedAddress;

    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Review Information',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please verify your onboarding details before completing registration.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRetailer ? '🏪 Retailer Account' : '👤 Personal Account',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _currentStep = 1),
                    icon: const Icon(Icons.edit, size: 14, color: Color(0xFF2563EB)),
                    label: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  )
                ],
              ),
              const Divider(height: 24),
              _ReviewRow(label: 'Name', value: _nameController.text.trim()),
              _ReviewRow(label: 'Mobile', value: widget.mobile),
              if (_emailController.text.trim().isNotEmpty)
                _ReviewRow(label: 'Email', value: _emailController.text.trim()),

              if (isRetailer) ...[
                _ReviewRow(label: 'Business Name', value: _shopNameController.text.trim()),
                _ReviewRow(label: 'Physical Shop', value: _hasPhysicalShop ? 'Yes' : 'No'),
                _ReviewRow(label: 'Business Type', value: _selectedBusinessType),
                if (_hasPhysicalShop && addrStr.isNotEmpty)
                  _ReviewRow(label: 'Address', value: addrStr),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 3: Terms & Conditions
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTermsStep() {
    final isRetailer = _accountType == 'RETAILER';

    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Terms & Agreement',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please review and accept the terms to complete your onboarding.',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 24),

        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(RouteNames.termsAndConditions);
            },
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isRetailer 
                            ? 'Retailer Service Agreement & Terms' 
                            : 'A1 Recharge User Terms & Conditions',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRetailer
                      ? 'By registering as a Retailer, you agree to comply with A1 Recharge commission policies, transaction guidelines, and regulatory requirements.'
                      : 'By registering a Personal Account, you agree to use A1 Recharge for lawful recharge and payment services.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Terms & Conditions',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _termsAccepted,
                onChanged: (val) {
                  setState(() {
                    _termsAccepted = val ?? false;
                    if (_termsAccepted) _termsError = null;
                  });
                },
                activeColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text.rich(
                  TextSpan(
                    text: 'I agree to the A1 Recharge ',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A), height: 1.4),
                    children: [
                      TextSpan(
                        text: 'Terms & Conditions',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            HapticFeedback.lightImpact();
                            context.push(RouteNames.termsAndConditions);
                          },
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            HapticFeedback.lightImpact();
                            context.push(RouteNames.privacyPolicy);
                          },
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (_termsError != null) ...[
          const SizedBox(height: 6),
          Text(_termsError!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w500)),
        ],

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selectable Account Type Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _AccountTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> features;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.title,
    required this.subtitle,
    required this.features,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                Radio<bool>(
                  value: true,
                  groupValue: isSelected,
                  onChanged: (_) => onTap(),
                  activeColor: const Color(0xFF2563EB),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: features.map((f) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    f,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          ),
        ],
      ),
    );
  }
}

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
              children: const [
                Icon(Icons.check_circle, size: 14, color: Color(0xFF16A34A)),
                SizedBox(width: 4),
                Text('Verified', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
