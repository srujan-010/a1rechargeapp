import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/operator_formatter.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/startup_tracker.dart';
import '../../../core/utils/logger.dart';
import '../../../core/services/background_startup_service.dart';
import '../../../features/wallet/domain/models/wallet_transaction.dart';
import '../../notifications/presentation/notifications_providers.dart';
import '../../wallet_mpin/providers/wallet_mpin_provider.dart';
import '../../commission/presentation/commission_providers.dart';
import '../../commission/domain/models/commission_slab.dart';
import 'dashboard_providers.dart';
import '../../personal/presentation/personal_providers.dart';
import '../../history/presentation/history_providers.dart';
import '../../recharge/presentation/recharge_providers.dart';
import '../../recharge/domain/models/operator.dart';
import '../../recharge/domain/models/circle.dart';
import 'package:flutter/services.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupTracker.instance.markDashboardDisplayed();
      BackgroundStartupService.instance.runTasks(ref);
    });
  }

  Future<void> _refresh() async {
    final userSession = ref.read(sessionProvider).valueOrNull;
    final isPersonal = userSession?.isPersonal ?? false;

    if (isPersonal) {
      ref.invalidate(personalSavingsProvider);
      ref.invalidate(personalBenefitsProvider);
      ref.invalidate(currentPlanProvider);
      ref.invalidate(lastRechargeProvider);
      ref.invalidate(frequentNumbersProvider);
      ref.invalidate(historyTransactionsProvider);
      await Future.wait([
        ref.read(personalSavingsProvider.future).catchError((_) => PersonalSavings(lifetimeSavings: 0, monthlySavings: 0, previousMonthSavings: 0, totalCompletedCount: 0)),
        ref.read(currentPlanProvider.future).catchError((_) => null),
        ref.read(lastRechargeProvider.future).catchError((_) => null),
      ]).catchError((_) => <Object>[]);
      return;
    }

    ref.invalidate(walletBalanceProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(earningsSummaryProvider);
    ref.invalidate(activeCommissionSlabsProvider);
    // Wait for all to complete
    await Future.wait([
      ref.read(walletBalanceProvider.future).catchError((Object error) => throw error),
      ref.read(recentTransactionsProvider.future).catchError((Object error) => throw error),
      ref.read(activeCommissionSlabsProvider.future).catchError((Object error) => <CommissionSlab>[]),
    ]).catchError((Object error) => <Object>[]);
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info('Dashboard Build Started', tag: 'Dashboard');
    final sessionAsync = ref.watch(sessionProvider);
    final user = sessionAsync.valueOrNull;
    final mpinState = ref.watch(walletMpinProvider);
    AppLogger.info('Dashboard Build Finished: User=${user?.name ?? "Guest/Loading"}', tag: 'Dashboard');

    final isPersonal = user?.isPersonal ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primaryBlue,
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _DashboardAppBar(user: user),
              ),

              // ── RETAILER ONLY: MPIN Prompt ──
              if (!isPersonal && mpinState.walletMpinConfigured == false)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.pagePadding, right: AppSpacing.pagePadding, top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded, color: AppColors.error),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Secure your wallet by creating a 6-digit MPIN.',
                              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.pushNamed(RouteNames.createMpin),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: AppColors.error,
                            ),
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── RETAILER ONLY: Wallet Balance Card & Stats ──
              if (!isPersonal) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: _WalletBalanceCard(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: _TodayStatsRow(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              // ── PERSONAL ONLY: Lifetime Savings, Current Plan & Last Recharge ──
              if (isPersonal) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: _PersonalSavingsCard(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: _PersonalCurrentPlanCard(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: _PersonalLastRechargeCard(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],

              // ── Quick Services Grid ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recharge & Pay Bills',
                        style: AppTextTheme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      const _QuickServicesGrid(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── PERSONAL ONLY: Frequent Numbers & Benefits Banner ──
              if (isPersonal) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: _PersonalFrequentNumbersRow(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: const _PersonalBenefitsBanner(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              // ── RETAILER ONLY: Commission Preview Card ──
              if (!isPersonal) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: const _CommissionPreviewCard(),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              // ── Recent Transactions ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Transactions', style: AppTextTheme.textTheme.titleLarge),
                      TextButton(
                        onPressed: () => context.go(RouteNames.transactionHistory),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _RecentTransactionsList(),
              ),

              if (isPersonal) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: const _WhyA1RechargeCard(),
                  ),
                ),
              ],
              
              const SliverToBoxAdapter(child: SizedBox(height: 100)), // padding for floating bottom nav
            ],
          ),
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _DashboardAppBar extends ConsumerWidget {
  const _DashboardAppBar({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsCount = ref.watch(unreadNotificationsCountProvider);
    final String retailerName = (user?.name != null && user!.name.toString().trim().isNotEmpty)
        ? user!.name.toString()
        : 'Retailer';
    final String initial = retailerName.isNotEmpty ? retailerName[0].toUpperCase() : 'R';
    final String retailerId = (user?.retailerId != null && user!.retailerId.toString().trim().isNotEmpty)
        ? user!.retailerId.toString()
        : '--';

    print('\n========== HOME WIDGET DATA ==========');
    print('Home Retailer Name: "$retailerName"');
    print('Home Retailer ID: "$retailerId"');
    print('======================================\n');

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, 
          12,
          AppSpacing.pagePadding, 
          12,
        ),
        constraints: const BoxConstraints(minHeight: 88),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Avatar with Gradient
            GestureDetector(
              onTap: () => context.pushNamed('profile'),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: initial.isNotEmpty
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : const Icon(Icons.person, color: Colors.white, size: 24),
                    ),
                  ),
                  if (user?.isVerified == true)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            
            // Greeting & Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '👋 ${_greeting()},',
                    style: AppTextTheme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (retailerName.isNotEmpty)
                    Text(
                      retailerName,
                      style: AppTextTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Container(
                      width: 120,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),

            // Right side: Retailer ID Pill & Notifications
            Row(
              children: [
                if (retailerId.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: retailerId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied ID: $retailerId'),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: user?.isPersonal == true ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: user?.isPersonal == true ? const Color(0xFFCBD5E1) : const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            user?.isPersonal == true ? Icons.person_rounded : Icons.storefront_rounded,
                            size: 14,
                            color: user?.isPersonal == true ? const Color(0xFF475569) : AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user?.isPersonal == true ? 'Personal' : retailerId,
                            style: TextStyle(
                              color: user?.isPersonal == true ? const Color(0xFF475569) : AppColors.primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (user?.isPersonal != true) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryBlue),
                          ],
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.sm),
                
                // Notifications Button
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () => context.pushNamed('notifications'),
                          child: const Icon(Icons.notifications_none_rounded, color: AppColors.textPrimary, size: 22),
                        ),
                      ),
                    ),
                    if (notificationsCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Text(
                            notificationsCount > 99 ? '99+' : '$notificationsCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }
}

// ─── Wallet Balance Card ──────────────────────────────────────────────────────

class _WalletBalanceCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_WalletBalanceCard> createState() => _WalletBalanceCardState();
}

class _WalletBalanceCardState extends ConsumerState<_WalletBalanceCard> {
  bool _hideBalance = false;

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(walletBalanceProvider);

    return balanceAsync.when(
      loading: () => const WalletCardSkeleton(),
      error: (e, _) => _buildErrorCard(),
      data: (balance) => _buildCard(balance),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available Balance', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: AppSpacing.sm),
          const Text('Unable to load', style: TextStyle(color: Colors.white, fontSize: 24)),
          TextButton(
            onPressed: () => ref.invalidate(walletBalanceProvider),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(dynamic balance) {
    final available = CurrencyFormatter.fromPaise(balance.availablePaise);
    final hold = CurrencyFormatter.fromPaise(balance.onHoldPaise);
    final isHidden = _hideBalance;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF1565FF), Color(0xFF0A4CC7)], // Premium blue
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Large Balance
          Text(
            isHidden ? '••••••' : available,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          
          // Hold Balance & Available Text Glass row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BalanceStat(
                    label: 'Available',
                    value: isHidden ? '••••' : available,
                  ),
                ),
                Container(width: 1, height: 24, color: Colors.white.withOpacity(0.2)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _BalanceStat(
                      label: 'Hold',
                      value: isHidden ? '••••' : hold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push(RouteNames.walletTopup),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Add Money',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => context.go(RouteNames.transactionHistory),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text(
                    'Statement',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── Today's Stats ────────────────────────────────────────────────────────────

class _TodayStatsRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsAsync = ref.watch(earningsSummaryProvider);

    return earningsAsync.when(
      loading: () => Row(
        children: List.generate(3, (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 8.0 : 0),
            child: const SkeletonBox(width: double.infinity, height: 85, borderRadius: AppRadius.md),
          ),
        )),
      ),
      error: (err, stack) {
        AppLogger.warning('Dashboard summary load error: $err', tag: 'DashboardScreen');
        final defaultStats = [
          const _StatData(
            label: "Today's Recharge",
            value: '₹0.00',
            icon: Icons.bolt,
            color: AppColors.primaryBlue,
            bgColor: AppColors.primaryBlueLight,
          ),
          const _StatData(
            label: 'Commission',
            value: '₹0.00',
            icon: Icons.percent,
            color: AppColors.success,
            bgColor: AppColors.successLight,
          ),
          _StatData(
            label: 'Transactions',
            value: '0',
            icon: Icons.receipt_long,
            color: AppColors.warning,
            bgColor: AppColors.warningLight,
            onTap: () => context.go(RouteNames.transactionHistory),
          ),
        ];

        return Row(
          children: defaultStats.asMap().entries.map((entry) {
            final i = entry.key;
            final stat = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i > 0 ? 8.0 : 0),
                child: _StatCard(data: stat),
              ),
            );
          }).toList(),
        );
      },
      data: (earnings) {
        final stats = [
          _StatData(
            label: "Today's Recharge",
            value: CurrencyFormatter.fromPaise(earnings['todayRechargeAmountPaise'] as int? ?? earnings['todayRechargeAmount'] as int? ?? 0),
            icon: Icons.bolt,
            color: AppColors.primaryBlue,
            bgColor: AppColors.primaryBlueLight,
          ),
          _StatData(
            label: 'Commission',
            value: CurrencyFormatter.fromPaise(earnings['todayCommissionPaise'] as int? ?? earnings['todayCommission'] as int? ?? 0),
            icon: Icons.percent,
            color: AppColors.success,
            bgColor: AppColors.successLight,
          ),
          _StatData(
            label: 'Transactions',
            value: '${earnings['todayTransactions'] ?? 0}',
            icon: Icons.receipt_long,
            color: AppColors.warning,
            bgColor: AppColors.warningLight,
            onTap: () => context.go(RouteNames.transactionHistory),
          ),
        ];

        return Row(
          children: stats.asMap().entries.map((entry) {
            final i = entry.key;
            final stat = entry.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i > 0 ? 8.0 : 0),
                child: _StatCard(data: stat),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: data.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: data.bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(data.icon, size: 16, color: data.color),
                ),
                const SizedBox(height: 10),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  data.label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick Services Grid ──────────────────────────────────────────────────────

class _QuickServicesGrid extends StatelessWidget {
  const _QuickServicesGrid();

  static const _services = [
    _ServiceItem(
      label: 'Prepaid',
      subtitle: 'Mobile',
      icon: Icons.phone_android,
      route: RouteNames.mobileRecharge,
      bgColor: Color(0xFFE3F2FD),
      iconColor: Color(0xFF1E88E5),
    ),
    _ServiceItem(
      label: 'Postpaid',
      subtitle: 'Bills',
      icon: Icons.phone_iphone,
      route: RouteNames.mobileRecharge,
      bgColor: Color(0xFFF3E5F5),
      iconColor: Color(0xFF8E24AA),
    ),
    _ServiceItem(
      label: 'DTH',
      subtitle: 'Recharge',
      icon: Icons.tv,
      route: RouteNames.dthRecharge,
      bgColor: Color(0xFFFFF3E0),
      iconColor: Color(0xFFFB8C00),
    ),
    _ServiceItem(
      label: 'Electricity',
      subtitle: 'Bill Payment',
      icon: Icons.lightbulb_outline,
      route: RouteNames.bbps, // Assuming bbps is handled
      bgColor: Color(0xFFE8F5E9),
      iconColor: Color(0xFF43A047),
      isElectricity: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _services.map((service) {
            return SizedBox(
              width: cardWidth,
              height: 100, // Compact height
              child: _ServiceGridItem(service: service),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.bgColor,
    required this.iconColor,
    this.isElectricity = false,
  });
  final String label;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color bgColor;
  final Color iconColor;
  final bool isElectricity;
}

class _ServiceGridItem extends StatefulWidget {
  const _ServiceGridItem({required this.service});
  final _ServiceItem service;

  @override
  State<_ServiceGridItem> createState() => _ServiceGridItemState();
}

class _ServiceGridItemState extends State<_ServiceGridItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
  );
  late final Animation<double> _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(_controller);

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  void _onTap() {
    if (widget.service.isElectricity) {
      context.push(RouteNames.bbpsStateSelection.replaceAll(':category', 'electricity'));
    } else {
      context.push(widget.service.route);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: _onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _onTap,
              splashColor: widget.service.iconColor.withOpacity(0.08),
              highlightColor: widget.service.iconColor.withOpacity(0.04),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.service.bgColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.service.icon, size: 22, color: widget.service.iconColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.service.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.service.subtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Recent Transactions ──────────────────────────────────────────────────────

class _RecentTransactionsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnAsync = ref.watch(recentTransactionsProvider);

    return txnAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        child: ListSkeleton(count: 3),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: ErrorStateWidget(
          message: 'Could not load recent transactions.',
          onRetry: () => ref.invalidate(recentTransactionsProvider),
          compact: true,
        ),
      ),
      data: (txns) {
        if (txns.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.pagePadding),
            child: EmptyStateWidget(
              title: 'No transactions yet',
              description: 'Your recent transactions will appear here.',
              compact: true,
            ),
          );
        }
        return Column(
          children: txns.take(4).map((txn) => _TransactionTile(txn: txn)).toList(),
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});
  final WalletTransaction txn;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (txn.status) {
      TransactionStatus.success => AppColors.success,
      TransactionStatus.pending || TransactionStatus.processing => AppColors.warning,
      TransactionStatus.failed || TransactionStatus.reversed => AppColors.error,
    };
    
    final customerNumber = txn.customerIdentifier.isNotEmpty ? txn.customerIdentifier : txn.referenceId;
    final dateStr = '${txn.completedAt.day.toString().padLeft(2, '0')}/${txn.completedAt.month.toString().padLeft(2, '0')} • ${txn.completedAt.hour}:${txn.completedAt.minute.toString().padLeft(2, '0')}';

    // UI based on service
    Color iconBgColor = AppColors.background;
    Color iconColor = AppColors.textPrimary;
    IconData? serviceIcon;
    String label = txn.transactionTitle;
    IconData iconData = _getServiceIcon(txn.serviceType);

    if (txn.serviceType == 'wallet_topup') {
      iconBgColor = AppColors.success.withOpacity(0.15);
      iconColor = AppColors.success;
      serviceIcon = Icons.account_balance_wallet;
    } else if (txn.serviceType == 'commission') {
      iconBgColor = Colors.purple.withOpacity(0.15);
      iconColor = Colors.purple;
      serviceIcon = Icons.star;
    } else if (txn.serviceType == 'bbps') {
      iconBgColor = Colors.orange.withOpacity(0.15);
      iconColor = Colors.orange;
      serviceIcon = Icons.lightbulb_outline;
    } else {
      // Recharge or DMT
      iconBgColor = AppColors.primaryBlueLight;
      iconColor = AppColors.primaryBlue;
      // No icon, use initial
    }

    final amountColor = txn.isCredit ? AppColors.success : AppColors.textPrimary;
    final amountSign = txn.isCredit ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 6,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {}, // Can navigate to details in future
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon/Logo
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: serviceIcon != null 
                        ? Icon(serviceIcon, color: iconColor, size: 22)
                        : Icon(iconData, color: iconColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No: $customerNumber',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (txn.commissionEarnedPaise > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Earned +₹${(txn.commissionEarnedPaise / 100).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Amount + Status
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$amountSign₹${(txn.amountPaise / 100).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: amountColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            txn.status.name.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    if (serviceType == 'mobile_recharge' || serviceType == 'dth') {
      return Icons.phone_android;
    } else if (serviceType == 'wallet_topup') {
      return Icons.account_balance_wallet;
    } else if (serviceType == 'dmt') {
      return Icons.send;
    } else if (serviceType == 'commission') {
      return Icons.star;
    } else if (serviceType == 'aeps') {
      return Icons.fingerprint;
    } else if (serviceType == 'bbps') {
      return Icons.receipt_long;
    }
    return Icons.receipt;
  }
}


// ─── Commission Preview Card ──────────────────────────────────────────────────────────

class _CommissionPreviewCard extends ConsumerWidget {
  const _CommissionPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slabsAsync = ref.watch(activeCommissionSlabsProvider);
    final slabs = slabsAsync.valueOrNull ?? [];

    AppLogger.info('Home Dashboard Commission List: count=${slabs.length}', tag: 'Dashboard');

    final previewSlabs = slabs.take(3).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.percent, color: AppColors.success, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  'Commission Chart',
                  style: AppTextTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (slabsAsync.isLoading && slabs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (previewSlabs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Text(
                  'No commissions available',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ...previewSlabs.map((slab) {
              final isFlat = slab.commissionType == 'flat';
              final commissionText = isFlat
                  ? '₹${slab.commissionValue.toStringAsFixed(2)} Flat'
                  : '${slab.commissionValue.toStringAsFixed(2)}%';
              return _CommissionPreviewRow(
                operatorName: slab.operatorName,
                percentage: commissionText,
              );
            }),

          const Divider(height: 1),
          InkWell(
            onTap: () => context.push(RouteNames.commissionSlab),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'View Full Chart',
                      style: TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, color: AppColors.primaryBlue, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionPreviewRow extends StatelessWidget {
  final String operatorName;
  final String percentage;

  const _CommissionPreviewRow({required this.operatorName, required this.percentage});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.background,
                child: Text(
                  operatorName[0],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                operatorName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
              ),
            ],
          ),
          Text(
            percentage,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

// ─── PERSONAL HOME WIDGETS ───────────────────────────────────────────────────

class _PersonalSavingsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savingsAsync = ref.watch(personalSavingsProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: savingsAsync.when(
          data: (s) {
            final hasSavings = s.lifetimeSavings > 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.savings_outlined, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('Your Savings', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push(RouteNames.personalBenefits),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('View Savings →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (hasSavings) ...[
                  Text(
                    '💰 You\'ve Saved ${CurrencyFormatter.fromRupees(s.lifetimeSavings)}',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text('Earn on eligible recharges & bill payments', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SavingsStat(label: 'This Month', amount: CurrencyFormatter.fromRupees(s.monthlySavings)),
                      _SavingsStat(label: 'Last Month', amount: CurrencyFormatter.fromRupees(s.previousMonthSavings)),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Start earning with your first recharge 💙',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Earn commission & savings automatically on every mobile, DTH, and bill payment.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                ],
              ],
            );
          },
          loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.white))),
          error: (err, _) => const Text('Savings unavailable', style: TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }
}

class _SavingsStat extends StatelessWidget {
  final String label;
  final String amount;

  const _SavingsStat({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }
}

class _PersonalLastRechargeCard extends ConsumerWidget {
  const _PersonalLastRechargeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastRechargeAsync = ref.watch(lastRechargeProvider);

    return lastRechargeAsync.when(
      data: (txn) {
        if (txn == null || txn.status != 'SUCCESS') {
          // Empty State for "Your Last Recharge"
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.history_rounded, size: 18, color: AppColors.primaryBlue),
                        SizedBox(width: 8),
                        Text(
                          'Your Last Recharge',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.go(RouteNames.transactionHistory),
                      child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'No recharge yet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Complete your first recharge to see your latest recharge here.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push(RouteNames.mobileRecharge),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryBlue,
                      side: const BorderSide(color: AppColors.primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Recharge Now', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        }

        final displayOpName = OperatorFormatter.getDisplayOperatorName(txn.operatorName);
        final tag = txn.rechargeType?.isNotEmpty == true
            ? txn.rechargeType!
            : (txn.amount <= 50 ? 'Top-up' : 'Mobile Recharge');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.history_rounded, size: 18, color: AppColors.primaryBlue),
                      SizedBox(width: 8),
                      Text(
                        'Your Last Recharge',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go(RouteNames.transactionHistory),
                    child: const Text('View All', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryBlueLight.withOpacity(0.2),
                    child: Text(
                      displayOpName.isNotEmpty ? displayOpName[0] : 'R',
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(displayOpName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (tag.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(txn.mobileNumber, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CurrencyFormatter.fromRupees(txn.amount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '✓ Successful',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final ops = ref.read(operatorsProvider('mobile')).valueOrNull ?? [];
                    final circles = ref.read(circlesProvider).valueOrNull ?? [];

                    final op = ops.where((o) {
                      final search = txn.operatorName.toLowerCase();
                      final nameLower = o.name.toLowerCase();
                      return o.id == txn.operatorCode ||
                             o.shortCode == txn.operatorCode ||
                             o.plansApiCode == txn.operatorCode ||
                             nameLower == search ||
                             (search.isNotEmpty && nameLower.contains(search));
                    }).firstOrNull ?? Operator(
                      id: txn.operatorCode.isNotEmpty ? txn.operatorCode : '2',
                      name: txn.operatorName.isNotEmpty ? txn.operatorName : 'Airtel',
                      logoUrl: '',
                      type: OperatorType.prepaid,
                      shortCode: txn.operatorCode.isNotEmpty ? txn.operatorCode : '2',
                      a1TopupCode: txn.operatorCode.isNotEmpty ? txn.operatorCode : 'AT',
                      plansApiCode: '2',
                    );

                    final targetCircleCode = txn.circleCode ?? '';
                    final circle = circles.where((c) {
                      return c.code == targetCircleCode ||
                             c.id == targetCircleCode ||
                             c.state.toLowerCase() == targetCircleCode.toLowerCase();
                    }).firstOrNull ?? const Circle(id: '90', state: 'Maharashtra', code: '90');

                    final amountPaise = (txn.amount * 100).round();

                    ref.read(rechargeFlowProvider.notifier).setupRechargeAgain(
                      phoneNumber: txn.mobileNumber,
                      operator: op,
                      circle: circle,
                      amountPaise: amountPaise,
                      rechargeType: txn.rechargeType,
                      providerOperatorCode: txn.operatorCode,
                    );

                    context.push(RouteNames.rechargeConfirm);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Recharge Again',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PersonalCurrentPlanCard extends ConsumerWidget {
  const _PersonalCurrentPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPlanAsync = ref.watch(currentPlanProvider);

    return currentPlanAsync.when(
      data: (plan) {
        final hasActivePlan = plan != null && (plan.cardType == 'PLAN_STATUS' || plan.validity != null || plan.expiryDate != null);

        if (hasActivePlan) {
          final displayOpName = OperatorFormatter.getDisplayOperatorName(plan.operatorName);
          final isExpired = plan.colorState == 'EXPIRED';
          final isRed = plan.colorState == 'RED';
          final isAmber = plan.colorState == 'AMBER';

          Color statusColor = AppColors.success;
          Color statusBg = AppColors.success.withOpacity(0.1);
          if (isExpired || isRed) {
            statusColor = AppColors.error;
            statusBg = AppColors.error.withOpacity(0.1);
          } else if (isAmber) {
            statusColor = const Color(0xFFD97706);
            statusBg = const Color(0xFFFEF3C7);
          }

          String badgeText = plan.validity ?? (plan.daysRemaining != null ? '${plan.daysRemaining} days remaining' : 'Active Plan');

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        Text(
                          plan.title.isNotEmpty ? plan.title : 'Your Current Plan',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push(RouteNames.mobileRecharge),
                      child: const Text('View Details →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryBlueLight.withOpacity(0.2),
                      child: Text(
                        displayOpName.isNotEmpty ? displayOpName[0] : 'P',
                        style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(displayOpName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (plan.mobileNumber.isNotEmpty)
                            Text(plan.mobileNumber, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (plan.amount > 0) ...[
                          Text(
                            CurrencyFormatter.fromRupees(plan.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // Empty state for "Your Current Plan"
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Your Current Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'No active plan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a monthly or yearly plan to get started.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push(RouteNames.mobileRecharge),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('View Plans', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PersonalFrequentNumbersRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final frequentAsync = ref.watch(frequentNumbersProvider);

    return frequentAsync.when(
      data: (numbers) {
        if (numbers.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Recharge', style: AppTextTheme.textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: numbers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final fn = numbers[index];
                  return GestureDetector(
                    onTap: () {
                      context.push(
                        RouteNames.mobileRecharge,
                        extra: {
                          'phoneNumber': fn.mobileNumber,
                          'operatorName': fn.operatorName,
                          'operatorCode': fn.operatorCode,
                          'circleCode': fn.circleCode,
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Icon(
                              fn.operatorName.contains('DTH') ? Icons.tv_rounded : Icons.phone_android_rounded,
                              size: 16,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(fn.mobileNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(fn.operatorName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Recharge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _PersonalBenefitsBanner extends StatelessWidget {
  const _PersonalBenefitsBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(RouteNames.personalBenefits),
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
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.percent_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Benefits & Savings Chart 📊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  SizedBox(height: 2),
                  Text('Check active savings rates across all operators & services.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }
}

class _WhyA1RechargeCard extends StatelessWidget {
  const _WhyA1RechargeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why A1 Recharge? ⚡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _FeatureRow(icon: Icons.flash_on_rounded, title: 'Instant Processing', subtitle: 'Direct high-speed operator connections'),
          const SizedBox(height: 10),
          _FeatureRow(icon: Icons.savings_rounded, title: 'Instant Savings', subtitle: 'Automatic upfront discounts on every recharge'),
          const SizedBox(height: 10),
          _FeatureRow(icon: Icons.lock_outline_rounded, title: '100% Secure Payments', subtitle: 'Protected by Razorpay bank-grade encryption'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}