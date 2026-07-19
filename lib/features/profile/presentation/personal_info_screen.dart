import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import 'personal_info_provider.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  final Map<String, dynamic> _pendingChanges = {};

  bool get _hasChanges => _pendingChanges.isNotEmpty;

  void _onFieldEdited(String key, dynamic value) {
    setState(() {
      _pendingChanges[key] = value;
    });
  }

  void _discardChanges() {
    setState(() {
      _pendingChanges.clear();
    });
  }

  Future<void> _saveChanges() async {
    await ref.read(personalInfoProvider.notifier).updateProfile(_pendingChanges);
    if (mounted) {
      final state = ref.read(personalInfoProvider);
      if (!state.hasError) {
        setState(() {
          _pendingChanges.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Color(0xFF00C853),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await ref.read(personalInfoProvider.notifier).uploadAvatar(File(image.path));
      if (mounted) {
        final state = ref.read(personalInfoProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Avatar upload failed: ${state.error}'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated'),
              backgroundColor: Color(0xFF00C853),
            ),
          );
        }
      }
    }
  }

  String _getValue(SessionUser user, String key) {
    if (_pendingChanges.containsKey(key)) {
      return _pendingChanges[key]?.toString() ?? '';
    }
    switch (key) {
      case 'name': return user.name;
      case 'email': return user.email ?? '';
      case 'dob': return user.dob ?? '';
      case 'gender': return user.gender ?? '';
      case 'shopName': return user.shopName ?? '';
      case 'shopAddress': return user.shopAddress ?? '';
      case 'city': return user.city ?? '';
      case 'state': return user.state ?? '';
      case 'pincode': return user.pincode ?? '';
      case 'gstNumber': return user.gstNumber ?? '';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);
    final user = sessionAsync.valueOrNull;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isSaving = ref.watch(personalInfoProvider).isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () {
            if (_hasChanges) {
              _showDiscardDialog();
            } else {
              context.pop();
            }
          },
        ),
        title: Column(
          children: [
            Text(
              'Personal Information',
              style: AppTextTheme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Manage your personal account details.',
              style: AppTextTheme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE2E8F0),
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                                    ? Image.network(
                                        '${AppConfig.baseUrl.replaceAll('/api', '')}${user.avatarUrl}',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildInitials(user.name),
                                      )
                                    : _buildInitials(user.name),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAvatar,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _getValue(user, 'name'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.retailerId,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified, size: 14, color: Color(0xFF16A34A)),
                            const SizedBox(width: 6),
                            Text(
                              user.phone,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (user.email == null || user.email!.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDBEAFE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.email_outlined, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Add your email address', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A))),
                                SizedBox(height: 2),
                                Text('to receive invoices and important updates.', style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Personal Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _SectionCard(
                    title: 'Personal Details',
                    children: [
                      _FieldRow(
                        label: 'Full Name',
                        value: _getValue(user, 'name'),
                        onTap: () => _editField(context, 'name', 'Full Name', _getValue(user, 'name')),
                      ),
                      _FieldRow(
                        label: 'Email Address',
                        value: _getValue(user, 'email'),
                        placeholder: 'Not provided',
                        onTap: () => _editField(context, 'email', 'Email Address', _getValue(user, 'email'), isEmail: true),
                      ),
                      _FieldRow(
                        label: 'Date of Birth',
                        value: _getValue(user, 'dob').isNotEmpty ? DateFormat('dd MMM yyyy').format(DateTime.parse(_getValue(user, 'dob'))) : '',
                        placeholder: 'Optional',
                        onTap: () => _editDate(context, 'dob', _getValue(user, 'dob')),
                      ),
                      _FieldRow(
                        label: 'Gender',
                        value: _getValue(user, 'gender'),
                        placeholder: 'Optional',
                        onTap: () => _editDropdown(context, 'gender', 'Gender', _getValue(user, 'gender'), ['Male', 'Female', 'Other']),
                      ),
                      _FieldRow(
                        label: 'Verified Mobile',
                        value: user.phone,
                        isReadOnly: true,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Change Number only through customer support.')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Business Details
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _SectionCard(
                    title: 'Business Information',
                    children: [
                      _FieldRow(
                        label: 'Shop Name',
                        value: _getValue(user, 'shopName'),
                        placeholder: 'Add Shop Name',
                        onTap: () => _editField(context, 'shopName', 'Shop Name', _getValue(user, 'shopName')),
                      ),
                      _FieldRow(
                        label: 'Business Address',
                        value: _getValue(user, 'shopAddress'),
                        placeholder: 'Add Address',
                        onTap: () => _editField(context, 'shopAddress', 'Business Address', _getValue(user, 'shopAddress'), multiline: true),
                      ),
                      _FieldRow(
                        label: 'City',
                        value: _getValue(user, 'city'),
                        placeholder: 'Add City',
                        onTap: () => _editField(context, 'city', 'City', _getValue(user, 'city')),
                      ),
                      _FieldRow(
                        label: 'State',
                        value: _getValue(user, 'state'),
                        placeholder: 'Add State',
                        onTap: () => _editField(context, 'state', 'State', _getValue(user, 'state')),
                      ),
                      _FieldRow(
                        label: 'Pincode',
                        value: _getValue(user, 'pincode'),
                        placeholder: 'Add Pincode',
                        onTap: () => _editField(context, 'pincode', 'Pincode', _getValue(user, 'pincode'), isNumber: true),
                      ),
                      _FieldRow(
                        label: 'GST Number',
                        value: _getValue(user, 'gstNumber'),
                        placeholder: 'Optional',
                        onTap: () => _editField(context, 'gstNumber', 'GST Number', _getValue(user, 'gstNumber')),
                      ),
                    ],
                  ),
                ),
              ),

              // Account Status
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  child: _SectionCard(
                    title: 'Account Status',
                    children: [
                      _FieldRow(
                        label: 'KYC Status',
                        value: user.kycStatus.toUpperCase(),
                        isReadOnly: true,
                        valueColor: user.isVerified ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      ),
                      _FieldRow(
                        label: 'Retailer ID',
                        value: user.retailerId,
                        isReadOnly: true,
                      ),
                      _FieldRow(
                        label: 'Member Since',
                        value: user.createdAt != null ? DateFormat('MMM yyyy').format(DateTime.parse(user.createdAt!)) : 'N/A',
                        isReadOnly: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky Save Button
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _hasChanges ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _discardChanges,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: const Color(0xFF64748B),
                        ),
                        child: const Text('Discard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitials(String name) {
    String initials = '?';
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) {
        initials = '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      } else {
        initials = name[0].toUpperCase();
      }
    }
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _editField(BuildContext context, String key, String label, String currentValue, {bool isNumber = false, bool isEmail = false, bool multiline = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _EditFieldSheet(
          fieldKey: key,
          label: label,
          initialValue: currentValue,
          isNumber: isNumber,
          isEmail: isEmail,
          multiline: multiline,
          onSaved: (val) => _onFieldEdited(key, val),
        ),
      ),
    );
  }

  void _editDate(BuildContext context, String key, String currentValue) async {
    final initialDate = currentValue.isNotEmpty ? DateTime.tryParse(currentValue) ?? DateTime.now() : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _onFieldEdited(key, picked.toIso8601String());
    }
  }

  void _editDropdown(BuildContext context, String key, String label, String currentValue, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select $label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...options.map((opt) => ListTile(
                title: Text(opt),
                trailing: currentValue == opt ? const Icon(Icons.check, color: AppColors.primaryBlue) : null,
                onTap: () {
                  _onFieldEdited(key, opt);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.value,
    this.placeholder,
    this.isReadOnly = false,
    this.onTap,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? placeholder;
  final bool isReadOnly;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.isNotEmpty;
    final displayValue = hasValue ? value : (placeholder ?? '');
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  displayValue,
                  style: TextStyle(
                    color: valueColor ?? (hasValue ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
                    fontSize: 14,
                    fontWeight: hasValue ? FontWeight.w500 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isReadOnly) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EditFieldSheet extends StatefulWidget {
  const _EditFieldSheet({
    required this.fieldKey,
    required this.label,
    required this.initialValue,
    required this.onSaved,
    this.isNumber = false,
    this.isEmail = false,
    this.multiline = false,
  });

  final String fieldKey;
  final String label;
  final String initialValue;
  final Function(String) onSaved;
  final bool isNumber;
  final bool isEmail;
  final bool multiline;

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final val = _controller.text.trim();
    if (widget.fieldKey == 'name' && val.length < 3) {
      setState(() => _error = 'Name must be at least 3 characters');
      return;
    }
    if (widget.isEmail && val.isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      if (!emailRegex.hasMatch(val)) {
        setState(() => _error = 'Invalid email address');
        return;
      }
    }
    widget.onSaved(val);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit ${widget.label}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: widget.isNumber
                ? TextInputType.number
                : (widget.isEmail ? TextInputType.emailAddress : (widget.multiline ? TextInputType.multiline : TextInputType.text)),
            maxLines: widget.multiline ? 3 : 1,
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: _error,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
