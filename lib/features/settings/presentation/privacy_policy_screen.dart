import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/theme/app_spacing.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          Text(content, style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Privacy Policies', style: AppTextTheme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Text('At A1Recharge (powered by Vasavi Tech Solutions), we are deeply committed to protecting your privacy and ensuring the security of your personal and financial information.\n\nThis Privacy Policy outlines how we collect, use, disclose, and safeguard your data when you use our website, mobile application, and related services.', style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
            
            _buildSection('01. Information We Collect', 'We collect various types of information to provide and improve our services to you securely and efficiently. This information is collected directly from you when you register, as well as automatically through your use of our platform.'),
            _buildSection('02. Personal Information', 'When you create an account, complete your KYC, or use our services, we may collect:\n• Full Name\n• Mobile Number\n• Email Address\n• Business Address and Location\n• KYC Documents (such as PAN, Aadhaar) where required by regulatory authorities'),
            _buildSection('03. Device Information', 'To ensure security and prevent fraud, we automatically collect information about the devices you use to access A1Recharge, including:\n• IP Address\n• Device model, OS version, and unique device identifiers\n• Browser type and version\n• Network information'),
            _buildSection('04. Transaction Information', 'When you conduct transactions through A1Recharge, we collect details related to the transaction, including:\n• Transaction amount and date\n• Beneficiary details (e.g., mobile number, consumer ID, bank account numbers)\n• Operator or service provider details\n• Wallet balance and transaction history'),
            _buildSection('05. Cookies', 'We use cookies and similar tracking technologies to enhance your experience, remember your preferences, and understand how you navigate our platform. You can configure your browser to reject cookies, though this may limit your ability to use certain features of A1Recharge.'),
            _buildSection('06. How Information is Used', 'We use the collected information for the following purposes:\n• To process your recharge and bill payment transactions instantly.\n• To verify your identity and comply with regulatory KYC requirements.\n• To calculate and disburse commissions accurately.\n• To detect, prevent, and mitigate fraud or unauthorized access.\n• To communicate with you regarding updates, offers, account alerts, and customer support.\n• To improve our application and website performance.'),
            _buildSection('07. Data Security (Bank-Grade Security)', 'We implement robust, industry-standard security measures, including 256-bit SSL encryption, to protect your data during transmission and at rest. Your sensitive financial credentials and passwords are encrypted and never stored in plain text.'),
            _buildSection('08. Third-Party Services', 'We do not sell your personal data to third parties. We only share necessary information with our telecom operators, biller partners, payment gateways, and banking partners strictly for the purpose of executing your requested transactions and complying with legal obligations.'),
            _buildSection('09. User Rights', 'Depending on applicable laws, you may have the right to access, correct, or request the deletion of your personal data. You may also opt-out of receiving promotional communications at any time. To exercise these rights, please contact our support team.'),
            _buildSection('10. Data Retention', 'We retain your personal and transaction data for as long as your account is active, or as long as necessary to fulfill the purposes outlined in this policy, comply with our legal and regulatory obligations, resolve disputes, and enforce our agreements.'),
            _buildSection('11. Children\'s Privacy', 'Our services are not intended for individuals under the age of 18. We do not knowingly collect personal information from children. If we become aware that a child has provided us with personal data, we will take steps to delete such information immediately.'),
            _buildSection('12. Policy Updates', 'We may update this Privacy Policy periodically to reflect changes in our practices or regulatory requirements. We encourage you to review this page regularly. Continued use of A1Recharge after changes are published constitutes your acceptance of the revised policy.'),
            _buildSection('Contact Information', 'A1Recharge\n\nEmail:\nvasavitechsolutions06@gmail.com\n\nPhone:\n+91 9975600499\n\nAddress:\nAnkisa, Sironcha, Gadchiroli, Maharashtra, India'),
          ],
        ),
      ),
    );
  }
}
