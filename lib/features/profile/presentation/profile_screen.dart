import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/premium_logout_sheet.dart';
import '../../../features/auth/provider/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature coming soon')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);
    final user = sessionAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // ── Premium App Bar ─────────────────────────────────────────
            SliverAppBar(
              backgroundColor: const Color(0xFF1565FF),
              pinned: true,
              elevation: 0,
              title: Text(
                'Profile',
                style: AppTextTheme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),

            // ── Premium Profile Header ────────────────────────────────────
            SliverToBoxAdapter(
              child: _PremiumProfileHeader(user: user),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Account ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'Account'),
                    const SizedBox(height: 8),
                    _ProfileMenuCard(
                      children: [
                        _ProfileMenuItem(
                          icon: Icons.person_outline,
                          label: 'Personal Information',
                          subtitle: 'Manage your profile details',
                          onTap: () => context.push(RouteNames.personalInfo),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.verified_user_outlined,
                          label: 'KYC Verification',
                          subtitle: 'Verify your identity',
                          onTap: () => context.push(RouteNames.kyc),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.account_balance_outlined,
                          label: 'Bank Accounts',
                          subtitle: 'Manage linked bank account',
                          onTap: () => context.push(RouteNames.bankDetails),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.lock_outline,
                          label: 'Change MPIN',
                          subtitle: 'Update your security PIN',
                          onTap: () => context.push(RouteNames.changeMpin),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.restore,
                          label: 'Forgot MPIN',
                          subtitle: 'Reset your security PIN',
                          onTap: () => context.push(RouteNames.forgotMpin),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Legal ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'Legal'),
                    const SizedBox(height: 8),
                    _ProfileMenuCard(
                      children: [
                        _ProfileMenuItem(
                          icon: Icons.privacy_tip_outlined,
                          label: 'Privacy Policy',
                          subtitle: 'Read our privacy guidelines',
                          onTap: () => context.push(RouteNames.privacyPolicy),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.gavel_outlined,
                          label: 'Terms & Conditions',
                          subtitle: 'App usage rules',
                          onTap: () => context.push(RouteNames.termsAndConditions),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.assignment_return_outlined,
                          label: 'Return, Refund & Cancellation Policy',
                          subtitle: 'Our refund processes',
                          onTap: () => context.push(RouteNames.refundPolicy),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.info_outline,
                          label: 'About A1 Recharge',
                          subtitle: 'Learn more about us',
                          onTap: () => context.push(RouteNames.aboutApp),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Support ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'Support'),
                    const SizedBox(height: 8),
                    _ProfileMenuCard(
                      children: [
                        _ProfileMenuItem(
                          icon: Icons.support_agent_outlined,
                          label: 'Help & Support',
                          subtitle: 'Contact our team, view FAQs & report issues',
                          onTap: () => context.push(RouteNames.support),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── App ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionHeader(title: 'App'),
                    const SizedBox(height: 8),
                    _ProfileMenuCard(
                      children: [
                        _ProfileMenuItem(
                          icon: Icons.notifications_none,
                          label: 'Notifications',
                          subtitle: 'Manage alert preferences',
                          onTap: () => context.push(RouteNames.notificationSettings),
                        ),
                        const _Divider(),
                        _ProfileMenuItem(
                          icon: Icons.system_update_outlined,
                          label: 'App Version',
                          subtitle: 'Check for updates',
                          trailing: Text('2.1.0', style: AppTextTheme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                          onTap: () => _showComingSoon(context, 'Check for Updates'),
                        ),
                        const _Divider(),
                        _LogoutMenuItem(
                          icon: Icons.power_settings_new,
                          label: 'Logout',
                          subtitle: 'Securely sign out',
                          onTap: () => _confirmLogout(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            
            // ── Footer ────────────────────────────────────────────────
            SliverSafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 120), // Prevents overlapping with bottom nav
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      Text(
                        'App Version 2.1.0',
                        style: AppTextTheme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Powered by Vasavi Tech Solutions',
                        style: AppTextTheme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final user = ref.read(sessionProvider).valueOrNull;
    final confirmed = await PremiumLogoutSheet.show(
      context,
      merchantName: user?.name ?? 'User',
      merchantId: user != null ? 'RET000001' : '',
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(authNotifierProvider.notifier).logout();
    if (!context.mounted) return;
    context.go(RouteNames.otpLogin);
  }
}

// ─── Premium Profile Header ───────────────────────────────────────────────────

class _PremiumProfileHeader extends StatelessWidget {
  const _PremiumProfileHeader({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    DateTime? parsedDate;
    if (user?.createdAt != null) {
      if (user!.createdAt is String) {
        parsedDate = DateTime.tryParse(user!.createdAt as String);
      } else if (user!.createdAt is DateTime) {
        parsedDate = user!.createdAt as DateTime;
      }
    }

    final memberSince = parsedDate != null 
        ? DateFormat('MMM yyyy').format(parsedDate) 
        : 'Jun 2023';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1565FF), Color(0xFF0A3D91)],
        ),
      ),
      child: SafeArea(
        top: false, // SliverAppBar handles top safe area
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials(user?.name),
                    style: const TextStyle(
                      color: Color(0xFF1565FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and KYC Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            user?.shopName ?? 'A1 Retailer',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _KycBadge(isVerified: user?.isVerified == true),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? 'Merchant Name',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Responsive layout for chips to prevent overflow
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _HeaderBadge(icon: Icons.phone_android, text: user?.phone ?? '9876543210'),
                        _HeaderBadge(icon: Icons.badge, text: user?.retailerId ?? 'RET0001'),
                        Text(
                          'Joined $memberSince',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

class _KycBadge extends StatelessWidget {
  final bool isVerified;
  const _KycBadge({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? const Color(0xFF00C853) : const Color(0xFFFF8F00);
    final text = isVerified ? 'Verified' : 'Pending';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeaderBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Section Components ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: AppTextTheme.textTheme.titleMedium?.copyWith(
          color: const Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final List<Widget> children;
  const _ProfileMenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, color: Color(0xFFF1F5F9));
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextTheme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
              if (trailing != null) const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutMenuItem extends StatelessWidget {
  const _LogoutMenuItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextTheme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF64748B),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


