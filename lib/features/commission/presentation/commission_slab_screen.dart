import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../domain/models/commission_slab.dart';
import 'commission_providers.dart';

class CommissionSlabScreen extends ConsumerStatefulWidget {
  const CommissionSlabScreen({super.key});

  @override
  ConsumerState<CommissionSlabScreen> createState() => _CommissionSlabScreenState();
}

class _CommissionSlabScreenState extends ConsumerState<CommissionSlabScreen> {
  final TextEditingController _amountController = TextEditingController(text: '1000');
  double _calcAmount = 1000.0;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    setState(() => _calcAmount = double.tryParse(val) ?? 0);
  }

  Future<void> _onRefresh() async {
    ref.invalidate(activeCommissionSlabsProvider);
    await ref.read(activeCommissionSlabsProvider.future).catchError((_) => <CommissionSlab>[]);
  }

  @override
  Widget build(BuildContext context) {
    final slabsAsync = ref.watch(activeCommissionSlabsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Commission Chart', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Compact Earnings Calculator Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlueLight.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calculate_outlined, color: AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Earnings Calculator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        Text('Enter recharge amount', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: TextField(
                      controller: _amountController,
                      onChanged: _onAmountChanged,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryBlue),
                      decoration: const InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primaryBlue,
              child: slabsAsync.when(
                loading: () => const _SlabListSkeleton(),
                error: (e, _) => CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      child: ErrorStateWidget(
                        message: 'Could not load commission slabs.',
                        onRetry: _onRefresh,
                      ),
                    )
                  ],
                ),
                data: (slabs) {
                  if (slabs.isEmpty) {
                    return CustomScrollView(
                      slivers: [
                        SliverFillRemaining(
                          child: EmptyStateWidget(
                            title: 'No Active Slabs',
                            description: 'Commission slabs will appear here once configured.',
                          ),
                        )
                      ],
                    );
                  }

                  // Grouping
                  final mobileSlabs = slabs.where((s) => s.serviceType == 'mobile').toList();
                  final dthSlabs = slabs.where((s) => s.serviceType == 'dth').toList();
                  final bbpsSlabs = slabs.where((s) => s.serviceType == 'bbps').toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    children: [
                      if (mobileSlabs.isNotEmpty)
                        _CategorySection(
                          title: 'Mobile Recharge',
                          icon: Icons.phone_android,
                          accentColor: AppColors.primaryBlue,
                          slabs: mobileSlabs,
                          calcAmount: _calcAmount,
                          initiallyExpanded: true,
                        ),
                      if (dthSlabs.isNotEmpty)
                        _CategorySection(
                          title: 'DTH Recharge',
                          icon: Icons.tv,
                          accentColor: Colors.deepOrange,
                          slabs: dthSlabs,
                          calcAmount: _calcAmount,
                          initiallyExpanded: true,
                        ),
                      if (bbpsSlabs.isNotEmpty)
                        _CategorySection(
                          title: 'Electricity',
                          icon: Icons.lightbulb_outline,
                          accentColor: Colors.teal,
                          slabs: bbpsSlabs,
                          calcAmount: _calcAmount,
                          initiallyExpanded: true,
                        ),
                      const SizedBox(height: 100),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<CommissionSlab> slabs;
  final double calcAmount;
  final bool initiallyExpanded;

  const _CategorySection({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.slabs,
    required this.calcAmount,
    this.initiallyExpanded = false,
  });

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(_controller);
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));
    if (_isExpanded) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: _handleTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: widget.accentColor, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary)),
                        Text('${widget.slabs.length} Operators', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _iconTurns,
                    child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable Grid
          ClipRect(
            child: AnimatedBuilder(
              animation: _controller.view,
              builder: _buildChildren,
              child: GridView.builder(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 110, // Fixed height for each premium card
                ),
                itemCount: widget.slabs.length,
                itemBuilder: (context, index) {
                  return _PremiumCommissionCard(
                    slab: widget.slabs[index],
                    calcAmount: widget.calcAmount,
                    accentColor: widget.accentColor,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildren(BuildContext context, Widget? child) {
    return Align(
      heightFactor: _heightFactor.value,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class _PremiumCommissionCard extends StatelessWidget {
  final CommissionSlab slab;
  final double calcAmount;
  final Color accentColor;

  const _PremiumCommissionCard({
    required this.slab,
    required this.calcAmount,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    double earning = 0;
    if (slab.commissionType == 'percentage') {
      earning = calcAmount * slab.commissionValue / 100;
    } else {
      earning = slab.commissionValue;
    }

    final isFlat = slab.commissionType == 'flat';
    final commissionText = isFlat ? '₹${slab.commissionValue.toStringAsFixed(2)} Flat' : '${slab.commissionValue.toStringAsFixed(2)}%';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Stack(
        children: [
          // Top right subtle accent decoration
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Row: Logo & Commission Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Operator Logo
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text(
                          slab.operatorName[0].toUpperCase(),
                          style: TextStyle(fontWeight: FontWeight.w900, color: accentColor, fontSize: 16),
                        ),
                      ),
                    ),
                    
                    // Commission % Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        commissionText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Bottom: Operator Name & Earnings
                Text(
                  slab.operatorName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Text('Earn ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(
                      '₹${earning.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading Skeleton ─────────────────────────────────────────────────────────

class _SlabListSkeleton extends StatelessWidget {
  const _SlabListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceVariant,
      highlightColor: AppColors.cardWhite,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: 3,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                width: 150,
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(color: AppColors.cardWhite, borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
