import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/loading_skeleton.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import 'recharge_providers.dart';
import '../domain/models/recharge_plan.dart';
import 'widgets/recent_contacts_list.dart';

class MobileRechargeScreen extends ConsumerStatefulWidget {
  const MobileRechargeScreen({super.key});

  @override
  ConsumerState<MobileRechargeScreen> createState() => _MobileRechargeScreenState();
}

class _MobileRechargeScreenState extends ConsumerState<MobileRechargeScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();

  final List<int> _quickAmounts = [19, 199, 299, 479, 666, 719];
  
  String _selectedCategory = '⭐ Recommended';
  final List<String> _categories = [
    '⭐ Recommended',
    '♾ Unlimited',
    '📶 Data',
    '⚡ Data Booster',
    '🎬 Content Packs',
    '5️⃣ Unlimited 5G',
    '💰 Talktime',
    '🌍 International Roaming',
    '📅 Yearly Plans',
  ];

  bool _hasContactPermission = false;

  final List<String> _quickFilters = [
    '28 Days', '56 Days', '84 Days', '365 Days', 
    '1GB/day', '1.5GB/day', '2GB/day', 'Unlimited 5G'
  ];
  String _searchQuery = '';
  String _selectedQuickFilter = '';
  final TextEditingController _searchController = TextEditingController();

  String _categorizePlan(RechargePlan plan) {
    final desc = plan.description.toLowerCase();
    final data = plan.data?.toLowerCase() ?? '';
    final voice = plan.voice?.toLowerCase() ?? '';
    final validity = plan.validity.toLowerCase();
    
    if (plan.tags.isNotEmpty || desc.contains('hotstar') || desc.contains('prime') || desc.contains('netflix')) return '🎬 Content Packs';
    if (validity.contains('365') || validity.contains('year')) return '📅 Yearly Plans';
    if (desc.contains('isd') || desc.contains('roaming')) return '🌍 International Roaming';
    if (desc.contains('5g') || plan.tags.any((t) => t.toLowerCase().contains('5g'))) return '5️⃣ Unlimited 5G';
    if (voice.contains('unlimited') || desc.contains('unlimited calls')) return '♾ Unlimited';
    if (data.isNotEmpty && (voice.isEmpty || voice == 'na' || voice == 'none')) return '⚡ Data Booster';
    if (data.isNotEmpty) return '📶 Data';
    if (plan.talktime != null || desc.contains('talktime')) return '💰 Talktime';
    
    return '♾ Unlimited'; // Fallback
  }

  @override
  void initState() {
    super.initState();
    _checkPermissionStatus();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(rechargeFlowProvider);
      if (state.phoneNumber != null) {
        _phoneController.text = state.phoneNumber!;
      } else {
        _phoneFocusNode.requestFocus();
      }
    });
  }

  Future<void> _checkPermissionStatus() async {
    if (kIsWeb) {
      setState(() {
        _hasContactPermission = false;
      });
      return;
    }
    
    final status = await Permission.contacts.status;
    setState(() {
      _hasContactPermission = status.isGranted;
    });
  }

  Future<void> _requestContactPermission() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts access is not supported on web.')),
        );
      }
      return;
    }

    try {
      final status = await Permission.contacts.request();
      setState(() {
        _hasContactPermission = status.isGranted;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts permission is not supported on this platform.')),
        );
      }
      // Ignore gracefully
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    ref.read(rechargeFlowProvider.notifier).setPhoneNumber(value);
    
    // Auto-resolve operator when 10 digits are entered
    if (value.length >= 10) {
      _resolveOperator(value.substring(value.length - 10)); // Take last 10 in case of +91
      _phoneFocusNode.unfocus();
    } else {
      // Clear operator if length is less than 10
      final state = ref.read(rechargeFlowProvider);
      if (state.operator != null) {
        ref.read(rechargeFlowProvider.notifier).reset();
        ref.read(rechargeFlowProvider.notifier).setPhoneNumber(value);
      }
    }
  }

  Future<void> _resolveOperator(String phone) async {
    try {
      final repo = ref.read(rechargeRepositoryProvider);
      final result = await repo.resolveOperator(phone);
      result
        ..onSuccess((res) {
          if (!mounted) return;
          ref.read(rechargeFlowProvider.notifier).setOperator(res.operator);
          ref.read(rechargeFlowProvider.notifier).setCircle(res.circle);
        })
        ..onFailure((err) {
          print('resolveOperator failed: $err');
        });
    } catch (e) {
      print('resolveOperator threw exception: $e');
    }
  }

  void _onRecentTap(String phone) {
    // Strip everything except numbers
    String cleanNumber = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanNumber.length > 10) {
      cleanNumber = cleanNumber.substring(cleanNumber.length - 10);
    }
    _phoneController.text = cleanNumber;
    _onPhoneChanged(cleanNumber);
  }

  void _selectOperator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text('Select Operator', style: AppTextTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ),
                const TabBar(
                  labelColor: AppColors.primaryBlue,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primaryBlue,
                  tabs: [
                    Tab(text: 'Prepaid'),
                    Tab(text: 'Postpaid'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildOperatorList('mobile', scrollController),
                      _buildOperatorList('postpaid', scrollController),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOperatorList(String serviceType, ScrollController scrollController) {
    return Consumer(
      builder: (context, ref, child) {
        final opsAsync = ref.watch(operatorsProvider(serviceType));
        return opsAsync.when(
          loading: () => ListView.builder(
            itemCount: 5,
            itemBuilder: (_, __) => const ListTile(
              leading: SkeletonBox(width: 40, height: 40, borderRadius: 20),
              title: SkeletonBox(width: 100, height: 16),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (ops) => ListView.separated(
            controller: scrollController,
            itemCount: ops.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final op = ops[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cell_tower, color: AppColors.primaryBlue, size: 20),
                ),
                title: Text(op.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  ref.read(rechargeFlowProvider.notifier).setOperator(op);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  void _selectCircle() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, child) {
              final circlesAsync = ref.watch(circlesProvider);
              
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Select Circle', style: AppTextTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: circlesAsync.when(
                      loading: () => ListView.builder(
                        itemCount: 5,
                        itemBuilder: (_, __) => const ListTile(
                          leading: SkeletonBox(width: 40, height: 40, borderRadius: 20),
                          title: SkeletonBox(width: 100, height: 16),
                        ),
                      ),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (circles) => ListView.separated(
                        controller: scrollController,
                        itemCount: circles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                        itemBuilder: (context, i) {
                          final circle = circles[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on, color: Colors.orange, size: 20),
                            ),
                            title: Text(circle.state, style: const TextStyle(fontWeight: FontWeight.w600)),
                            onTap: () {
                              ref.read(rechargeFlowProvider.notifier).setCircle(circle);
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
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rechargeFlowProvider);
    final walletBalanceAsync = ref.watch(walletBalanceProvider);
    
    final bool hasOperator = state.operator != null && state.circle != null;
    final bool hasPlan = state.customAmountPaise != null && state.customAmountPaise! > 0;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mobile Recharge', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // ── Wallet Balance Header ──
                  SliverToBoxAdapter(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.account_balance_wallet, color: AppColors.textSecondary, size: 20),
                              const SizedBox(width: 8),
                              const Text('Wallet Balance: ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              walletBalanceAsync.when(
                                data: (b) => Text(CurrencyFormatter.fromPaiseNoDecimal(b.availablePaise), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                loading: () => const SkeletonBox(width: 50, height: 14),
                                error: (_, __) => const Text('Error', style: TextStyle(color: AppColors.error, fontSize: 12)),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () => context.push(RouteNames.walletTopup),
                            child: const Text('+ Add Money', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                          )
                        ],
                      ),
                    ),
                  ),

                  // ── Compact Customer Card or Phone Input ──
                  if (hasOperator)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                        child: InkWell(
                          onTap: () {
                            ref.read(rechargeFlowProvider.notifier).clearOperator();
                            _phoneController.clear();
                          },
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primaryBlueLight.withValues(alpha: 0.2),
                                  radius: 18,
                                  child: const Icon(Icons.sim_card, color: AppColors.primaryBlue, size: 20),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_phoneController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text('${state.operator!.name} • ${state.circle?.state ?? 'Unknown'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                const Text('CHANGE', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
                        margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mobile Number', style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: AppSpacing.md),
                            SizedBox(
                              height: 60,
                              child: TextFormField(
                                controller: _phoneController,
                                focusNode: _phoneFocusNode,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: _onPhoneChanged,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 1),
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: 'Enter 10-digit mobile number',
                                  hintStyle: TextStyle(color: AppColors.textHint.withValues(alpha: 0.6), fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0),
                                  prefixIcon: const Padding(
                                    padding: EdgeInsets.only(left: 12.0, right: 8.0),
                                    child: Icon(Icons.phone_android, size: 24, color: AppColors.textSecondary),
                                  ),
                                  prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  suffixIcon: Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: IconButton(
                                      icon: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
                                        child: const Icon(Icons.contacts, color: Colors.white, size: 20),
                                      ),
                                      padding: EdgeInsets.zero,
                                      splashRadius: 24,
                                      onPressed: _requestContactPermission,
                                    ),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1.5)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1.5)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2)),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Recent Contacts ──
                  if (!hasOperator)
                    SliverToBoxAdapter(
                      child: RecentContactsList(
                        onContactSelected: _onRecentTap,
                      ),
                    ),

                  // ── Premium Category Selector & Plans ──
                  if (hasOperator) ...[
                    // Search Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                        child: TextField(
                          controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search ₹299, 2GB/day, Netflix...',
                                    hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                                    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                                    suffixIcon: _searchQuery.isNotEmpty 
                                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; }))
                                      : null,
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: const BorderSide(color: AppColors.primaryBlue)),
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                                ),
                              ),
                            ),
                            
                            // Quick Filters
                            SliverToBoxAdapter(
                              child: SizedBox(
                                height: 36,
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _quickFilters.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final filter = _quickFilters[index];
                                    final isSelected = filter == _selectedQuickFilter;
                                    return ActionChip(
                                      label: Text(filter),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                      backgroundColor: isSelected ? AppColors.textPrimary : Colors.white,
                                      side: BorderSide(color: isSelected ? AppColors.textPrimary : AppColors.border.withValues(alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                      onPressed: () {
                                        setState(() {
                                          _selectedQuickFilter = isSelected ? '' : filter;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            Consumer(
                              builder: (context, ref, child) {
                                final plansAsync = ref.watch(plansProvider((operatorId: state.operator!.id, circle: state.circle!.id, serviceType: state.operator!.type.name)));
                                
                                return plansAsync.when(
                                  loading: () => SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) => const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
                                        child: SkeletonBox(width: double.infinity, height: 160, borderRadius: 12),
                                      ),
                                      childCount: 4,
                                    ),
                                  ),
                                  error: (err, _) => SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(AppSpacing.lg),
                                      child: Text('Failed to load plans: $err', style: const TextStyle(color: AppColors.error)),
                                    ),
                                  ),
                                  data: (allPlans) {
                                    // Apply Search & Filters
                                    var plans = allPlans.where((p) {
                                      if (_searchQuery.isNotEmpty) {
                                        final q = _searchQuery;
                                        if (!p.pricePaise.toString().contains(q) &&
                                            !p.validity.toLowerCase().contains(q) &&
                                            !p.description.toLowerCase().contains(q) &&
                                            !(p.data?.toLowerCase().contains(q) ?? false)) {
                                          return false;
                                        }
                                      }
                                      if (_selectedQuickFilter.isNotEmpty) {
                                        final f = _selectedQuickFilter.toLowerCase();
                                        if (f.contains('day') && !f.contains('gb')) {
                                          if (!p.validity.toLowerCase().contains(f)) return false;
                                        } else if (f.contains('gb')) {
                                          if (!(p.data?.toLowerCase().contains(f) ?? false)) return false;
                                        } else if (f.contains('5g')) {
                                          if (!p.description.toLowerCase().contains('5g') && !p.tags.any((t) => t.toLowerCase().contains('5g'))) return false;
                                        }
                                      }
                                      return true;
                                    }).toList();
                            final categoriesMap = <String, List<RechargePlan>>{};
                            for (final cat in _categories) { categoriesMap[cat] = []; }
                            
                            for (final p in plans) {
                              final cat = _categorizePlan(p);
                              if (categoriesMap.containsKey(cat)) { categoriesMap[cat]!.add(p); }
                            }
                            
                            final recommended = plans.where((p) => p.isPopular || p.isBestValue).toList();
                            categoriesMap['⭐ Recommended'] = recommended.isNotEmpty ? recommended : plans.take(15).toList();

                            final activeCategories = _categories.where((c) => c == '⭐ Recommended' || (categoriesMap[c]?.isNotEmpty ?? false)).toList();
                            
                            if (!activeCategories.contains(_selectedCategory)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) setState(() => _selectedCategory = '⭐ Recommended');
                              });
                            }

                            final selectedPlans = categoriesMap[_selectedCategory] ?? [];

                            return SliverMainAxisGroup(
                              slivers: [
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: _CategorySelectorDelegate(
                                    categories: activeCategories,
                                    categoriesMap: categoriesMap,
                                    selectedCategory: _selectedCategory,
                                    onSelected: (cat) => setState(() => _selectedCategory = cat),
                                  ),
                                ),
                                SliverPadding(
                                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final plan = selectedPlans[index];
                                        final isSelected = state.selectedPlan?.id == plan.id || state.customAmountPaise == plan.pricePaise;
                                        
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
                                          child: _PremiumPlanCard(
                                            plan: plan,
                                            isSelected: isSelected,
                                            onTap: () => ref.read(rechargeFlowProvider.notifier).setPlan(plan),
                                            onDetailsTap: () {
                                              showModalBottomSheet(
                                                context: context,
                                                isScrollControlled: true,
                                                backgroundColor: Colors.transparent,
                                                builder: (context) => _PlanDetailsSheet(plan: plan, onRecharge: () {
                                                  Navigator.pop(context);
                                                  ref.read(rechargeFlowProvider.notifier).setPlan(plan);
                                                }),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                      childCount: selectedPlans.length,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ]
                ],
              ),
            ),
            
            // ── Sticky Bottom Summary Bar ──
            if (hasPlan)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, -5))],
                ),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl), // Extra padding at bottom for safe area
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Amount Payable', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.fromPaiseNoDecimal(state.customAmountPaise ?? state.selectedPlan?.pricePaise ?? 0),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => context.push(RouteNames.rechargeConfirm),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(120, 52), // Override global double.infinity
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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
  final Map<String, List<RechargePlan>> categoriesMap;
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
                color: isSelected ? AppColors.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.5),
                ),
                boxShadow: isSelected 
                  ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
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
                        color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppColors.surfaceVariant,
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

class _PlanDetailCol extends StatelessWidget {
  final String label;
  final String value;
  const _PlanDetailCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }
}

class _PremiumPlanCard extends StatelessWidget {
  const _PremiumPlanCard({
    required this.plan,
    required this.isSelected,
    required this.onTap,
    required this.onDetailsTap,
  });

  final RechargePlan plan;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDetailsTap;

  @override
  Widget build(BuildContext context) {
    final hasOtt = plan.description.toLowerCase().contains('hotstar') || plan.description.toLowerCase().contains('prime') || plan.description.toLowerCase().contains('netflix');
    
    // Calculate Rs/day
    String? rsPerDay;
    if (plan.validity.toLowerCase().contains('day')) {
      final daysMatch = RegExp(r'(\d+)').firstMatch(plan.validity);
      if (daysMatch != null) {
        final days = int.tryParse(daysMatch.group(1)!);
        if (days != null && days > 0) {
          final ppd = (plan.pricePaise / 100) / days;
          rsPerDay = '\u20B9${ppd.toStringAsFixed(1)}/day';
        }
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryBlueLight.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.3),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected 
          ? [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]
          : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Row: Price, Badges, Action Button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '\u20B9${plan.pricePaise ~/ 100}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    if (plan.isBestValue || plan.isPopular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(plan.isBestValue ? 'Best Value' : 'Popular', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                      ),
                    const Spacer(),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.primaryBlue : Colors.white,
                          foregroundColor: isSelected ? Colors.white : AppColors.primaryBlue,
                          elevation: 0,
                          minimumSize: const Size(64, 36), // Override global double.infinity
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: AppColors.primaryBlue),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        child: const Text('Recharge', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Second Row: Compact Chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(icon: '🗓', text: plan.validity),
                    if (plan.data != null && plan.data != 'NA') _InfoChip(icon: '📶', text: plan.data!),
                    if (plan.voice != null && plan.voice != 'NA') _InfoChip(icon: '📞', text: plan.voice!),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Third Row: Meta details and View Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (plan.sms != null && plan.sms!.isNotEmpty)
                            _MetaText(icon: '💬', text: plan.sms!),
                          if (hasOtt)
                            const _MetaText(icon: '🎬', text: 'OTT Included', color: Colors.purple),
                          if (rsPerDay != null)
                            _MetaText(icon: '💚', text: rsPerDay, color: Colors.green),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: onDetailsTap,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        child: Text('Details →', style: TextStyle(fontSize: 13, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String icon;
  final String text;
  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String icon;
  final String text;
  final Color? color;
  const _MetaText({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          text, 
          style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
          maxLines: 1, 
          overflow: TextOverflow.ellipsis
        ),
      ],
    );
  }
}

class _SheetStat extends StatelessWidget {
  final String label;
  final String value;
  const _SheetStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.textHint, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
        ),
      ],
    );
  }
}

class _PlanDetailsSheet extends StatelessWidget {
  final RechargePlan plan;
  final VoidCallback onRecharge;

  const _PlanDetailsSheet({required this.plan, required this.onRecharge});

  @override
  Widget build(BuildContext context) {
    final bullets = plan.description.split('. ').where((s) => s.trim().isNotEmpty).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\u20B9${plan.pricePaise ~/ 100}',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  if (plan.isBestValue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Best Value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _SheetStat(label: 'VALIDITY', value: plan.validity)),
                    Expanded(child: _SheetStat(label: 'DATA', value: plan.data ?? 'NA')),
                    Expanded(child: _SheetStat(label: 'VOICE', value: plan.voice ?? 'NA')),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Text('Benefits', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.md),
              if (bullets.isNotEmpty)
                ...bullets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6.0, right: 8.0),
                        child: Icon(Icons.circle, size: 6, color: AppColors.primaryBlue),
                      ),
                      Expanded(child: Text(b, style: const TextStyle(color: AppColors.textSecondary, height: 1.4))),
                    ],
                  ),
                ))
              else
                Text(plan.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
              
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: onRecharge,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54), // Ensure it spans the bottom sheet
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Select Plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}