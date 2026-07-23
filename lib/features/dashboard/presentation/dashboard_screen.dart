import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/providers/core_providers.dart';
import '../../../features/wallet/domain/models/wallet_transaction.dart';
import '../../notifications/presentation/notifications_providers.dart';
import 'dashboard_providers.dart';
import 'package:flutter/services.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Future<void> _refresh() async {
    ref.invalidate(walletBalanceProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(earningsSummaryProvider);
    // Wait for all to complete
    await Future.wait([
      ref.read(walletBalanceProvider.future).catchError((Object error) => throw error),
      ref.read(recentTransactionsProvider.future).catchError((Object error) => throw error),
    ]).catchError((Object error) => <Object>[]);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);
    final user = sessionAsync.valueOrNull;

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

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Wallet Balance Card ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                  child: _WalletBalanceCard(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Today's Stats ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                  child: _TodayStatsRow(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Quick Services ────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Services',
                        style: AppTextTheme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      const _QuickServicesGrid(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Commission Preview Card ───────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                  child: const _CommissionPreviewCard(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── Recent Transactions ───────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Transactions', style: AppTextTheme.textTheme.titleLarge),
                      TextButton(
                        onPressed: () => context.go(RouteNames.history),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: _RecentTransactionsList(),
              ),
              
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
    final retailerName = user?.name ?? 'Retailer';
    final initial = retailerName.isNotEmpty ? retailerName[0].toUpperCase() : 'R';
    final retailerId = user?.retailerId ?? 'RET000000';

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
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                  Text(
                    retailerName,
                    style: AppTextTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Right side: Retailer ID Pill & Notifications
            Row(
              children: [
                // Retailer ID Pill
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
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded, size: 14, color: AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        Text(
                          retailerId,
                          style: const TextStyle(
                            color: AppColors.primaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryBlue),
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
                  onPressed: () => context.go(RouteNames.history),
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
      error: (_, __) => const SizedBox.shrink(),
      data: (earnings) {
        final stats = [
          _StatData(
            label: "Today's Recharge",
            value: CurrencyFormatter.fromPaise(earnings['todayRechargeAmountPaise'] as int? ?? 0),
            icon: Icons.bolt,
            color: AppColors.primaryBlue,
            bgColor: AppColors.primaryBlueLight,
          ),
          _StatData(
            label: 'Commission',
            value: CurrencyFormatter.fromPaise(earnings['todayCommissionPaise'] as int? ?? 0),
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
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
    _ServiceItem(
      label: 'Gas',
      subtitle: 'Bill Payment',
      icon: Icons.local_fire_department,
      route: RouteNames.gas,
      bgColor: Color(0xFFFBE9E7),
      iconColor: Color(0xFFD84315),
    ),
    _ServiceItem(
      label: 'FASTag',
      subtitle: 'Recharge',
      icon: Icons.directions_car,
      route: RouteNames.fastag,
      bgColor: Color(0xFFE0F7FA),
      iconColor: Color(0xFF00838F),
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
      TransactionStatus.pending => AppColors.warning,
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
                        if (txn.commissionEarnedPaise != null && txn.commissionEarnedPaise! > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Earned +₹${(txn.commissionEarnedPaise! / 100).toStringAsFixed(2)}',
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

class _CommissionPreviewCard extends StatelessWidget {
  const _CommissionPreviewCard();

  @override
  Widget build(BuildContext context) {
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
          const _CommissionPreviewRow(operatorName: 'Airtel', percentage: '1.00%'),
          const _CommissionPreviewRow(operatorName: 'Jio', percentage: '0.80%'),
          const _CommissionPreviewRow(operatorName: 'Vi', percentage: '2.70%'),
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