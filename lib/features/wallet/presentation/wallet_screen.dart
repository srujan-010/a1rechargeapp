import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../history/presentation/history_providers.dart';
import '../domain/models/wallet_transaction.dart';
import '../domain/models/wallet_balance.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  String _selectedTab = 'All';
  final List<String> _tabs = ['All', 'Wallet', 'Commission', 'Recharge', 'Settlement'];

  List<WalletTransaction> _filterTransactions(List<WalletTransaction> txns) {
    if (_selectedTab == 'All') return txns;
    return txns.where((txn) {
      if (_selectedTab == 'Wallet') {
        return txn.serviceType == 'wallet_topup';
      } else if (_selectedTab == 'Commission') {
        return txn.serviceType == 'commission';
      } else if (_selectedTab == 'Recharge') {
        return txn.serviceType == 'mobile_recharge' || txn.serviceType == 'mobile' || txn.serviceType == 'dth';
      } else if (_selectedTab == 'Settlement') {
        return txn.serviceType == 'settlement'; // Not strictly present yet, but future-proof
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final analyticsAsync = ref.watch(dashboardAnalyticsProvider('today'));
    final txnsAsync = ref.watch(historyTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ─── Header ───────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wallet',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
                Text(
                  'Manage your wallet & settlements',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history, color: AppColors.textPrimary),
                onPressed: () => context.push(RouteNames.transactionHistory),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
                onPressed: () => context.push(RouteNames.notifications),
              ),
            ],
          ),

          // ─── Balance Card ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: balanceAsync.when(
                loading: () => const SkeletonBox(height: 200, width: double.infinity, borderRadius: 24),
                error: (e, _) => const _ErrorCard(message: 'Failed to load balance'),
                data: (balance) => _PremiumWalletCard(balance: balance),
              ),
            ),
          ),

          // ─── Quick Actions ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: const _QuickActionsRow(),
            ),
          ),

          // ─── Today's Summary ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Summary",
                    style: AppTextTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  analyticsAsync.when(
                    loading: () => const Row(
                      children: [
                        Expanded(child: SkeletonBox(height: 100, width: double.infinity)),
                        SizedBox(width: 12),
                        Expanded(child: SkeletonBox(height: 100, width: double.infinity)),
                      ],
                    ),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (analytics) => _SummaryCards(analytics: analytics),
                  ),
                ],
              ),
            ),
          ),

          // ─── Monthly Analytics Mini Chart ─────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: _MiniAnalyticsChart(),
            ),
          ),

          // ─── Wallet Activity Tabs ─────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyTabBarDelegate(
              child: Container(
                color: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: _tabs.map((tab) {
                      final isSelected = _selectedTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedTab = tab),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primaryBlue : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryBlue : AppColors.border,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              tab,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          // ─── Transaction List ─────────────────────────────────────
          txnsAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: ListSkeleton(count: 5),
              ),
            ),
            error: (e, _) => const SliverToBoxAdapter(
              child: Center(child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('Failed to load transactions'),
              )),
            ),
            data: (txns) {
              final filtered = _filterTransactions(txns);
              if (filtered.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: EmptyStateWidget(
                      title: 'No wallet activity yet.',
                      description: 'Top up your wallet to start recharging.',
                      ctaLabel: 'Add Money',
                      onCtaTap: () => context.push(RouteNames.walletTopup),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _WalletTransactionTile(txn: filtered[index]);
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
    );
  }
}

// ─── Component: Premium Wallet Card ───────────────────────────────────────
class _PremiumWalletCard extends StatelessWidget {
  final WalletBalance balance;
  const _PremiumWalletCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1565FF), Color(0xFF0038A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565FF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background circles for glass effect feeling
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        balance.walletId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.fromPaise(balance.availablePaise),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Updated ${DateFormat('hh:mm a').format(balance.lastUpdated)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Breakdowns
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _BalanceItem(
                        label: 'Ledger',
                        amount: balance.ledgerBalancePaise,
                      ),
                      Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
                      _BalanceItem(
                        label: 'Hold',
                        amount: balance.onHoldPaise,
                      ),
                      Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
                      _BalanceItem(
                        label: 'Pending',
                        amount: balance.pendingSettlementPaise,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final int amount;
  const _BalanceItem({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.fromPaise(amount),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── Component: Quick Actions ─────────────────────────────────────────────
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.add,
          label: 'Add Money',
          onTap: () => context.push(RouteNames.walletTopup),
        ),
        _ActionButton(
          icon: Icons.description_outlined,
          label: 'Statement',
          onTap: () => context.push(RouteNames.walletStatement),
        ),
        _ActionButton(
          icon: Icons.receipt_long_outlined,
          label: 'Ledger',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ledger view coming soon')));
          },
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          )
        ],
      ),
    );
  }
}

// ─── Component: Today's Summary ──────────────────────────────────────────
class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> analytics;
  const _SummaryCards({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final current = analytics['currentPeriod'] as Map<String, dynamic>? ?? {};
    final rechargePaise = current['recharge'] as int? ?? 0;
    final commissionPaise = current['commission'] as int? ?? 0;
    final txnsCount = current['transactions'] as int? ?? 0;

    return Row(
      children: [
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.show_chart, color: AppColors.primaryBlue, size: 20),
                const SizedBox(height: 8),
                Text(
                  'Today\'s Recharge',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.fromPaise(rechargePaise),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star_border, color: AppColors.success, size: 20),
                const SizedBox(height: 8),
                Text(
                  'Commission',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.fromPaise(commissionPaise),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sync_alt, color: Colors.purple, size: 20),
                const SizedBox(height: 8),
                Text(
                  'Txns / Pending',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '$txnsCount / 0',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Component: Mini Analytics Chart ──────────────────────────────────────
class _MiniAnalyticsChart extends StatelessWidget {
  const _MiniAnalyticsChart();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Wallet Usage',
            style: AppTextTheme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final randomHeight = 20.0 + (Random().nextInt(60));
              final isToday = index == 6;
              return Column(
                children: [
                  Container(
                    width: 24,
                    height: randomHeight,
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.primaryBlue : AppColors.primaryBlueLight.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ['M','T','W','T','F','S','S'][index],
                    style: TextStyle(
                      fontSize: 10,
                      color: isToday ? AppColors.primaryBlue : AppColors.textHint,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  )
                ],
              );
            }),
          )
        ],
      ),
    );
  }
}

// ─── Component: Wallet Transaction Tile ───────────────────────────────────
class _WalletTransactionTile extends StatelessWidget {
  final WalletTransaction txn;
  const _WalletTransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final timeStr = DateFormat('dd MMM hh:mm a').format(txn.completedAt);
    
    // Determine Color based on premium rules
    Color getAccentColor() {
      if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) return AppColors.error;
      if (txn.serviceType == 'wallet_topup') return AppColors.primaryBlue;
      if (txn.serviceType == 'commission') return AppColors.success;
      if (txn.isCredit) return AppColors.success;
      return AppColors.textPrimary;
    }
    
    IconData getIcon() {
      if (txn.serviceType == 'wallet_topup') return Icons.account_balance_wallet;
      if (txn.serviceType == 'commission') return Icons.star;
      if (txn.serviceType == 'mobile_recharge' || txn.serviceType == 'mobile' || txn.serviceType == 'dth') return Icons.phone_android;
      if (txn.serviceType == 'bbps') return Icons.receipt_long;
      return Icons.swap_horiz;
    }

    String getTitle() {
      return txn.transactionTitle;
    }
    
    String getSubtitle() {
      if (txn.serviceType == 'wallet_topup') return 'UPI';
      if (txn.customerIdentifier.isNotEmpty) return txn.customerIdentifier;
      if (txn.referenceId.isNotEmpty) return 'Ref: ${txn.referenceId}';
      return 'Completed';
    }

    final accentColor = getAccentColor();
    final amountFormatted = CurrencyFormatter.fromPaise(txn.amountPaise);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(getIcon(), color: accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        getTitle(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getSubtitle(),
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'}$amountFormatted',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: TextStyle(color: AppColors.textHint, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            
            // Show commission sub-transaction if present and this is a recharge
            if (txn.commissionEarnedPaise != null && txn.commissionEarnedPaise! > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Commission Earned',
                      style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '+${CurrencyFormatter.fromPaise(txn.commissionEarnedPaise!)}',
                      style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.errorLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.error)),
      ),
    );
  }
}

// ─── Sticky Header Delegate ───────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _StickyTabBarDelegate({required this.child});

  @override
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}