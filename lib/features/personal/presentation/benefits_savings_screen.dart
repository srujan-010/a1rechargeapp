import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/utils/app_navigation.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_widget.dart';
import 'personal_providers.dart';

class BenefitsSavingsScreen extends ConsumerStatefulWidget {
  const BenefitsSavingsScreen({super.key});

  @override
  ConsumerState<BenefitsSavingsScreen> createState() => _BenefitsSavingsScreenState();
}

class _BenefitsSavingsScreenState extends ConsumerState<BenefitsSavingsScreen> {
  String _selectedService = 'all';
  String _selectedOperator = 'all';

  final List<({String key, String label, IconData icon})> _services = [
    (key: 'all', label: 'All Services', icon: Icons.grid_view_rounded),
    (key: 'mobile', label: 'Mobile', icon: Icons.smartphone_rounded),
    (key: 'dth', label: 'DTH', icon: Icons.tv_rounded),
    (key: 'electricity', label: 'Electricity', icon: Icons.bolt_rounded),
    (key: 'gas', label: 'Gas', icon: Icons.local_fire_department_rounded),
    (key: 'fastag', label: 'FASTag', icon: Icons.directions_car_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final benefitsAsync = ref.watch(personalBenefitsProvider);
    final savingsAsync = ref.watch(personalSavingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Benefits & Savings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 1),
            Text('Save more on every recharge', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.normal)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AppNavigation.pop(context, fallbackRoute: RouteNames.dashboard),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(personalBenefitsProvider);
            ref.invalidate(personalSavingsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. PERSONAL ACCOUNT BADGE ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'PERSONAL ACCOUNT',
                                  style: TextStyle(
                                    color: Color(0xFF1E40AF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(Icons.verified_rounded, color: Color(0xFF2563EB), size: 14),
                              ],
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Your applicable savings & commission rates',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 2. SUMMARY CARD (REAL DATA ONLY) ──
                savingsAsync.when(
                  data: (s) => _SavingsSummaryCard(savings: s),
                  loading: () => const _SummaryCardSkeleton(),
                  error: (_, __) => const _SavingsSummaryCard(
                    savings: null,
                  ),
                ),
                const SizedBox(height: 20),

                // ── 3. SERVICE FILTER PILLS (HORIZONTAL SCROLL) ──
                const Text('Service Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _services.map((svc) {
                      final isSelected = _selectedService == svc.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          showCheckmark: false,
                          selected: isSelected,
                          avatar: Icon(svc.icon, size: 16, color: isSelected ? Colors.white : AppColors.primaryBlue),
                          label: Text(svc.label),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          backgroundColor: Colors.white,
                          selectedColor: AppColors.primaryBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryBlue : AppColors.border,
                            ),
                          ),
                          onSelected: (val) {
                            setState(() {
                              _selectedService = svc.key;
                              _selectedOperator = 'all';
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── 4. SLABS BODY WITH CACHING & SKELETON UX ──
                benefitsAsync.when(
                  data: (rawSlabs) {
                    final slabs = deduplicateSlabs(rawSlabs);

                    if (slabs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: EmptyStateWidget(
                          title: 'No Commission Rates Available',
                          description: 'Your savings rates are currently being updated. Check back shortly!',
                        ),
                      );
                    }

                    // Extract unique operators for dropdown filter
                    final availableOperators = <String>{'all'};
                    for (final s in slabs) {
                      if (_selectedService == 'all' || s.serviceType == _selectedService) {
                        if (s.operatorName.isNotEmpty) {
                          availableOperators.add(s.operatorName);
                        }
                      }
                    }

                    // Apply filters
                    final filteredSlabs = slabs.where((s) {
                      final matchesService = _selectedService == 'all' || s.serviceType == _selectedService;
                      final matchesOperator = _selectedOperator == 'all' || s.operatorName == _selectedOperator;
                      return matchesService && matchesOperator;
                    }).toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Operator Dropdown Filter Header
                        if (availableOperators.length > 2) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${filteredSlabs.length} Rates Available',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButton<String>(
                                  value: availableOperators.contains(_selectedOperator) ? _selectedOperator : 'all',
                                  underline: const SizedBox.shrink(),
                                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedOperator = val);
                                  },
                                  items: availableOperators.map((op) {
                                    return DropdownMenuItem<String>(
                                      value: op,
                                      child: Text(op == 'all' ? 'All Operators' : op),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (filteredSlabs.isEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: EmptyStateWidget(
                              title: 'No Matching Rates Found',
                              description: 'Try changing your service or operator filter above.',
                            ),
                          ),
                        ] else ...[
                          ...filteredSlabs.map((slab) => _SlabCardTile(slab: slab)),
                        ],
                      ],
                    );
                  },
                  loading: () => const _SlabsListSkeleton(),
                  error: (err, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 44),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load your savings rates.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          const Text('Please check your network connection and try again.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.invalidate(personalBenefitsProvider),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Try Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── SUMMARY CARD WIDGET ───
class _SavingsSummaryCard extends StatelessWidget {
  final PersonalSavings? savings;

  const _SavingsSummaryCard({this.savings});

  @override
  Widget build(BuildContext context) {
    final double monthly = savings?.monthlySavings ?? 0.0;
    final double lifetime = savings?.lifetimeSavings ?? 0.0;
    final bool hasEarnings = lifetime > 0;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Savings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 1),
                    Text(
                      'Earn commission on eligible recharges & bill payments.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          if (hasEarnings) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _StatColumn(label: 'This Month', amount: CurrencyFormatter.fromRupees(monthly))),
                Container(height: 32, width: 1, color: Colors.white24),
                Expanded(child: _StatColumn(label: 'Lifetime Savings', amount: CurrencyFormatter.fromRupees(lifetime))),
              ],
            ),
          ] else ...[
            const Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Start earning with your first recharge 💙',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String amount;

  const _StatColumn({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(amount, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ─── SLAB CARD TILE ───
class _SlabCardTile extends StatelessWidget {
  final PersonalBenefitSlab slab;

  const _SlabCardTile({required this.slab});

  void _showCalculatorModal(BuildContext context) {
    final isPercentage = slab.commissionType == 'percentage';
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
                  Flexible(
                    child: Text(
                      '${slab.operatorName} Savings',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPercentage ? '${rate.toStringAsFixed(2)}% Earned' : '₹${rate.toStringAsFixed(2)} Flat Earned',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Sample Earnings Calculator:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              _SampleRow(amount: 100, earned: isPercentage ? (100 * rate / 100) : rate),
              const Divider(),
              _SampleRow(amount: 299, earned: isPercentage ? (299 * rate / 100) : rate),
              const Divider(),
              _SampleRow(amount: 500, earned: isPercentage ? (500 * rate / 100) : rate),
              const Divider(),
              _SampleRow(amount: 1000, earned: isPercentage ? (1000 * rate / 100) : rate),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
    final isPercentage = slab.commissionType == 'percentage';
    final val = slab.commissionValue;
    final String rateLabel = isPercentage ? '${val.toStringAsFixed(2)}%' : '₹${val.toStringAsFixed(2)} Flat';
    final double sampleEarn100 = isPercentage ? (100 * val / 100) : val;

    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: () => _showCalculatorModal(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryBlueLight.withValues(alpha: 0.15),
          radius: 20,
          child: Text(
            slab.operatorName.isNotEmpty ? slab.operatorName[0].toUpperCase() : 'O',
            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                slab.operatorName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                slab.serviceType.toUpperCase(),
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'You earn ₹${sampleEarn100.toStringAsFixed(2)} on ₹100 recharge',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Text(
            rateLabel,
            style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _SampleRow extends StatelessWidget {
  final double amount;
  final double earned;

  const _SampleRow({required this.amount, required this.earned});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Recharge ₹${amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          Text('You Earn +₹${earned.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─── SKELETON WIDGETS ───
class _SummaryCardSkeleton extends StatelessWidget {
  const _SummaryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
    );
  }
}

class _SlabsListSkeleton extends StatelessWidget {
  const _SlabsListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.4)),
          ),
          child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      ),
    );
  }
}
