import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Services'),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            // Active Premium Services
            _PremiumServiceCard(
              title: 'Mobile Recharge',
              description: 'Prepaid & Postpaid mobile recharges across all operators instantly.',
              icon: Icons.phone_android,
              gradient: const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.push(RouteNames.mobileRecharge),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PremiumServiceCard(
              title: 'DTH Recharge',
              description: 'Recharge your Direct-To-Home connections with latest plans.',
              icon: Icons.tv,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFA726), Color(0xFFFB8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: () => context.push(RouteNames.dthRecharge),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PremiumServiceCard(
              title: 'Electricity Bill',
              description: 'Pay electricity bills securely with instant settlement.',
              icon: Icons.lightbulb_outline,
              gradient: const LinearGradient(
                colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              // Use string replacement for the path parameter if it's defined as a path
              onTap: () => context.push(RouteNames.bbpsBiller.replaceAll(':category', 'electricity')),
            ),
            
            const SizedBox(height: 60),
            
            // Coming Soon Section
            const Text(
              'More services coming soon',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: const [
                _ComingSoonChip(label: 'AEPS'),
                _ComingSoonChip(label: 'DMT'),
                _ComingSoonChip(label: 'BBPS'),
                _ComingSoonChip(label: 'FASTag'),
                _ComingSoonChip(label: 'Insurance'),
                _ComingSoonChip(label: 'Gas'),
                _ComingSoonChip(label: 'Water'),
                _ComingSoonChip(label: 'PAN'),
                _ComingSoonChip(label: 'Travel'),
                _ComingSoonChip(label: 'Loans'),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _PremiumServiceCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _PremiumServiceCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left Accent
              Container(
                width: 6,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: gradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: gradient.colors.first.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: AppTextTheme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description,
                              style: AppTextTheme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonChip extends StatelessWidget {
  final String label;
  
  const _ComingSoonChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
