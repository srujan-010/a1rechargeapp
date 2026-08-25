import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import 'personal_providers.dart';

class BenefitsSavingsScreen extends ConsumerWidget {
  const BenefitsSavingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final benefitsAsync = ref.watch(personalBenefitsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Benefits & Savings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigation.pop(context, fallbackRoute: RouteNames.dashboard),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: benefitsAsync.when(
          data: (slabs) {
            final mobileSlabs = slabs.where((s) => s.serviceType == 'mobile').toList();
            final dthSlabs = slabs.where((s) => s.serviceType == 'dth').toList();
            final electricitySlabs = slabs.where((s) => s.serviceType == 'electricity' || s.serviceType == 'bbps').toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Info Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.savings_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Save on Every Recharge 💰',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Instant savings applied automatically at checkout.',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mobile Section
                  if (mobileSlabs.isNotEmpty) ...[
                    _SectionHeader(title: '📱 Mobile Recharge Savings', subtitle: 'Applicable across all prepaid operators'),
                    const SizedBox(height: 12),
                    ...mobileSlabs.map((slab) => _SlabTile(slab: slab)),
                    const SizedBox(height: 24),
                  ],

                  // DTH Section
                  if (dthSlabs.isNotEmpty) ...[
                    _SectionHeader(title: '📺 DTH Recharge Savings', subtitle: 'Applicable across all DTH connections'),
                    const SizedBox(height: 12),
                    ...dthSlabs.map((slab) => _SlabTile(slab: slab)),
                    const SizedBox(height: 24),
                  ],

                  // Electricity Section
                  if (electricitySlabs.isNotEmpty) ...[
                    _SectionHeader(title: '⚡ Bill Payment Savings', subtitle: 'Utility & electricity bill discounts'),
                    const SizedBox(height: 12),
                    ...electricitySlabs.map((slab) => _SlabTile(slab: slab)),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Failed to load benefits: $err')),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

class _SlabTile extends StatelessWidget {
  final PersonalBenefitSlab slab;

  const _SlabTile({required this.slab});

  void _showCalculatorBottomSheet(BuildContext context) {
    final rate = slab.commissionValue;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${slab.operatorName} Benefit', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${rate.toStringAsFixed(2)}% Instant Saving',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Sample Savings Calculator:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),

              _CalculatorRow(amount: 100, savings: 100 * (rate / 100)),
              const Divider(),
              _CalculatorRow(amount: 299, savings: 299 * (rate / 100)),
              const Divider(),
              _CalculatorRow(amount: 500, savings: 500 * (rate / 100)),
              const Divider(),
              _CalculatorRow(amount: 1000, savings: 1000 * (rate / 100)),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: () => _showCalculatorBottomSheet(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlueLight.withOpacity(0.15),
          child: Text(
            slab.operatorName.isNotEmpty ? slab.operatorName[0] : 'O',
            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(slab.operatorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: const Text('Tap to view sample savings', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Text(
            '${slab.commissionValue.toStringAsFixed(2)}% Save',
            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _CalculatorRow extends StatelessWidget {
  final double amount;
  final double savings;

  const _CalculatorRow({required this.amount, required this.savings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Recharge ₹${amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('You save ₹${savings.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
