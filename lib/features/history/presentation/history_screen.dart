import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_skeleton.dart';
import 'history_providers.dart';
import '../../wallet/domain/models/wallet_transaction.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final String? txnId;
  const HistoryScreen({super.key, this.txnId});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _selectedFilter = 'All';
  bool _isSearchActive = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Recharge', 'Wallet', 'Commission', 'Bills', 'Failed', 'Pending'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<WalletTransaction>> _groupTransactions(List<WalletTransaction> txns) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<WalletTransaction>> groups = {};

    for (var txn in txns) {
      final txnDate = DateTime(txn.completedAt.year, txn.completedAt.month, txn.completedAt.day);
      
      String key;
      if (txnDate == today) {
        key = 'Today • ${DateFormat('dd MMM').format(txnDate)}';
      } else if (txnDate == yesterday) {
        key = 'Yesterday • ${DateFormat('dd MMM').format(txnDate)}';
      } else {
        key = DateFormat('EEEE • dd MMM yyyy').format(txnDate);
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(txn);
    }
    
    return groups;
  }

  List<WalletTransaction> _filterTransactions(List<WalletTransaction> txns) {
    return txns.where((txn) {
      // 1. Apply Type Filter
      bool matchesType = true;
      if (_selectedFilter == 'Recharges') {
        matchesType = txn.serviceType == 'mobile_recharge' || txn.serviceType == 'mobile' || txn.serviceType == 'dth';
      } else if (_selectedFilter == 'Top-ups') {
        matchesType = txn.serviceType == 'wallet_topup';
      } else if (_selectedFilter == 'Commission') {
        matchesType = txn.serviceType == 'commission';
      } else if (_selectedFilter == 'Bills') {
        matchesType = txn.serviceType == 'bbps';
      } else if (_selectedFilter == 'Failed') {
        matchesType = txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed;
      } else if (_selectedFilter == 'Pending') {
        matchesType = txn.status == TransactionStatus.pending;
      }

      if (!matchesType) return false;

      // 2. Apply Search Query
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesId = txn.id.toLowerCase().contains(query);
        final matchesRef = txn.referenceId.toLowerCase().contains(query);
        final matchesCustomer = txn.customerIdentifier.toLowerCase().contains(query);
        
        return matchesId || matchesRef || matchesCustomer;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.txnId != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction Details')),
        body: Center(
          child: Text('Details for ${widget.txnId} (Coming Soon)'),
        ),
      );
    }

    final txnAsync = ref.watch(historyTransactionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Premium subtle background
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(historyTransactionsProvider);
            await ref.read(historyTransactionsProvider.future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
            // ── Premium App Bar ─────────────────────────────────────────
            SliverAppBar(
              backgroundColor: const Color(0xFF1565FF),
              pinned: true,
              elevation: 0,
              expandedHeight: 116,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1565FF), Color(0xFF0A3D91)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 56, left: 16, right: 16),
                      child: !_isSearchActive 
                        ? const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'View all recharge, wallet & commission activities.',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox(),
                    ),
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              titleSpacing: 0,
              title: _isSearchActive
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Search by mobile, ID, ref...',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    )
                  : const Text(
                      'Transaction History',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
              actions: [
                _HeaderActionButton(
                  icon: _isSearchActive ? Icons.close : Icons.search,
                  onTap: () {
                    setState(() {
                      if (_isSearchActive) {
                        _isSearchActive = false;
                        _searchQuery = '';
                        _searchController.clear();
                      } else {
                        _isSearchActive = true;
                      }
                    });
                  },
                ),
                if (!_isSearchActive) ...[
                  const SizedBox(width: 8),
                  _HeaderActionButton(
                    icon: Icons.calendar_today,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Date picker coming soon')),
                      );
                    },
                  ),
                ],
                const SizedBox(width: 16),
              ],
            ),
            
            // ── Segmented Filters ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _filters.map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _PremiumFilterChip(
                          label: filter,
                          isSelected: isSelected,
                          onSelected: () => setState(() => _selectedFilter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            
            // ── Main Content ───────────────────────────────────────────────
            txnAsync.when(
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: List.generate(5, (index) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: ListSkeleton(count: 1),
                    )),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: SizedBox(
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text('Could not load history.', style: AppTextTheme.textTheme.titleMedium),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'Retry',
                          onPressed: () => ref.invalidate(historyTransactionsProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (txns) {
                final filteredTxns = _filterTransactions(txns);

                if (filteredTxns.isEmpty) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: 400,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  )
                                ],
                              ),
                              child: const Icon(Icons.receipt_long, size: 64, color: Color(0xFFCBD5E1)),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No Transactions Found',
                              style: AppTextTheme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty 
                                  ? 'No results match your search.'
                                  : 'Start your first recharge or bill payment.',
                              style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final groupedTxns = _groupTransactions(filteredTxns);
                final todayTxns = txns.where((t) {
                  final tDate = DateTime(t.completedAt.year, t.completedAt.month, t.completedAt.day);
                  final today = DateTime.now();
                  return tDate == DateTime(today.year, today.month, today.day);
                }).toList();

                return MultiSliverList(
                  groupedTxns: groupedTxns, 
                  todayTxns: todayTxns, 
                  showSummary: _selectedFilter == 'All' && _searchQuery.isEmpty
                );
              },
            ),
            
            // ── Bottom Padding ───────────────────────────────────────────────
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    ),
  );
}
}

// ─── MultiSliver Builder ──────────────────────────────────────────────────────

class MultiSliverList extends StatelessWidget {
  final Map<String, List<WalletTransaction>> groupedTxns;
  final List<WalletTransaction> todayTxns;
  final bool showSummary;

  const MultiSliverList({
    super.key, 
    required this.groupedTxns, 
    required this.todayTxns,
    required this.showSummary,
  });

  @override
  Widget build(BuildContext context) {
    final slivers = <Widget>[];

    if (showSummary) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _AnalyticsSummary(todayTxns: todayTxns),
          ),
        ),
      );
    }

    for (final entry in groupedTxns.entries) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
          ),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PremiumHistoryTile(txn: entry.value[index]),
              );
            },
            childCount: entry.value.length,
          ),
        ),
      );
    }

    return SliverMainAxisGroup(slivers: slivers);
  }
}

// ─── Analytics Summary Card ───────────────────────────────────────────────────

class _AnalyticsSummary extends StatelessWidget {
  final List<WalletTransaction> todayTxns;
  const _AnalyticsSummary({required this.todayTxns});

  @override
  Widget build(BuildContext context) {
    int totalCount = todayTxns.length;
    int rechargeVol = 0;
    int commissionVol = 0;
    int topupVol = 0;

    for (var txn in todayTxns) {
      if (txn.status != TransactionStatus.success) continue;
      if (txn.serviceType == 'mobile_recharge' || txn.serviceType == 'mobile' || txn.serviceType == 'dth') {
        rechargeVol += txn.amountPaise;
      } else if (txn.serviceType == 'commission') {
        commissionVol += txn.amountPaise;
      } else if (txn.serviceType == 'wallet_topup') {
        topupVol += txn.amountPaise;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Summary",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryStat(label: 'Transactions', value: totalCount.toString()),
              _SummaryStat(label: 'Recharges', value: CurrencyFormatter.fromPaise(rechargeVol)),
              _SummaryStat(label: 'Commission', value: CurrencyFormatter.fromPaise(commissionVol), valueColor: AppColors.success),
              _SummaryStat(label: 'Wallet Top-up', value: CurrencyFormatter.fromPaise(topupVol)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryStat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

// ─── Premium Filter Chip ──────────────────────────────────────────────────────

class _PremiumFilterChip extends StatelessWidget {
  const _PremiumFilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565FF) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565FF) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF1565FF).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF334155),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─── Premium Transaction Tile ─────────────────────────────────────────────────

class _PremiumHistoryTile extends StatelessWidget {
  const _PremiumHistoryTile({required this.txn});
  final WalletTransaction txn;

  Color get _iconColor {
    if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) {
      return const Color(0xFFDC2626); // Red
    }
    if (txn.status == TransactionStatus.pending) {
      return const Color(0xFFF59E0B); // Orange
    }
    
    final title = txn.transactionTitle.toLowerCase();
    if (title.contains('commission')) return const Color(0xFF10B981); // Green
    if (title.contains('wallet')) return const Color(0xFF8B5CF6); // Purple
    if (title.contains('electricity')) return const Color(0xFFEAB308); // Yellow/Amber
    if (title.contains('water')) return const Color(0xFF0EA5E9); // Light Blue
    if (title.contains('gas')) return const Color(0xFFF97316); // Orange
    if (title.contains('fastag')) return const Color(0xFF00838F); // Teal
    if (title.contains('broadband')) return const Color(0xFF6366F1); // Indigo
    if (title.contains('dth')) return const Color(0xFFF43F5E); // Rose
    if (title.contains('mobile')) return const Color(0xFF3B82F6); // Blue
    if (txn.isCredit) return const Color(0xFF10B981); // Default Credit
    
    return const Color(0xFF3B82F6); // Default Blue
  }

  IconData get _iconData {
    if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) return Icons.error_outline;
    
    final title = txn.transactionTitle.toLowerCase();
    if (title.contains('commission')) return Icons.redeem; // 💰 Commission
    if (title.contains('wallet')) return Icons.account_balance_wallet; // 💳 Wallet
    if (title.contains('electricity')) return Icons.bolt; // ⚡ Electricity
    if (title.contains('water')) return Icons.water_drop; // 💧 Water
    if (title.contains('gas')) return Icons.local_fire_department; // 🔥 Gas
    if (title.contains('fastag')) return Icons.directions_car; // 🚗 FASTag
    if (title.contains('broadband')) return Icons.wifi; // 🌐 Broadband
    if (title.contains('dth')) return Icons.tv; // 📺 DTH
    if (title.contains('mobile')) return Icons.phone_android; // 📱 Mobile
    if (txn.isCredit) return Icons.arrow_downward; // Default Credit
    
    return Icons.receipt_long;
  }
  
  String get _amountStr {
    final amount = CurrencyFormatter.fromPaise(txn.amountPaise);
    if (txn.isCredit) return '+$amount';
    return '-$amount'; 
  }
  
  Color get _amountColor {
    if (txn.status == TransactionStatus.failed || txn.status == TransactionStatus.reversed) {
      return const Color(0xFF64748B); // Grey out failed amounts
    }
    if (txn.isCredit) return const Color(0xFF10B981); // Green
    return const Color(0xFF0F172A); // Dark for debits
  }
  
  Color get _statusColor {
    return switch (txn.status) {
      TransactionStatus.success => const Color(0xFF10B981),
      TransactionStatus.pending => const Color(0xFFF59E0B),
      TransactionStatus.failed || TransactionStatus.reversed => const Color(0xFFDC2626),
    };
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('dd MMM yyyy • hh:mm a').format(txn.completedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            context.pushNamed(
              'transaction-detail',
              pathParameters: {'txnId': txn.id},
              extra: txn,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _iconColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Hero(
                        tag: 'txn_icon_${txn.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Icon(
                            _iconData,
                            size: 22,
                            color: _iconColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    
                    // Center: Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.transactionTitle,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (txn.operatorName.isNotEmpty) ...[
                            Text(
                              txn.operatorName,
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          if (txn.customerIdentifier.isNotEmpty) ...[
                            Text(
                              txn.customerIdentifier,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            timeStr,
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 12,
                            ),
                          ),
                          if (txn.commissionEarnedPaise != null && txn.commissionEarnedPaise! > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Commission +${CurrencyFormatter.fromPaise(txn.commissionEarnedPaise!)}',
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    // Right: Amount & Status
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Hero(
                              tag: 'txn_amount_${txn.id}',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  _amountStr,
                                  style: TextStyle(
                                    color: _amountColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                txn.status.name.toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // Bottom: Reference inline row
                if (txn.referenceId.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Reference',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            txn.referenceId,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: txn.referenceId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Reference copied to clipboard')),
                              );
                            },
                            child: const Icon(Icons.copy, size: 14, color: Color(0xFF3B82F6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}