import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../commission/presentation/commission_providers.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../recharge/domain/models/recharge_result.dart';
import 'providers/dth_providers.dart';

class DthReceiptScreen extends ConsumerStatefulWidget {
  final RechargeReceipt receipt;

  const DthReceiptScreen({super.key, required this.receipt});

  @override
  ConsumerState<DthReceiptScreen> createState() => _DthReceiptScreenState();
}

class _DthReceiptScreenState extends ConsumerState<DthReceiptScreen> {
  late RechargeReceipt _currentReceipt;
  Timer? _statusPoller;
  int _pollCount = 0;

  @override
  void initState() {
    super.initState();
    _currentReceipt = widget.receipt;

    if (_currentReceipt.status == RechargeStatus.pending ||
        _currentReceipt.status == RechargeStatus.processing) {
      _startStatusPolling();
    }
  }

  @override
  void dispose() {
    _statusPoller?.cancel();
    super.dispose();
  }

  void _startStatusPolling() {
    _statusPoller?.cancel();
    _statusPoller = Timer.periodic(const Duration(seconds: 3), (timer) async {
      _pollCount++;
      if (_pollCount > 10) { // Stop after 30 seconds
        timer.cancel();
        return;
      }

      final repo = ref.read(dthRepositoryProvider);
      final result = await repo.checkDthStatus(_currentReceipt.transactionId);

      result.onSuccess((updatedReceipt) {
        if (mounted) {
          setState(() {
            _currentReceipt = updatedReceipt.copyWith(
              paymentMode: _currentReceipt.paymentMode,
            );
          });

          if (updatedReceipt.status == RechargeStatus.success ||
              updatedReceipt.status == RechargeStatus.failed) {
            timer.cancel();
            
            // Invalidate wallet and history providers to refresh app UI state
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(dthHistoryProvider);
            ref.invalidate(dashboardAnalyticsProvider);
            ref.invalidate(earningsSummaryProvider);
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _currentReceipt.status == RechargeStatus.success;
    final isPending = _currentReceipt.status == RechargeStatus.pending ||
        _currentReceipt.status == RechargeStatus.processing;

    final statusColor = isSuccess
        ? AppColors.success
        : (isPending ? AppColors.warning : AppColors.error);

    final statusIcon = isSuccess
        ? Icons.check_circle_rounded
        : (isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded);

    final statusText = isSuccess
        ? 'DTH RECHARGE SUCCESSFUL'
        : (isPending ? 'RECHARGE PENDING' : 'RECHARGE FAILED');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DTH Receipt'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              ref.read(dthFlowProvider.notifier).reset();
              context.go(RouteNames.dashboard);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            children: [
              // Status Header
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 64),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                statusText,
                style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Verifying status with DTH operator...',
                  style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),

              // Amount Card
              AppCard(
                child: Column(
                  children: [
                    Text(
                      'Recharge Amount',
                      style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      CurrencyFormatter.fromPaise(_currentReceipt.amountPaise),
                      style: AppTextTheme.textTheme.displayMedium?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Transaction Details
              AppCard(
                child: Column(
                  children: [
                    _ReceiptRow(label: 'Subscriber ID', value: _currentReceipt.mobileNumber),
                    const Divider(height: AppSpacing.lg),
                    _ReceiptRow(label: 'DTH Operator', value: _currentReceipt.operatorName),
                    const Divider(height: AppSpacing.lg),
                    _ReceiptRow(label: 'Order ID', value: _currentReceipt.transactionId),
                    if (_currentReceipt.operatorRef != null && _currentReceipt.operatorRef!.isNotEmpty) ...[
                      const Divider(height: AppSpacing.lg),
                      _ReceiptRow(label: 'Operator Ref', value: _currentReceipt.operatorRef!),
                    ],
                    const Divider(height: AppSpacing.lg),
                    _ReceiptRow(label: 'Payment Method', value: _currentReceipt.paymentMode),
                    const Divider(height: AppSpacing.lg),
                    _ReceiptRow(
                      label: 'Date & Time',
                      value: _currentReceipt.timestamp.toString().substring(0, 19),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Action Buttons
              AppButton(
                label: 'Done',
                onPressed: () {
                  ref.read(dthFlowProvider.notifier).reset();
                  context.go(RouteNames.dashboard);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextTheme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTextTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
