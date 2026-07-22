import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';

class BbpsScreen extends StatelessWidget {
  const BbpsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {'name': 'Electricity', 'icon': Icons.lightbulb_outline, 'id': 'electricity'},
      {'name': 'FASTag Recharge', 'icon': Icons.directions_car_outlined, 'id': 'fastag'},
      {'name': 'Water', 'icon': Icons.water_drop_outlined, 'id': 'water'},
      {'name': 'Piped Gas', 'icon': Icons.gas_meter_outlined, 'id': 'gas'},
      {'name': 'Broadband', 'icon': Icons.router_outlined, 'id': 'broadband'},
      {'name': 'Postpaid', 'icon': Icons.phone_android, 'id': 'postpaid'},
      {'name': 'Cable TV', 'icon': Icons.tv, 'id': 'cable'},
      {'name': 'Insurance', 'icon': Icons.health_and_safety_outlined, 'id': 'insurance'},
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pay Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          )
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // BBPS Logo/Banner
              AppCard(
                backgroundColor: AppColors.primaryBlueLight,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          'BBPS',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bharat BillPay',
                            style: AppTextTheme.textTheme.titleMedium?.copyWith(
                              color: AppColors.primaryBlue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Safe, Secure & Fast bill payments',
                            style: AppTextTheme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              
              Text('Biller Categories', style: AppTextTheme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.85,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _CategoryItem(
                    name: cat['name'] as String,
                    icon: cat['icon'] as IconData,
                    onTap: () {
                      final categoryId = cat['id'] as String;
                      if (categoryId == 'electricity') {
                        context.push(RouteNames.bbpsStateSelection.replaceFirst(':category', categoryId));
                      } else {
                        context.push(RouteNames.bbpsBiller.replaceFirst(':category', categoryId));
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.name,
    required this.icon,
    required this.onTap,
  });
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            name,
            style: AppTextTheme.textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
