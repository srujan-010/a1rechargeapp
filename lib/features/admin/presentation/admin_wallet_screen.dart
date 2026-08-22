// lib/features/admin/presentation/admin_wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_field.dart';

class AdminWalletScreen extends ConsumerStatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  ConsumerState<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends ConsumerState<AdminWalletScreen> {
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _remarkController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSearching = false;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _retailers = [];
  Map<String, dynamic>? _selectedRetailer;

  @override
  void initState() {
    super.initState();
    _searchRetailers('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _searchRetailers(String query) async {
    setState(() => _isSearching = true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get<List<dynamic>>(
        '/admin/retailers/search',
        queryParameters: {'query': query},
        fromJson: (json) => json as List<dynamic>,
      );

      if (response.success && response.data != null) {
        setState(() {
          _retailers = response.data!.map((e) => e as Map<String, dynamic>).toList();
        });
      }
    } catch (e) {
      // Handle silently or show error
    } finally {
      setState(() => _isSearching = false);
    }
  }

  double get _enteredAmount {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 0.0;
    return double.tryParse(text) ?? 0.0;
  }

  double get _currentBalance {
    if (_selectedRetailer == null) return 0.0;
    final rupees = _selectedRetailer!['availableRupees'] ?? _selectedRetailer!['balanceRupees'];
    if (rupees is num) return rupees.toDouble();
    return 0.0;
  }

  double get _newBalance => _currentBalance + _enteredAmount;

  void _selectRetailer(Map<String, dynamic> retailer) {
    setState(() {
      _selectedRetailer = retailer;
    });
  }

  Future<void> _handleCreditSubmit() async {
    if (_selectedRetailer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a retailer to credit')),
      );
      return;
    }

    if (!_formKey.currentState!.validate() || _enteredAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid credit amount (> ₹0)')),
      );
      return;
    }

    final amountStr = CurrencyFormatter.fromPaise((_enteredAmount * 100).toInt());
    final retailerName = _selectedRetailer!['name'] ?? 'Retailer';

    // Show Confirmation Dialog (Requirement 3)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppColors.primaryBlue),
            SizedBox(width: 10),
            Text('Confirm Wallet Credit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credit $amountStr to this retailer?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _confirmRow('Retailer', retailerName),
                  _confirmRow('Current Balance', CurrencyFormatter.fromPaise((_currentBalance * 100).toInt())),
                  _confirmRow('Credit Amount', '+$amountStr', isGreen: true),
                  const Divider(),
                  _confirmRow('New Balance', CurrencyFormatter.fromPaise((_newBalance * 100).toInt()), isBold: true),
                  if (_remarkController.text.trim().isNotEmpty)
                    _confirmRow('Remark', _remarkController.text.trim()),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Credit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final refId = 'ADM_CREDIT_${DateTime.now().millisecondsSinceEpoch}';

      final response = await apiClient.post<Map<String, dynamic>>(
        '/admin/wallet/credit',
        data: {
          'retailerUserId': _selectedRetailer!['id'],
          'amountRupees': _enteredAmount,
          'remark': _remarkController.text.trim().isEmpty ? 'Initial operational wallet funding' : _remarkController.text.trim(),
          'referenceId': refId,
        },
        fromJson: (json) => json as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final newBalRupees = (data['newBalanceRupees'] as num?)?.toDouble() ?? _newBalance;

        // Show Success BottomSheet Receipt
        if (mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Wallet Credit Successful!',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$amountStr credited to $retailerName',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _confirmRow('Retailer', retailerName),
                        _confirmRow('Retailer ID', _selectedRetailer!['retailerId'] ?? ''),
                        _confirmRow('Previous Balance', CurrencyFormatter.fromPaise((_currentBalance * 100).toInt())),
                        _confirmRow('Credit Amount', '+$amountStr', isGreen: true),
                        _confirmRow('New Balance', CurrencyFormatter.fromPaise((newBalRupees * 100).toInt()), isBold: true),
                        _confirmRow('Reference ID', data['referenceId'] ?? refId),
                        _confirmRow('Date & Time', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Done',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resetForm();
                    },
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message.isNotEmpty ? response.message : 'Credit failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to credit wallet: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedRetailer = null;
      _amountController.clear();
      _remarkController.clear();
    });
    _searchRetailers('');
  }

  Widget _confirmRow(String label, String value, {bool isGreen = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isGreen ? AppColors.success : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Admin Wallet Credit',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Search & Select Retailer Section ─────────────────────
              Text(
                '1. Search & Select Retailer',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _searchController,
                label: 'Search Retailer',
                hint: 'Enter name, phone, or retailer ID...',
                prefixIcon: Icons.search,
                onChanged: (val) => _searchRetailers(val),
              ),
              const SizedBox(height: AppSpacing.sm),

              if (_isSearching)
                const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
              else if (_retailers.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No retailers found', style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _retailers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = _retailers[index];
                      final isSelected = _selectedRetailer?['id'] == r['id'];
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.primaryBlueLight.withValues(alpha: 0.15),
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.primaryBlue : AppColors.background,
                          child: Text(
                            (r['name'] as String? ?? 'R')[0].toUpperCase(),
                            style: TextStyle(color: isSelected ? Colors.white : AppColors.primaryBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          r['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text('${r['retailerId']} • ${r['phone']}', style: const TextStyle(fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.fromPaise(((r['availableRupees'] ?? 0.0) * 100).toInt()),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                            ),
                            const Text('Balance', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                          ],
                        ),
                        onTap: () => _selectRetailer(r),
                      );
                    },
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),

              // ─── Retailer Wallet Details Card ─────────────────────────
              if (_selectedRetailer != null) ...[
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedRetailer!['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlueLight.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _selectedRetailer!['retailerId'] ?? '',
                              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current Wallet Balance:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text(
                            CurrencyFormatter.fromPaise((_currentBalance * 100).toInt()),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ─── Credit Details Form ──────────────────────────────────
              Text(
                '2. Enter Funding Details',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),

              AppTextField(
                controller: _amountController,
                label: 'Credit Amount (₹)',
                hint: 'e.g. 1000',
                prefixIcon: Icons.currency_rupee,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final amt = double.tryParse(val.trim());
                  if (amt == null || amt <= 0) return 'Enter valid amount > 0';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.sm),

              AppTextField(
                controller: _remarkController,
                label: 'Remark / Reason (Optional)',
                hint: 'e.g. Initial operational wallet funding',
                prefixIcon: Icons.notes,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ─── Balance Calculation Preview (Requirement 3) ─────────
              if (_selectedRetailer != null && _enteredAmount > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transaction Calculation Preview',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 12),
                      _confirmRow('Retailer:', _selectedRetailer!['name'] ?? ''),
                      _confirmRow('Current Balance:', CurrencyFormatter.fromPaise((_currentBalance * 100).toInt())),
                      _confirmRow('Credit Amount:', '+${CurrencyFormatter.fromPaise((_enteredAmount * 100).toInt())}', isGreen: true),
                      const Divider(),
                      _confirmRow(
                        'New Balance:',
                        CurrencyFormatter.fromPaise((_newBalance * 100).toInt()),
                        isBold: true,
                        isGreen: true,
                      ),
                      if (_remarkController.text.trim().isNotEmpty)
                        _confirmRow('Remark:', _remarkController.text.trim()),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // ─── Confirm & Submit Button ──────────────────────────────
              AppButton(
                label: 'Confirm Wallet Credit',
                prefixIcon: Icons.add_card,
                isLoading: _isSubmitting,
                onPressed: (_selectedRetailer != null && _enteredAmount > 0) ? _handleCreditSubmit : null,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
