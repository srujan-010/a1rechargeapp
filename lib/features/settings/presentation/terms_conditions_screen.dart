import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/theme/app_spacing.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

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
        title: const Text('Terms & Conditions'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Terms and Conditions of A1Recharge', style: AppTextTheme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Text('Welcome to A1Recharge. By downloading, registering, accessing, or using this application, you agree to comply with these Terms and Conditions. If you do not agree with these Terms, please do not use the application.', style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
            
            _buildSection('1. Acceptance of Terms', 'By creating an account or using A1Recharge, you confirm that you have read, understood, and accepted these Terms & Conditions, the Privacy Policy, and the Refund Policy.'),
            _buildSection('2. Eligibility', 'Users must be at least 18 years of age and legally capable of entering into a binding agreement under applicable law.'),
            _buildSection('3. Account Registration', 'Users must provide accurate, complete, and up-to-date information during registration. You are responsible for maintaining the confidentiality of your login credentials and for all activities carried out through your account.'),
            _buildSection('4. Services', 'A1Recharge provides services that may include:\n• Mobile Recharge\n• DTH Recharge\n• Electricity and Utility Bill Payments\n• AEPS, DMT, and other financial services (where available and after successful KYC)\nThe availability of services may change without prior notice.'),
            _buildSection('5. KYC Compliance', 'Certain services, including AEPS, DMT, or other regulated financial services, require successful KYC verification. Users agree to provide accurate KYC documents when requested.'),
            _buildSection('6. User Responsibilities', 'Users are solely responsible for entering the correct:\n• Mobile Number\n• Operator\n• Account Number\n• Consumer Number\n• Amount\n• Bank Details\n• Any other transaction information\nA1Recharge shall not be responsible for losses arising from incorrect information entered by the user.'),
            _buildSection('7. Wallet Usage', 'Wallet balances may only be used for services available within the application. Users are responsible for ensuring sufficient wallet balance before initiating any transaction.'),
            _buildSection('8. Transactions', 'All transactions are subject to successful processing by banks, payment gateways, operators, and API partners. Transaction success cannot be guaranteed in every circumstance.'),
            _buildSection('9. Failed Transactions', 'In case of technical failure, refunds or wallet credits shall be processed according to the Refund Policy. Delays caused by operators, banks, or API providers are beyond the control of A1Recharge.'),
            _buildSection('10. Commission', 'Retailer commissions are determined according to the commission structure applicable at the time of the transaction and may change without prior notice.'),
            _buildSection('11. Prohibited Activities', 'Users shall not:\n• Use the application for unlawful activities.\n• Submit false KYC information.\n• Attempt unauthorized access.\n• Abuse promotional offers.\n• Perform fraudulent transactions.\nViolation may result in immediate suspension or permanent termination.'),
            _buildSection('12. Account Suspension', 'A1Recharge reserves the right to suspend or terminate any account suspected of fraud, misuse, illegal activity, policy violations, or regulatory non-compliance.'),
            _buildSection('13. Intellectual Property', 'All content, logos, trademarks, software, graphics, and materials available within A1Recharge remain the exclusive property of the company and may not be copied or reproduced without written permission.'),
            _buildSection('14. Privacy', 'Collection and use of personal information are governed by the A1Recharge Privacy Policy.'),
            _buildSection('15. Limitation of Liability', 'To the maximum extent permitted by law, A1Recharge shall not be liable for indirect, incidental, consequential, or special damages, including losses caused by operator failures, banking systems, API provider downtime, network interruptions, or user errors.'),
            _buildSection('16. Third-Party Services', 'Certain services are provided through authorized third-party operators, banks, payment gateways, and API providers. A1Recharge is not responsible for delays or failures caused by such third parties.'),
            _buildSection('17. Changes to Terms', 'A1Recharge reserves the right to modify these Terms & Conditions at any time. Continued use of the application after changes are published constitutes acceptance of the revised Terms.'),
            _buildSection('18. Governing Law', 'These Terms & Conditions shall be governed by the laws of India. Any disputes shall be subject to the jurisdiction of the competent courts where the company is registered.'),
            
            _buildSection('Contact Information', 'For any questions or grievances regarding these Terms & Conditions, please contact:\nA1Recharge\nEmail: vasavitechsolutions06@gmail.com\nPhone: 9975600499\nAddress: Ankisa, sironcha, gadchiroli'),
          ],
        ),
      ),
    );
  }
}
