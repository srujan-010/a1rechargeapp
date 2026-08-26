import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../domain/models/wallet_transaction.dart';
import '../domain/models/wallet_balance.dart';

class WalletStatementScreen extends ConsumerStatefulWidget {
  const WalletStatementScreen({super.key});

  @override
  ConsumerState<WalletStatementScreen> createState() => _WalletStatementScreenState();
}

class _WalletStatementScreenState extends ConsumerState<WalletStatementScreen> {
  final ScrollController _scrollController = ScrollController();
  
  String _selectedType = 'all'; // 'all', 'credits', 'debits'
  int? _selectedDays = 7; // 7, 30, 90, or null for all time

  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  int _currentPage = 1;
  final int _pageSize = 20;

  final List<WalletTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchStatement(isRefresh: false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _errorMessage == null) {
        _fetchStatement(isLoadMore: true);
      }
    }
  }

  Future<void> _fetchStatement({bool isRefresh = false, bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    } else if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
      _errorMessage = null;
    } else {
      setState(() {
        _isLoadingInitial = true;
        _errorMessage = null;
        _currentPage = 1;
        _hasMore = true;
      });
    }

    try {
      final repo = ref.read(walletRepositoryProvider);
      final pageToFetch = isLoadMore ? _currentPage + 1 : 1;
      
      final result = await repo.getStatement(
        page: pageToFetch,
        pageSize: _pageSize,
        type: _selectedType,
        days: _selectedDays,
      ).timeout(const Duration(seconds: 8));

      final fetchedList = result.valueOrNull;

      if (fetchedList != null) {
        setState(() {
          if (isLoadMore) {
            _transactions.addAll(fetchedList);
            _currentPage = pageToFetch;
          } else {
            _transactions.clear();
            _transactions.addAll(fetchedList);
            _currentPage = 1;
          }

          if (fetchedList.length < _pageSize) {
            _hasMore = false;
          }
          _isLoadingInitial = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
          if (!isLoadMore && _transactions.isEmpty) {
            final rawMsg = result.errorOrNull?.message;
            if (rawMsg != null && (rawMsg.contains('Not authorized') || rawMsg.contains('no token') || rawMsg.contains('token failed'))) {
              _errorMessage = 'Session unauthenticated or expired. Please log in again to view your statement.';
            } else {
              _errorMessage = rawMsg ?? 'Unable to load wallet statement. Please check your connection and try again.';
            }
          }
        });
      }
    } catch (e) {
      AppLogger.error('Wallet statement fetch failed: $e', tag: 'WalletStatement');
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _isLoadingMore = false;
          if (!isLoadMore && _transactions.isEmpty) {
            _errorMessage = 'Unable to load wallet statement. Please check your connection and try again.';
          }
        });
      }
    }
  }

  void _onTypeFilterChanged(String type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
      _isLoadingInitial = true;
    });
    _fetchStatement(isRefresh: true);
  }

  void _onDaysFilterChanged(int? days) {
    if (_selectedDays == days) return;
    setState(() {
      _selectedDays = days;
      _isLoadingInitial = true;
    });
    _fetchStatement(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Wallet Statement',
          style: AppTextTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(walletBalanceProvider);
          await _fetchStatement(isRefresh: true);
        },
        color: AppColors.primaryBlue,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // 1. Current Wallet Balance Summary Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _BalanceSummaryCard(balanceAsync: balanceAsync),
              ),
            ),

            // 2. Filters Row (Type & Period)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'All',
                                  isSelected: _selectedType == 'all',
                                  onTap: () => _onTypeFilterChanged('all'),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Credits',
                                  isSelected: _selectedType == 'credits',
                                  onTap: () => _onTypeFilterChanged('credits'),
                                ),
                                const SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Debits',
                                  isSelected: _selectedType == 'debits',
                                  onTap: () => _onTypeFilterChanged('debits'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PeriodDropdown(
                          selectedDays: _selectedDays,
                          onChanged: _onDaysFilterChanged,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // 3. Transactions List / Skeletons / Empty State / Error State
            if (_isLoadingInitial && _transactions.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: SkeletonBox(width: double.infinity, height: 74, borderRadius: 14),
                    ),
                    childCount: 6,
                  ),
                ),
              )
            else if (_errorMessage != null && _transactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 32),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load wallet statement',
                          style: AppTextTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _errorMessage!,
                          style: AppTextTheme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _fetchStatement(isRefresh: true),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_transactions.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 36,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: AppTextTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Your wallet activity will appear here once you add money or make a transaction.',
                            textAlign: TextAlign.center,
                            style: AppTextTheme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < _transactions.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TransactionCard(transaction: _transactions[index]),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: _isLoadingMore
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        );
                      }
                    },
                    childCount: _transactions.length + (_hasMore ? 1 : 0),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 90)), // Bottom nav padding
          ],
        ),
      ),
    );
  }
}

// ─── Compact Balance Summary Card ─────────────────────────────────────────────

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({required this.balanceAsync});
  final AsyncValue<WalletBalance> balanceAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: balanceAsync.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 100, height: 14),
            SizedBox(height: 8),
            SkeletonBox(width: 150, height: 26),
          ],
        ),
        error: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wallet Balance',
              style: AppTextTheme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '₹0.00',
              style: AppTextTheme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        data: (balance) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      'Wallet Balance',
                      style: AppTextTheme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: AppTextTheme.textTheme.labelSmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.fromPaise(balance.balancePaise),
              style: AppTextTheme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Available balance: ${CurrencyFormatter.fromPaise(balance.availablePaise)}',
              style: AppTextTheme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Chip Widget ────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primaryBlue : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.border,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Period Dropdown Widget ───────────────────────────────────────────────────

class _PeriodDropdown extends StatelessWidget {
  const _PeriodDropdown({
    required this.selectedDays,
    required this.onChanged,
  });

  final int? selectedDays;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final Map<int?, String> options = {
      7: 'Last 7 Days',
      30: 'Last 30 Days',
      90: 'Last 90 Days',
      null: 'All Time',
    };

    final String displayLabel = options[selectedDays] ?? 'Last 7 Days';

    return PopupMenuButton<int?>(
      onSelected: onChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => options.entries
          .map(
            (e) => PopupMenuItem<int?>(
              value: e.key,
              child: Text(
                e.value,
                style: TextStyle(
                  fontWeight: selectedDays == e.key ? FontWeight.bold : FontWeight.normal,
                  color: selectedDays == e.key ? AppColors.primaryBlue : AppColors.textPrimary,
                ),
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Transaction Item Card Widget ──────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final bool isCredit = transaction.isCredit;
    final String amountText = isCredit
        ? '+${CurrencyFormatter.fromPaise(transaction.amountPaise)}'
        : '-${CurrencyFormatter.fromPaise(transaction.amountPaise)}';

    final String formattedDate = DateFormat('dd MMM, h:mm a').format(transaction.createdAt);

    final Color iconColor = isCredit ? AppColors.success : AppColors.primaryBlue;
    final Color iconBg = isCredit ? AppColors.successLight : AppColors.primaryBlueLight;
    final IconData iconData = isCredit ? Icons.add : Icons.north_east;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          context.push('${RouteNames.transactionHistory}/detail/${transaction.id}', extra: transaction);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              // Icon Indicator
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Title & Date/Ref
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.transactionTitle,
                      style: AppTextTheme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: AppTextTheme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    if (transaction.referenceId.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ref: ${transaction.referenceId}',
                        style: AppTextTheme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textHint,
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Amount & Status Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: isCredit ? AppColors.success : AppColors.textPrimary,
                    ),
                  ),
                  if (transaction.status == TransactionStatus.pending || transaction.status == TransactionStatus.processing) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transaction.status == TransactionStatus.processing ? 'Processing' : 'Pending',
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ] else if (transaction.status == TransactionStatus.failed) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Failed',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}