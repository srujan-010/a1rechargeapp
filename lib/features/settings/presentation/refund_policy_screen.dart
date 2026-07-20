import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/theme/app_spacing.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

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
        title: const Text('Refund Policy'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Refund Policies', style: AppTextTheme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            Text('Thank you for using A1 Recharge, growing mobile recharge and utility payments platforms. We strive to provide good service and ensure customer satisfaction. This refund policy outlines the terms and conditions regarding refunds for mobile recharge transactions made through the A1 Recharge platform.', style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: AppSpacing.lg),
            
            _buildSection('1. Eligibility For Refunds', '1.1 A1Recharge will provide refunds only in the following case:\n1.2 If a mobile recharge, Utility payments or other transaction fails due to technical issues or errors on our platform.\n1.3 Refund request for failed transactions must be reported by the user within 24 hours from the date of the failed transaction.\n1.4 Money will be refunded within 24 hours if transaction failed due to our error.\n1.5 Users are allowed up to 10 refund requests per calendar month for transactions that failed due to user’s error, including entering an incorrect mobile number, operator/circle, or recharge amount. From the 11th such request onwards, a processing fee of Rs 10 per request will be deducted from the user’s wallet.'),
            _buildSection('2. Refunds Request Process', '2.1 To request a refund for a failed transaction, the user must contact A1Recharge customer support within 24 hours from the date of the failed transaction.\n2.2 The user must provide the following details:\n   a) Transaction ID or Reference number\n   b) Mobile number for which the recharge was intended\n   c) Date and time for the transaction\n   d) Reason for the refund request\n2.3 Refund requests can be submitted by contacting our customer support via email or phone. Contact details are available on our website.'),
            _buildSection('3. Refund Processing', '3.1 A1Recharge will review the refund request and the provided details within 3-5 working days of receiving the request.\n3.2 If the refund request for a failed transaction is approved, the refund amount will be credited to the user’s A1Recharge wallet within 3-5 working days.\n3.3 The refunded amount can be used for future mobile recharges or other transactions on the A1Recharge platform.'),
            _buildSection('4. Changes to the Refund Policy', '4.1 A1Recharge reserves the right to modify or update this refund policy at any time. Any changes to the policy will be effective immediately upon posting on our website.\n4.2 It is the user’s responsibility to review the refund policy periodically to stay informed about any updates or changes.\n\nIf you have any questions or concerns regarding our refund policy, please contact our customer support team, who will be happy to assist you.'),
            _buildSection('Contact Information', 'A1Recharge\n\nEmail:\nvasavitechsolutions06@gmail.com\n\nPhone:\n+91 9975600499\n\nAddress:\nAnkisa, Sironcha, Gadchiroli, Maharashtra, India'),
          ],
        ),
      ),
    );
  }
}
