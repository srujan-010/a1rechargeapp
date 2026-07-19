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

  final List<int> _quickAmounts = [19, 199, 299, 666, 719, 2999];

  bool _hasContactPermission = false;

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

  // Removed _dismissPermissionCard

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
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
      result.onSuccess((operator) {
        if (!mounted) return;
        ref.read(rechargeFlowProvider.notifier).setOperator(operator);
        ref.read(rechargeFlowProvider.notifier).setCircle('Delhi NCR');
      });
    } catch (_) {}
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
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, child) {
              final opsAsync = ref.watch(operatorsProvider('mobile'));
              
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text('Select Operator', style: AppTextTheme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: opsAsync.when(
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

                  // ── Phone Input Section ──
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
                                  child: _hasContactPermission
                                      ? TextButton.icon(
                                          onPressed: () {
                                            // Handle contact picker
                                          },
                                          icon: const Icon(Icons.import_contacts, size: 16),
                                          label: const Text('Import', style: TextStyle(fontWeight: FontWeight.bold)),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primaryBlue,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                          ),
                                        )
                                      : IconButton(
                                          icon: Container(
                                            width: 44,
                                            height: 44,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primaryBlue,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.contacts, color: Colors.white, size: 20),
                                          ),
                                          padding: EdgeInsets.zero,
                                          splashRadius: 24,
                                          onPressed: () {
                                            _requestContactPermission();
                                          },
                                        ),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1.5),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5), width: 1.5),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                                ),
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                              ),
                            ),
                          ),
                          
                          // Operator details if resolved (Animated Fade In)
                          AnimatedOpacity(
                            opacity: hasOperator ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: hasOperator ? Padding(
                              padding: const EdgeInsets.only(top: AppSpacing.md),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: Colors.white,
                                      radius: 16,
                                      child: Text(state.operator!.name[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(state.operator!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          Text('${state.circle} • Prepaid', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _selectOperator,
                                      borderRadius: BorderRadius.circular(4),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        child: Text('EDIT', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ) : const SizedBox.shrink(),
                          )
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

                  // ── Quick Amounts & Plans (if operator detected) ──
                  if (hasOperator) ...[
                    // Quick Amounts
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              child: Text('Popular Amounts', style: AppTextTheme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              height: 40,
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                scrollDirection: Axis.horizontal,
                                itemCount: _quickAmounts.length,
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final amount = _quickAmounts[index];
                                  final isSelected = state.customAmountPaise == amount * 100;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    child: ActionChip(
                                      label: Text(CurrencyFormatter.fromPaiseNoDecimal(amount * 100)),
                                      labelStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : AppColors.textPrimary,
                                      ),
                                      backgroundColor: isSelected ? AppColors.primaryBlue : Colors.white,
                                      side: BorderSide(color: isSelected ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.5)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      onPressed: () {
                                        ref.read(rechargeFlowProvider.notifier).setAmount(amount * 100);
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Fetched Plans
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                        child: Text('Recommended Plans', style: AppTextTheme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final plansAsync = ref.watch(plansProvider((operatorId: state.operator!.id, circle: state.circle!)));
                        
                        return plansAsync.when(
                          loading: () => SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
                                child: SkeletonBox(width: double.infinity, height: 120, borderRadius: 12),
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
                          data: (plans) {
                            final filteredPlans = plans.where((p) => p.category != PlanCategory.data).toList();
                            return SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final plan = filteredPlans[index];
                                  final isSelected = state.selectedPlan?.id == plan.id || state.customAmountPaise == plan.pricePaise;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 6),
                                    child: AnimatedScale(
                                      scale: isSelected ? 1.02 : 1.0,
                                      duration: const Duration(milliseconds: 150),
                                      child: InkWell(
                                        onTap: () => ref.read(rechargeFlowProvider.notifier).setPlan(plan),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primaryBlueLight.withValues(alpha: 0.3) : Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isSelected ? AppColors.primaryBlue : AppColors.border.withValues(alpha: 0.3),
                                              width: isSelected ? 2 : 1,
                                            ),
                                            boxShadow: [
                                              if (!isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2))
                                            ]
                                          ),
                                          padding: const EdgeInsets.all(AppSpacing.md),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    CurrencyFormatter.fromPaiseNoDecimal(plan.pricePaise),
                                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                                                  ),
                                                  if (index == 0 || index == 2)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.amber.shade100,
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: const Text('Best Value', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _PlanDetailCol(label: 'VALIDITY', value: plan.validity),
                                                  _PlanDetailCol(label: 'DATA', value: plan.data ?? 'NA'),
                                                  _PlanDetailCol(label: 'VOICE', value: 'Unlimited'),
                                                ],
                                              ),
                                              if (plan.description.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                Divider(height: 1, color: AppColors.border.withValues(alpha: 0.3)),
                                                const SizedBox(height: 12),
                                                Text(
                                                  plan.description,
                                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ]
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: filteredPlans.length,
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 120)), // padding for sticky bottom
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
                            CurrencyFormatter.fromPaiseNoDecimal(state.customAmountPaise!),
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