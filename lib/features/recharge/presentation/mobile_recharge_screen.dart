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


  String _selectedCategory = '⭐ Recommended';
  final List<String> _quickFilters = [
    '28 Days', '56 Days', '84 Days', '365 Days', 
    '1GB/day', '1.5GB/day', '2GB/day', 'Unlimited 5G'
  ];
  String _searchQuery = '';
  String _selectedQuickFilter = '';
  final TextEditingController _searchController = TextEditingController();

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
      return;
    }
    
    await Permission.contacts.status;
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
      await Permission.contacts.request();
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
    debugPrint('[FLOW] Mobile entered: $value');
    ref.read(rechargeFlowProvider.notifier).setPhoneNumber(value);
    
    // Auto-resolve operator when 10 digits are entered
    if (value.length >= 10) {
      debugPrint('[FLOW] Starting operator resolution for number');
      ref.read(rechargeFlowProvider.notifier).setDetecting(true);
      _resolveOperator(value.substring(value.length - 10)); // Take last 10 in case of +91
      _phoneFocusNode.unfocus();
    }
  }

  Future<void> _resolveOperator(String phone) async {
    debugPrint('[FLOW] Calling resolve API for phone: $phone');
    try {
      final repo = ref.read(rechargeRepositoryProvider);
      final result = await repo.resolveOperator(phone);
      debugPrint('[FLOW] Response received from resolve API');
      
      result
        ..onSuccess((res) {
          debugPrint('[FLOW] Parsing JSON successful. Updating operator and circle.');
          if (!mounted) return;
          ref.read(rechargeFlowProvider.notifier).setAutoDetection(res.operator, res.circle);
          debugPrint('[FLOW] State updated. Starting plans fetch automatically via plansProvider.');
        })
        ..onFailure((err) {
          debugPrint('[FLOW] resolveOperator failed: $err');
          ref.read(rechargeFlowProvider.notifier).setDetecting(false);
        });
    } catch (e, st) {
      debugPrint('[FLOW] resolveOperator threw exception: $e');
      debugPrintStack(stackTrace: st);
      ref.read(rechargeFlowProvider.notifier).setDetecting(false);
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
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: DefaultTabController(
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
                      _buildOperatorList('mobile'),
                      _buildOperatorList('postpaid'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Change Operator Error: $e');
      debugPrintStack(stackTrace: st);
    }
  }

  Widget _buildOperatorList(String serviceType) {
    return Consumer(
      builder: (context, ref, child) {
        final opsAsync = ref.watch(operatorsProvider(serviceType));
        final state = ref.watch(rechargeFlowProvider);
        
        return opsAsync.when(
          loading: () => ListView.builder(
            itemCount: 5,
            itemBuilder: (_, __) => const ListTile(
              leading: SkeletonBox(width: 40, height: 40, borderRadius: 20),
              title: SkeletonBox(width: 100, height: 16),
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (ops) {
            debugPrint('==========================');
            debugPrint('STEP 5 - UI');
            debugPrint('==========================');
            debugPrint('operators.length = ${ops.length}');
            if (ops.isEmpty) {
              return const Center(child: Text('No operators found'));
            }
            return ListView.separated(
              itemCount: ops.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final op = ops[i];
                final isSelected = state.operator?.id == op.id;
                
                Color opColor = AppColors.primaryBlue;
                String opInitials = op.name.isNotEmpty ? op.name.substring(0, 1).toUpperCase() : 'O';
              
              final nameLower = op.name.toLowerCase();
              if (nameLower.contains('airtel')) {
                opColor = Colors.red;
                opInitials = 'A';
              } else if (nameLower.contains('jio')) {
                opColor = Colors.blue;
                opInitials = 'J';
              } else if (nameLower.contains('vi') || nameLower.contains('vodafone') || nameLower.contains('idea')) {
                opColor = Colors.redAccent;
                opInitials = 'V';
              } else if (nameLower.contains('bsnl') || nameLower.contains('mtnl')) {
                opColor = Colors.orange;
                opInitials = 'B';
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                tileColor: isSelected ? AppColors.primaryBlue.withValues(alpha: 0.05) : null,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: opColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      opInitials,
                      style: TextStyle(color: opColor, fontWeight: FontWeight.bold, fontSize: 18),
                    )
                  ),
                ),
                title: Text(
                  op.name, 
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                  )
                ),
                trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primaryBlue) : null,
                onTap: () {
                  ref.read(rechargeFlowProvider.notifier).setOperator(op);
                  Navigator.pop(context);
                },
              );
            },
          );
          },
        );
      },
    );
  }

  void _selectCircle() {
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        builder: (context) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Consumer(
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
                      data: (circles) {
                        if (circles.isEmpty) return const Center(child: Text('No circles found'));
                        return ListView.separated(
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
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Change Circle Error: $e');
      debugPrintStack(stackTrace: st);
    }
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

                  if (state.isDetecting)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (hasOperator)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppColors.primaryBlueLight.withValues(alpha: 0.2),
                                        radius: 14,
                                        child: const Icon(Icons.phone_android, color: AppColors.primaryBlue, size: 14),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(_phoneController.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    ],
                                  ),
                                  InkWell(
                                    onTap: () {
                                      ref.read(rechargeFlowProvider.notifier).clearOperator();
                                      _phoneController.clear();
                                      _phoneFocusNode.requestFocus();
                                    },
                                    child: const Text('EDIT NUMBER', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (state.isAutoDetected && !state.hasManualSelection)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 4),
                                        child: Text('Detected:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text('${state.operator?.name ?? 'Unknown'} • ${state.circle?.state ?? 'Unknown'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        ),
                                        Row(
                                          children: [
                                            InkWell(
                                              onTap: _selectOperator,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('Change Operator', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 10)),
                                              )
                                            ),
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: _selectCircle,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                                child: const Text('Change Circle', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 10)),
                                              )
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (state.isAutoDetected && !state.hasManualSelection)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text('Detection may be inaccurate for ported numbers. You can change the operator or circle manually.', style: TextStyle(color: AppColors.textHint, fontSize: 10, fontStyle: FontStyle.italic)),
                                ),
                            ],
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
                  if (!hasOperator && !state.isDetecting)
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
                                  final operator = state.operator;
                                  final circle = state.circle;
                                  if (operator == null || circle == null) {
                                    return const SliverToBoxAdapter(child: SizedBox());
                                  }
                                  final plansAsync = ref.watch(plansProvider((operatorId: operator.id, circle: circle.id, serviceType: operator.type.name)));
                                
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
                                    debugPrint('\n========== PLANS DEBUG ==========');
                                    debugPrint('inside build()');
                                    debugPrint('plansProvider has ${allPlans.length} plans');
                                    debugPrint('Plans from provider: ${allPlans.length}');

                                    // Apply Search
                                    final searchQuery = _searchController.text.toLowerCase().trim();
                                    var plans = allPlans;
                                    
                                    if (searchQuery.isNotEmpty) {
                                      plans = allPlans.where((p) {
                                        final amountStr = (p.pricePaise ~/ 100).toString();
                                        return amountStr.contains(searchQuery) ||
                                               p.categoryName.toLowerCase().contains(searchQuery) ||
                                               p.description.toLowerCase().contains(searchQuery) ||
                                               p.validity.toLowerCase().contains(searchQuery) ||
                                               (p.data?.toLowerCase().contains(searchQuery) ?? false);
                                      }).toList();
                                    }

                                    // Apply Validity/Quick Filters
                                    if (_selectedQuickFilter.isNotEmpty) {
                                      final qf = _selectedQuickFilter.toLowerCase();
                                      plans = plans.where((p) {
                                        if (qf.contains('day') || qf.contains('year')) return p.validity.toLowerCase().contains(qf);
                                        if (qf.contains('gb')) return (p.data?.toLowerCase().contains(qf) ?? false);
                                        if (qf.contains('5g')) return (p.tags.any((t) => t.toLowerCase().contains('5g')) || p.description.toLowerCase().contains('5g'));
                                        return true;
                                      }).toList();
                                    }

                                    // Categorize dynamically
                                    final categoriesMap = <String, List<RechargePlan>>{};
                                    for (final p in plans) {
                                      final cat = p.categoryName;
                                      if (!categoriesMap.containsKey(cat)) categoriesMap[cat] = [];
                                      categoriesMap[cat]!.add(p);
                                    }
                                    
                                    final recommended = plans.where((p) => p.isPopular || p.isBestValue).toList();
                                    if (recommended.isNotEmpty) {
                                      categoriesMap['⭐ Recommended'] = recommended;
                                    } else if (plans.isNotEmpty) {
                                      categoriesMap['⭐ Recommended'] = plans.take(15).toList();
                                    }

                                    final activeCategories = ['⭐ Recommended'];
                                    final otherCats = categoriesMap.keys.where((c) => c != '⭐ Recommended').toList()..sort();
                                    activeCategories.addAll(otherCats);
                                    
                                    if (!activeCategories.contains(_selectedCategory)) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) setState(() => _selectedCategory = activeCategories.isNotEmpty ? activeCategories.first : '⭐ Recommended');
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Amount Payable', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.fromPaiseNoDecimal(state.customAmountPaise ?? state.selectedPlan?.pricePaise ?? 0),
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
                          onPressed: () => context.push(RouteNames.rechargeConfirm),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            '\u20B9${plan.pricePaise ~/ 100}',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          if (plan.isBestValue || plan.isPopular)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(plan.isBestValue ? 'Best Value' : 'Popular', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 95,
                      height: 36,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.primaryBlue : Colors.white,
                          foregroundColor: isSelected ? Colors.white : AppColors.primaryBlue,
                          elevation: 0,
                          padding: EdgeInsets.zero, // Important for fixed small width
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(color: AppColors.primaryBlue),
                          ),
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
          Flexible(
            child: Text(
              text, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              maxLines: 2,
              softWrap: true,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
        Flexible(
          child: Text(
            text, 
            style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w500),
            maxLines: 2, 
            softWrap: true,
            overflow: TextOverflow.ellipsis
          ),
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
                  Expanded(
                    child: Text(
                      '\u20B9${plan.pricePaise ~/ 100}',
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
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