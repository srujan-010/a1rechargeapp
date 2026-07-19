import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // FAQ Data Structure
  final Map<String, List<Map<String, String>>> _faqCategories = {
    '📱 Mobile Recharge': [
      {
        'q': 'My recharge failed but money was deducted.',
        'a': 'If the recharge fails, the deducted amount will usually be refunded to your wallet automatically within the expected processing time. If it is not refunded, contact support with the transaction ID.'
      },
      {
        'q': 'Recharge is still pending.',
        'a': 'Some operators take additional time to process requests. Please wait and refresh the transaction status before contacting support.'
      },
      {
        'q': 'Can I repeat a previous recharge?',
        'a': 'Yes. Open Transaction History and tap "Repeat Recharge".'
      },
    ],
    '💰 Wallet': [
      {
        'q': 'How do I add money?',
        'a': 'Go to Wallet > Add Money and complete payment using UPI.'
      },
      {
        'q': 'Is there any wallet top-up fee?',
        'a': 'No. Wallet top-ups via supported payment methods are free unless otherwise notified.'
      },
      {
        'q': 'Why is my wallet balance different?',
        'a': 'Wallet balance changes after successful recharges, refunds, commissions, or wallet top-ups.'
      },
    ],
    '💵 Commission': [
      {
        'q': 'When will I receive commission?',
        'a': 'Commission is credited only after a successful recharge or bill payment.'
      },
      {
        'q': 'Why is today\'s commission showing ₹0?',
        'a': 'Commission appears only after eligible successful transactions.'
      },
    ],
    '🔐 Account': [
      {
        'q': 'How do I reset my MPIN?',
        'a': 'Go to Profile → Change MPIN and verify your account.'
      },
      {
        'q': 'How do I complete KYC?',
        'a': 'Open Profile → KYC Verification and submit the required documents.'
      },
      {
        'q': 'My account is blocked.',
        'a': 'Please contact customer support for verification and assistance.'
      },
    ],
    '⚡ Payments & Bills': [
      {
        'q': 'Which services are supported?',
        'a': '- Mobile Recharge\n- Postpaid Bills\n- DTH\n- Electricity\n- Broadband\n- FASTag\n- Gas\n- Water'
      },
      {
        'q': 'How can I download receipts?',
        'a': 'Open Transaction History, select a transaction, and tap Download Receipt.'
      },
    ],
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, List<Map<String, String>>> get _filteredFaqs {
    if (_searchQuery.trim().isEmpty) return _faqCategories;
    
    final query = _searchQuery.toLowerCase();
    final Map<String, List<Map<String, String>>> filtered = {};

    _faqCategories.forEach((category, items) {
      final matchingItems = items.where((item) {
        return item['q']!.toLowerCase().contains(query) || item['a']!.toLowerCase().contains(query);
      }).toList();

      if (matchingItems.isNotEmpty) {
        filtered[category] = matchingItems;
      }
    });

    return filtered;
  }

  Future<void> _launchUrl(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not perform this action.')));
      }
    }
  }

  void _callSupport() => _launchUrl(Uri.parse('tel:+919975600499'));
  void _emailSupport() => _launchUrl(Uri.parse('mailto:support@a1recharge.com?subject=Support%20Request'));
  void _whatsappSupport() => _launchUrl(Uri.parse('https://wa.me/919975600499'));
  
  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _filteredFaqs;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help Center'),
        backgroundColor: const Color(0xFF1565FF),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          // ── Header & Search ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1565FF),
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How can we help you?',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find answers to common questions or get in touch with our support team.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search help articles...',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primaryBlue),
                        suffixIcon: _searchQuery.isNotEmpty 
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Actions ────────────────────────────────────────────
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Actions', style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSpacing.md),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.4,
                      children: [
                        _QuickActionCard(
                          icon: Icons.phone_in_talk,
                          title: 'Contact Support',
                          subtitle: 'Call our team',
                          color: Colors.blue,
                          onTap: _callSupport,
                        ),
                        _QuickActionCard(
                          icon: Icons.chat,
                          title: 'WhatsApp',
                          subtitle: 'Chat directly',
                          color: Colors.green,
                          onTap: _whatsappSupport,
                        ),
                        _QuickActionCard(
                          icon: Icons.email,
                          title: 'Email Support',
                          subtitle: 'Send an email',
                          color: Colors.orange,
                          onTap: _emailSupport,
                        ),
                        _QuickActionCard(
                          icon: Icons.bug_report,
                          title: 'Report Issue',
                          subtitle: 'Failed transactions',
                          color: Colors.red,
                          onTap: () => context.push(RouteNames.raiseTicket),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // ── Bonus Features ────────────────────────────────────────────
          if (_searchQuery.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                child: Column(
                  children: [
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.picture_as_pdf, color: AppColors.primaryBlue),
                            title: const Text('Download User Guide'),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => _showComingSoon('User Guide PDF Download'),
                          ),
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(Icons.star_rate, color: Colors.amber),
                            title: const Text('Rate your support experience'),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () => _showComingSoon('App Rating'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),

          // ── FAQs ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_searchQuery.isEmpty ? 'Frequently Asked Questions' : 'Search Results', style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.md),
                  if (filteredCategories.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxxl),
                        child: Column(
                          children: [
                            const Icon(Icons.search_off, size: 48, color: AppColors.textHint),
                            const SizedBox(height: AppSpacing.md),
                            const Text('No FAQs found', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filteredCategories.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppCard(
                          padding: EdgeInsets.zero,
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded: _searchQuery.isNotEmpty,
                              title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                              children: entry.value.map((faq) {
                                return Column(
                                  children: [
                                    const Divider(height: 1),
                                    Theme(
                                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                      child: ExpansionTile(
                                        title: Text(faq['q']!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                        expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            faq['a']!,
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                                          ),
                                          if (faq['a']!.contains('Transaction ID')) ...[
                                            const SizedBox(height: 8),
                                            OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                minimumSize: Size.zero,
                                              ),
                                              icon: const Icon(Icons.copy, size: 14),
                                              label: const Text('Copy Transaction ID', style: TextStyle(fontSize: 12)),
                                              onPressed: () => _showComingSoon('Copy ID feature'),
                                            )
                                          ]
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // ── Support Footer Card ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const Icon(Icons.support_agent, size: 48, color: AppColors.primaryBlue),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Need more help?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 4),
                    const Text('Contact our support team directly.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: AppSpacing.lg),
                    
                    const Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('+91 99756 00499', style: TextStyle(fontWeight: FontWeight.w600)),
                              SizedBox(height: 12),
                              Text('Email', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('support@a1recharge.com', style: TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Support Hours', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('Monday – Saturday', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text('9:00 AM – 8:00 PM', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _callSupport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxxl)),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}