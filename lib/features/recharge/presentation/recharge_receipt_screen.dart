import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/models/recharge_result.dart';
import '../../history/presentation/history_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import 'recharge_providers.dart';

class RechargeReceiptScreen extends ConsumerStatefulWidget {
  const RechargeReceiptScreen({super.key, required this.receipt});
  final RechargeReceipt receipt;

  @override
  ConsumerState<RechargeReceiptScreen> createState() => _RechargeReceiptScreenState();
}

class _RechargeReceiptScreenState extends ConsumerState<RechargeReceiptScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 0.8, curve: Curves.easeIn)),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic)),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = widget.receipt.isSuccess;
    final bool hasCommission = (widget.receipt.commission ?? 0) > 0;
    
    final String amountStr = CurrencyFormatter.fromPaise(widget.receipt.amountPaise);
    final String commissionStr = hasCommission 
        ? '+${CurrencyFormatter.fromPaise(widget.receipt.commission!)}' 
        : 'Not Available for this service';

    final String walletDebitedStr = widget.receipt.walletDebitedPaise != null
        ? CurrencyFormatter.fromPaise(widget.receipt.walletDebitedPaise!)
        : (hasCommission 
            ? CurrencyFormatter.fromPaise(widget.receipt.amountPaise - widget.receipt.commission!)
            : amountStr);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _exitReceipt();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + AppSpacing.xl,
              bottom: AppSpacing.xl,
              left: AppSpacing.md,
              right: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSuccess ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFEF4444).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess ? Icons.check_rounded : Icons.close_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      Text(
                        isSuccess ? 'Recharge Successful' : 'Recharge Failed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSuccess ? '$amountStr ${widget.receipt.operatorName} Recharge Completed' : widget.receipt.failureReason ?? 'Transaction failed',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: isSuccess ? 22 : 14,
                          fontWeight: isSuccess ? FontWeight.w800 : FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isSuccess && hasCommission) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Commission Earned',
                                style: TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                commissionStr,
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Credited to Wallet',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Receipt Body
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Branding Header
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlueLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.flash_on, color: AppColors.primaryBlue, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'A1 Recharge',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primaryBlue,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'Retailer Receipt',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        
                        // Recharge Details
                        const _SectionHeader(title: 'Recharge Details'),
                        _ReceiptRow(label: 'Mobile Number', value: widget.receipt.mobileNumber, isBold: true),
                        _ReceiptRow(label: 'Operator', value: widget.receipt.operatorName),
                        if (widget.receipt.circle != null)
                          _ReceiptRow(label: 'Circle', value: widget.receipt.circle!),
                        if (widget.receipt.validity != null)
                          _ReceiptRow(label: 'Validity', value: widget.receipt.validity!),
                        
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        // Payment Details
                        const _SectionHeader(title: 'Payment Details'),
                        _ReceiptRow(
                          label: 'Recharge Amount',
                          value: amountStr,
                          isBold: true,
                        ),
                        _ReceiptRow(
                          label: 'Wallet Debited',
                          value: walletDebitedStr,
                        ),
                        _ReceiptRow(
                          label: 'Commission Earned',
                          value: commissionStr,
                          valueColor: hasCommission ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          isBold: hasCommission,
                        ),
                        if (widget.receipt.walletBalancePaise != null)
                          _ReceiptRow(
                            label: 'Wallet Balance After',
                            value: CurrencyFormatter.fromPaise(widget.receipt.walletBalancePaise!),
                          ),
                        _ReceiptRow(label: 'Payment Method', value: widget.receipt.paymentMode),
                        
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),

                        // Transaction Reference
                        const _SectionHeader(title: 'Transaction Reference'),
                        _ReceiptRow(label: 'Transaction ID', value: widget.receipt.transactionId, showCopy: true),
                        if (widget.receipt.operatorRef != null)
                          _ReceiptRow(label: 'Operator Ref', value: widget.receipt.operatorRef!, showCopy: true),
                        _ReceiptRow(
                          label: 'Date & Time',
                          value: DateFormat('dd MMM yyyy, hh:mm a').format(widget.receipt.timestamp),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Sticky Footer Actions
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      offset: const Offset(0, -4),
                      blurRadius: 8,
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: 'Done',
                        onPressed: _exitReceipt,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Download coming soon')),
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                          label: const Text(
                            'Download',
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                        TextButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Share coming soon')),
                            );
                          },
                          icon: const Icon(Icons.share_rounded, size: 18, color: Color(0xFF64748B)),
                          label: const Text(
                            'Share',
                            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  void _exitReceipt() {
    // Invalidate history, dashboard, wallet, and recent contacts to force fresh data
    ref.invalidate(historyTransactionsProvider);
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(dashboardAnalyticsProvider('today'));
    ref.invalidate(earningsSummaryProvider);
    ref.invalidate(recentContactsProvider);

    context.go(RouteNames.dashboard);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
    this.showCopy = false,
  });
  
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;
  final bool showCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? const Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                if (showCopy)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
                      },
                      child: const Icon(Icons.copy_all, size: 16, color: AppColors.primaryBlue),
                    ),
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
