import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../../models/mobile_plan.dart';
import '../../../models/plan_category.dart';
import '../../recharge/domain/models/operator.dart';
import '../domain/models/dth_customer_info.dart';

import 'providers/dth_providers.dart';

enum DthSortOption { popular, priceLowToHigh, priceHighToLow, validity }

class DthRechargeScreen extends ConsumerStatefulWidget {
  const DthRechargeScreen({super.key});

  @override
  ConsumerState<DthRechargeScreen> createState() => _DthRechargeScreenState();
}

class _DthRechargeScreenState extends ConsumerState<DthRechargeScreen> {
  final _subscriberIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _searchController = TextEditingController();
  final FocusNode _subscriberIdFocusNode = FocusNode();

  String _selectedCategory = '';
  DthSortOption _sortOption = DthSortOption.popular;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dthFlowProvider.notifier).reset();
      _subscriberIdController.clear();
      _amountController.clear();
    });
  }

  @override
  void dispose() {
    _subscriberIdController.dispose();
    _amountController.dispose();
    _searchController.dispose();
    _subscriberIdFocusNode.dispose();
    super.dispose();
  }

  void _onSubscriberIdChanged(String value) {
    ref.read(dthFlowProvider.notifier).setSubscriberId(value);
  }

  void _onAmountChanged(String value) {
    final num = int.tryParse(value) ?? 0;
    ref.read(dthFlowProvider.notifier).setAmount(num * 100);
  }

  void _selectOperator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, child) {
              final opsAsync = ref.watch(dthOperatorsProvider);
              
              return Column(
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Text('Select DTH Operator', style: AppTextTheme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  Expanded(
                    child: opsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (ops) => ListView.builder(
                        controller: scrollController,
                        itemCount: ops.length,
                        itemBuilder: (context, i) {
                          final op = ops[i];
                          return ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.surfaceVariant,
                              child: Icon(Icons.satellite_alt, color: AppColors.primaryBlue),
                            ),
                            title: Text(op.name),
                            onTap: () {
                              ref.read(dthFlowProvider.notifier).setOperator(op);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomerInfoCard(DthCustomerInfo info, String? subscriberId, String? operatorName) {
    final status = info.status?.toLowerCase() ?? 'unknown';
    final isActive = status == 'active';
    
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFF4F7FF), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryBlueLight,
                  radius: 22,
                  child: Icon(Icons.person, color: AppColors.primaryBlue, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.customerName?.isNotEmpty == true ? info.customerName! : 'Customer Details', 
                        style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
                      ),
                      if (subscriberId != null) 
                        Text('Subscriber ID: $subscriberId', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (info.status != null && info.status!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? AppColors.success.withValues(alpha: 0.3) : AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(isActive ? Icons.check_circle : Icons.error, size: 14, color: isActive ? AppColors.success : AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isActive ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn('Operator', operatorName ?? 'Unknown'),
                if (info.balance != null && info.balance!.isNotEmpty)
                  _buildInfoColumn('Balance', '₹${info.balance}'),
                if (info.monthlyPack != null && info.monthlyPack!.isNotEmpty)
                  _buildInfoColumn('Monthly Pack', '₹${info.monthlyPack}'),
                if (info.nextRechargeDate != null && info.nextRechargeDate!.isNotEmpty)
                  _buildInfoColumn('Next Recharge', info.nextRechargeDate!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dthFlowProvider);

    if (state.customAmountPaise != null) {
      final textAmount = (state.customAmountPaise! ~/ 100).toString();
      if (_amountController.text != textAmount && textAmount != '0') {
        _amountController.text = textAmount;
      }
    } else if (state.customAmountPaise == null && _amountController.text.isNotEmpty) {
      _amountController.text = '';
    }

    final hasOperator = state.selectedOperator != null;
    final hasSubscriberId = state.subscriberId != null && state.subscriberId!.length >= 4;
    final hasAmount = state.customAmountPaise != null && state.customAmountPaise! > 0;

    final isValid = hasOperator && hasSubscriberId && hasAmount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DTH Recharge'),
      ),
      body: CustomScrollView(
        slivers: [
          // Basic Input Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Subscriber ID ──
                  Text('Subscriber ID / VC Number', style: AppTextTheme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _subscriberIdController,
                    focusNode: _subscriberIdFocusNode,
                    keyboardType: TextInputType.text,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    onChanged: _onSubscriberIdChanged,
                    decoration: InputDecoration(
                      hintText: 'Enter Subscriber ID',
                      prefixIcon: const Icon(Icons.tv),
                      suffixIcon: state.isDetecting 
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Operator Selection ──
                  Text('DTH Operator', style: AppTextTheme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primaryBlueLight,
                        child: Icon(Icons.satellite_alt, color: AppColors.primaryBlue),
                      ),
                      title: Text(state.selectedOperator?.name ?? 'Select Operator'),
                      trailing: state.selectedOperator == null 
                          ? const Icon(Icons.arrow_forward_ios, size: 16)
                          : TextButton(
                              onPressed: _selectOperator,
                              child: const Text('Change'),
                            ),
                      onTap: state.selectedOperator == null ? _selectOperator : null,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Customer Info ──
                  if (state.customerInfo != null)
                    _buildCustomerInfoCard(state.customerInfo!, state.subscriberId, state.selectedOperator?.name),

                  if (hasOperator) ...[
                    // ── Amount ──
                    Text('Amount', style: AppTextTheme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onAmountChanged,
                      style: AppTextTheme.textTheme.headlineMedium,
                      decoration: const InputDecoration(
                        hintText: '₹ 0',
                        prefixText: '₹ ',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),

          // Plans Section if Operator is Selected
          if (hasOperator) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search plans...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.all(AppSpacing.sm),
                        suffixIcon: _searchController.text.isNotEmpty ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ) : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: DthSortOption.values.map((option) {
                          final isSelected = _sortOption == option;
                          final label = switch(option) {
                            DthSortOption.popular => 'Popular',
                            DthSortOption.priceLowToHigh => 'Low → High',
                            DthSortOption.priceHighToLow => 'High → Low',
                            DthSortOption.validity => 'Validity',
                          };
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _sortOption = option),
                              backgroundColor: AppColors.surfaceVariant,
                              selectedColor: AppColors.primaryBlue,
                              checkmarkColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            ref.watch(dthPacksProvider(state.selectedOperator!)).when(
              loading: () => const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16.0), child: ListSkeleton(count: 3))),
              error: (err, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text('Failed to load plans: $err', style: const TextStyle(color: AppColors.error))),
                ),
              ),
              data: (allCategories) {
                final categoriesMap = <String, List<MobilePlan>>{};
                
                for (final category in allCategories) {
                  if (category.plans.isNotEmpty) {
                    categoriesMap[category.name] = category.plans;
                  }
                }
                
                final activeCategories = categoriesMap.keys.toList();

                if (activeCategories.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: Text('No plans match your search.')),
                      ),
                    );
                }

                if (!activeCategories.contains(_selectedCategory)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedCategory = activeCategories.first);
                  });
                }

                var selectedPlans = List<MobilePlan>.from(categoriesMap[_selectedCategory] ?? []);
                final searchQuery = _searchController.text.toLowerCase().trim();
                
                if (searchQuery.isNotEmpty) {
                  selectedPlans = selectedPlans.where((p) {
                    final amountStr = (double.tryParse(p.rs ?? '0') ?? 0).toString();
                    return amountStr.contains(searchQuery) ||
                            (p.desc ?? '').toLowerCase().contains(searchQuery) ||
                            (p.validity ?? '').toLowerCase().contains(searchQuery);
                  }).toList();
                }

                if (_sortOption == DthSortOption.priceLowToHigh) {
                  selectedPlans.sort((a, b) => (double.tryParse(a.rs ?? '0') ?? 0).compareTo(double.tryParse(b.rs ?? '0') ?? 0));
                } else if (_sortOption == DthSortOption.priceHighToLow) {
                  selectedPlans.sort((a, b) => (double.tryParse(b.rs ?? '0') ?? 0).compareTo(double.tryParse(a.rs ?? '0') ?? 0));
                } else if (_sortOption == DthSortOption.validity) {
                  selectedPlans.sort((a, b) => (a.validity ?? '').compareTo(b.validity ?? ''));
                }

                return SliverMainAxisGroup(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _CategorySelectorDelegate(
                        categories: activeCategories,
                        categoriesMap: categoriesMap,
                        selectedCategory: _selectedCategory,
                        onSelected: (cat) {
                          setState(() => _selectedCategory = cat);
                          // Hide keyboard when interacting with categories
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.pagePadding),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final plan = selectedPlans[index];
                            final rsVal = double.tryParse(plan.rs ?? '0') ?? 0;
                            final paiseVal = (rsVal * 100).toInt();
                            final isSelected = state.customAmountPaise == paiseVal && state.selectedPlan == plan;

                            return _PremiumPlanCard(
                              plan: plan,
                              isSelected: isSelected,
                              onTap: () {
                                ref.read(dthFlowProvider.notifier).setPlan(plan);
                                // Scroll or update UI smoothly
                              },
                            );
                          },
                          childCount: selectedPlans.length,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
      bottomNavigationBar: isValid
          ? Container(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Amount Payable', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.fromPaiseNoDecimal(state.customAmountPaise ?? 0),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    SizedBox(
                      height: 52,
                      width: 140,
                      child: ElevatedButton(
                        onPressed: () => context.push(RouteNames.dthConfirm),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _CategorySelectorDelegate extends SliverPersistentHeaderDelegate {
  _CategorySelectorDelegate({
    required this.categories,
    required this.categoriesMap,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final Map<String, List<MobilePlan>> categoriesMap;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  double get minExtent => 70;
  @override
  double get maxExtent => 70;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      alignment: Alignment.centerLeft,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 15),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final count = categoriesMap[cat]?.length ?? 0;
          final isSelected = cat == selectedCategory;
          
          return GestureDetector(
            onTap: () => onSelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected 
                  ? const LinearGradient(colors: [AppColors.primaryBlue, Color(0xFF3377FF)]) 
                  : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.border.withValues(alpha: 0.5),
                ),
                boxShadow: isSelected 
                  ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))]
                  : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.25) : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_CategorySelectorDelegate oldDelegate) {
    return oldDelegate.selectedCategory != selectedCategory ||
           oldDelegate.categories != categories;
  }
}

class _PremiumPlanCard extends ConsumerWidget {
  const _PremiumPlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
  });

  final MobilePlan plan;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dthFlowProvider);
    final hasPricingOptions = plan.pricingOptions != null && plan.pricingOptions!.isNotEmpty;
    
    // Parse HD Channels string
    String hdText = 'Not Included';
    if (plan.hdChannels != null && plan.hdChannels!.isNotEmpty) {
      if (plan.hdChannels!.toLowerCase().contains('no hd channels')) {
        hdText = 'Not Included';
      } else {
        final match = RegExp(r'\d+').firstMatch(plan.hdChannels!);
        if (match != null) {
          hdText = '${match.group(0)} Channels';
        } else {
          hdText = plan.hdChannels!;
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    plan.desc ?? 'Unknown Plan',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
                if (plan.language != null && plan.language!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      plan.language!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          
          // ── FEATURES GRID ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFeatureIcon(Icons.tv, 'Total Channels', plan.channels?.replaceAll(' Channels', '') ?? 'N/A'),
                const SizedBox(width: 12),
                _buildFeatureIcon(Icons.live_tv, 'Paid', plan.paidChannels?.replaceAll(' Paid Channels', '') ?? 'N/A'),
                const SizedBox(width: 12),
                _buildFeatureIcon(Icons.hd, 'HD', hdText, isHighlight: hdText != 'Not Included'),
                const Spacer(),
                if (plan.lastUpdate != null && plan.lastUpdate!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Updated', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Text(plan.lastUpdate!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.black12),
          
          // ── PRICING OPTIONS ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Recharge Option', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                if (hasPricingOptions)
                  ...plan.pricingOptions!.map((option) {
                    final rsVal = double.tryParse(option.amount) ?? 0;
                    final paiseVal = (rsVal * 100).toInt();
                    final isOptionSelected = state.customAmountPaise == paiseVal && state.selectedPlan == plan;
                    
                    return GestureDetector(
                      onTap: () {
                        ref.read(dthFlowProvider.notifier).setPlan(plan);
                        ref.read(dthFlowProvider.notifier).setAmount(paiseVal);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isOptionSelected ? AppColors.primaryBlueLight.withValues(alpha: 0.15) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isOptionSelected ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.5),
                            width: isOptionSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('₹${option.amount}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isOptionSelected ? AppColors.primaryBlue : AppColors.textPrimary)),
                                if (option.validity.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(option.validity, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ]
                              ],
                            ),
                            if (isOptionSelected)
                              const Icon(Icons.check_circle, color: AppColors.primaryBlue)
                            else
                              const Icon(Icons.radio_button_unchecked, color: AppColors.border),
                          ],
                        ),
                      ),
                    );
                  })
                else
                  // Fallback if no PricingList
                  GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryBlueLight.withValues(alpha: 0.15) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('₹${plan.rs}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary)),
                          if (isSelected) const Icon(Icons.check_circle, color: AppColors.primaryBlue) else const Icon(Icons.radio_button_unchecked, color: AppColors.border),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: isHighlight ? AppColors.primaryBlue : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isHighlight ? AppColors.primaryBlue : AppColors.textPrimary)),
      ],
    );
  }
}