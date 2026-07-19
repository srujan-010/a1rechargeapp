import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

class WalletTopupScreen extends ConsumerStatefulWidget {
  const WalletTopupScreen({super.key});

  @override
  ConsumerState<WalletTopupScreen> createState() => _WalletTopupScreenState();
}

class _WalletTopupScreenState extends ConsumerState<WalletTopupScreen> with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _focusNode = FocusNode();
  
  int _amount = 0;
  bool _isLoading = false;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    final clean = val.replaceAll(RegExp(r'[^\d]'), '');
    final num = int.tryParse(clean) ?? 0;
    
    if (num > 100000) {
      _shakeController.forward(from: 0);
      return;
    }

    setState(() {
      _amount = num;
      if (num > 0) {
        final formatted = NumberFormat('#,##,###').format(num);
        if (_amountController.text != formatted) {
          _amountController.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
        }
      } else {
        _amountController.text = '';
      }
    });
  }

  void _addQuickAmount(int amountToAdd) {
    final newAmount = _amount + amountToAdd;
    
    if (newAmount > 100000) {
      _shakeController.forward(from: 0);
      return;
    }
    
    _onAmountChanged(newAmount.toString());
  }

  void _onProceed() async {
    if (_amount < 10 || _amount > 100000) return;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    
    if (!mounted) return;

    final amountPaise = _amount * 100;
    final repo = ref.read(walletRepositoryProvider);
    final result = await repo.topup(amountPaise);

    if (!mounted) return;

    result.onSuccess((balance) {
      ref.invalidate(walletBalanceProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(earningsSummaryProvider);

      context.go(RouteNames.dashboard);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Top-up successful! New balance: ${CurrencyFormatter.fromPaise(balance.availablePaise)}'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }).onFailure((error) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Top-up failed: ${error.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isValid = _amount >= 10 && _amount <= 100000;
    final balanceAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Money', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: Color(0xFF1E293B))),
            Text('Top up your wallet securely.', style: TextStyle(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        bottomOpacity: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Balance Pill ──
                      Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Wallet Balance',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            balanceAsync.when(
                              data: (b) => Text(
                                CurrencyFormatter.fromPaise(b.availablePaise),
                                style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              loading: () => Container(width: 60, height: 16, color: const Color(0xFFE2E8F0)),
                              error: (_, __) => const Text('Error', style: TextStyle(color: Color(0xFF64748B))),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ── Amount Input ──
                      AnimatedBuilder(
                        animation: _shakeController,
                        builder: (context, child) {
                          final shake = 4.0 * math.sin(_shakeController.value * 4 * math.pi);
                          return Transform.translate(
                            offset: Offset(shake, 0),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            const Text(
                              'Amount',
                              style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 240,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '₹',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
                                      color: _amount > 0 ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IntrinsicWidth(
                                    child: TextField(
                                      controller: _amountController,
                                      focusNode: _focusNode,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(color: const Color(0xFFCBD5E1).withValues(alpha: 0.5)),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      onChanged: _onAmountChanged,
                                      cursorColor: const Color(0xFF1565FF),
                                      cursorWidth: 2,
                                      cursorHeight: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Quick Amounts ──
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          _QuickAmountTile(amount: 500, selectedAmount: _amount, onTap: () => _addQuickAmount(500)),
                          _QuickAmountTile(amount: 1000, selectedAmount: _amount, onTap: () => _addQuickAmount(1000)),
                          _QuickAmountTile(amount: 2000, selectedAmount: _amount, onTap: () => _addQuickAmount(2000)),
                          _QuickAmountTile(amount: 5000, selectedAmount: _amount, onTap: () => _addQuickAmount(5000)),
                          _QuickAmountTile(amount: 10000, selectedAmount: _amount, onTap: () => _addQuickAmount(10000)),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ── Payment Method ──
                      Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'UPI • Cards • Net Banking',
                                    style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF1E293B), fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Powered by Razorpay',
                                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      // ── Security Badges ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 14, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          const Text(
                            'Secure Payments',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('•', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                          ),
                          const Text(
                            'PCI DSS Compliant',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // ── Sticky Proceed Button ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: const Color(0xFFF1F5F9), width: 1)),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isValid ? 1.0 : 0.6,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isValid && !_isLoading ? _onProceed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565FF),
                      disabledBackgroundColor: const Color(0xFF1565FF).withValues(alpha: 0.5),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text('Continue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountTile extends StatelessWidget {
  final int amount;
  final int selectedAmount;
  final VoidCallback onTap;

  const _QuickAmountTile({required this.amount, required this.selectedAmount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAmount == amount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1565FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF1565FF) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '₹${NumberFormat('#,##,###').format(amount)}',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}