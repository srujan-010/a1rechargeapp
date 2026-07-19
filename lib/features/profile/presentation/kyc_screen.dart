import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_card.dart';
import 'kyc_provider.dart';
import 'widgets/kyc_forms.dart';

class KycScreen extends ConsumerWidget {
  const KycScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kycState = ref.watch(kycProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('KYC Verification'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextTheme.textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: kycState.status == KycStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.pagePadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: AppSpacing.lg),
                          _buildStatusCard(kycState),
                          const SizedBox(height: AppSpacing.lg),
                          
                          if (kycState.kycModel?.status == 'verified')
                            _buildVerifiedBenefits()
                          else
                            _buildStepper(context, ref, kycState),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Unlock Full Access', style: AppTextTheme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Complete your KYC to unlock all recharge services, wallet features and higher transaction limits.',
          style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatusCard(KycState state) {
    final status = state.kycModel?.status ?? 'notStarted';
    Color color = AppColors.textHint;
    String label = 'Pending';
    String message = 'Complete the remaining steps below.';
    IconData icon = Icons.info_outline;

    if (status == 'verified') {
      color = AppColors.success;
      label = 'Verified';
      message = 'Your KYC has been approved.';
      icon = Icons.check_circle;
    } else if (status == 'rejected') {
      color = AppColors.error;
      label = 'Rejected';
      message = state.kycModel?.remarks ?? 'Please re-upload your documents.';
      icon = Icons.cancel;
    } else if (status == 'underReview') {
      color = AppColors.warning;
      label = 'Under Review';
      message = 'Your documents are being reviewed (24-48 hours).';
      icon = Icons.pending;
    } else if (status == 'pending') {
      color = AppColors.primaryBlue;
      label = 'In Progress';
    }

    return AppCard(
      backgroundColor: color.withOpacity(0.05),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextTheme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(message, style: AppTextTheme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBenefits() {
    return AppCard(
      backgroundColor: Colors.green.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Benefits Unlocked', style: AppTextTheme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
          const SizedBox(height: AppSpacing.md),
          _benefitRow('Unlimited Recharge'),
          _benefitRow('Wallet Withdrawal'),
          _benefitRow('Higher Transaction Limits'),
          _benefitRow('Commission Eligibility'),
        ],
      ),
    );
  }

  Widget _benefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.check, color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Text(text, style: AppTextTheme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildStepper(BuildContext context, WidgetRef ref, KycState state) {
    final isReadOnly = state.kycModel?.status == 'underReview' || state.kycModel?.status == 'verified';

    return Stepper(
      physics: const NeverScrollableScrollPhysics(),
      currentStep: state.currentStep,
      onStepTapped: isReadOnly ? null : (step) => ref.read(kycProvider.notifier).setStep(step),
      controlsBuilder: (context, details) => const SizedBox.shrink(),
      steps: [
        Step(
          title: const Text('Personal Information'),
          content: PersonalDetailsForm(
            isReadOnly: isReadOnly,
            onNext: () => ref.read(kycProvider.notifier).setStep(1),
          ),
          isActive: state.currentStep >= 0,
          state: state.currentStep > 0 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Aadhaar Verification'),
          content: AadhaarForm(
            isReadOnly: isReadOnly,
            onNext: () => ref.read(kycProvider.notifier).setStep(2),
          ),
          isActive: state.currentStep >= 1,
          state: state.currentStep > 1 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('PAN Verification'),
          content: PanForm(
            isReadOnly: isReadOnly,
            onNext: () => ref.read(kycProvider.notifier).setStep(3),
          ),
          isActive: state.currentStep >= 2,
          state: state.currentStep > 2 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Shop Details'),
          content: ShopForm(
            isReadOnly: isReadOnly,
            onNext: () => ref.read(kycProvider.notifier).setStep(4),
          ),
          isActive: state.currentStep >= 3,
          state: state.currentStep > 3 ? StepState.complete : StepState.indexed,
        ),
        Step(
          title: const Text('Selfie Verification'),
          content: SelfieForm(
            isReadOnly: isReadOnly,
            onSubmit: () async {
               final success = await ref.read(kycProvider.notifier).saveKycDraft(isFinalSubmit: true);
               if (success && context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KYC Submitted successfully')));
                 // Wait a moment then maybe pop or just let it rebuild to Under Review
               }
            },
          ),
          isActive: state.currentStep >= 4,
          state: state.currentStep > 4 ? StepState.complete : StepState.indexed,
        ),
      ],
    );
  }
}