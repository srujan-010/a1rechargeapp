import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../recharge/presentation/recharge_providers.dart';

class DthRechargeScreen extends ConsumerStatefulWidget {
  const DthRechargeScreen({super.key});

  @override
  ConsumerState<DthRechargeScreen> createState() => _DthRechargeScreenState();
}

class _DthRechargeScreenState extends ConsumerState<DthRechargeScreen> {
  final _subscriberIdController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure we start with a clean state for DTH
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(rechargeFlowProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _subscriberIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onSubscriberIdChanged(String value) {
    ref.read(rechargeFlowProvider.notifier).setPhoneNumber(value); // we map phone_number to subscriber_id internally
  }

  void _onAmountChanged(String value) {
    final num = int.tryParse(value) ?? 0;
    ref.read(rechargeFlowProvider.notifier).setAmount(num * 100); // Store in paise
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
              final opsAsync = ref.watch(operatorsProvider('dth'));
              
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
                              ref.read(rechargeFlowProvider.notifier).setOperator(op);
                              // We use a dummy circle for DTH usually
                              ref.read(rechargeFlowProvider.notifier).setCircle('All India'); 
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
    
    if (state.customAmountPaise != null) {
      final textAmount = (state.customAmountPaise! ~/ 100).toString();
      if (_amountController.text != textAmount) {
        _amountController.text = textAmount;
      }
    }

    final isValid = state.phoneNumber != null && state.phoneNumber!.length >= 8 &&
                    state.operator != null &&
                    state.customAmountPaise != null && state.customAmountPaise! > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('DTH Recharge'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Operator Selection First for DTH ──
              Text('DTH Operator', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 0),
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryBlueLight,
                    child: Icon(Icons.satellite_alt, color: AppColors.primaryBlue),
                  ),
                  title: Text(state.operator?.name ?? 'Select Operator'),
                  trailing: state.operator == null 
                      ? const Icon(Icons.arrow_forward_ios, size: 16)
                      : TextButton(
                          onPressed: _selectOperator,
                          child: const Text('Change'),
                        ),
                  onTap: state.operator == null ? _selectOperator : null,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              if (state.operator != null) ...[
                // ── Subscriber ID ──
                Text('Subscriber ID / VC Number', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _subscriberIdController,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  ],
                  onChanged: _onSubscriberIdChanged,
                  decoration: const InputDecoration(
                    hintText: 'Enter Subscriber ID',
                    prefixIcon: Icon(Icons.tv),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

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
                const SizedBox(height: AppSpacing.xxxl),

                // ── Proceed Button ──
                AppButton(
                  label: 'Proceed to Pay',
                  onPressed: isValid ? () {
                    // Reuse the mobile recharge confirmation screen
                    context.push(RouteNames.rechargeConfirm);
                  } : null,
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}