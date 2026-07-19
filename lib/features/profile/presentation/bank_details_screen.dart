import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/widgets/pin_entry_widget.dart';
import '../domain/models/bank_details.dart';
import 'bank_details_provider.dart';

class BankDetailsScreen extends ConsumerWidget {
  const BankDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bankDetailsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bank Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextTheme.textTheme.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SafeArea(
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, BankDetailsState state) {
    if (state.status == BankDetailsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == BankDetailsStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              state.errorMessage ?? 'An error occurred',
              style: AppTextTheme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(bankDetailsProvider.notifier).fetchBankDetails(),
              child: const Text('Retry'),
            )
          ],
        ),
      );
    }

    if (state.status == BankDetailsStatus.empty || state.bankDetails == null) {
      return _buildEmptyState(context);
    }

    return _buildPopulatedState(context, ref, state.bankDetails!);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_balance, size: 100, color: AppColors.primaryBlue),
          const SizedBox(height: AppSpacing.xxxl),
          Text(
            'No Bank Account Added',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Add your bank account to receive wallet settlements and commissions.',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: () => context.push('${RouteNames.profileView}/add-bank'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: AppColors.primaryBlue,
            ),
            child: const Text(
              '+ Add Bank Account', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopulatedState(BuildContext context, WidgetRef ref, BankDetails bank) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text(
            'Manage the bank account used for settlements, wallet withdrawals and commission payments.',
            style: AppTextTheme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _BankCard(bank: bank),
          const SizedBox(height: AppSpacing.xxxl),
          
          _ActionMenuItem(
            icon: Icons.edit_outlined,
            title: 'Edit Account Details',
            onTap: () => _requireMpin(context, ref, (mpin) {
              context.push('${RouteNames.profileView}/add-bank', extra: {'bank': bank, 'mpin': mpin});
            }),
          ),
          const Divider(height: 1),
          _ActionMenuItem(
            icon: Icons.swap_horiz,
            title: 'Replace Bank Account',
            onTap: () => _requireMpin(context, ref, (mpin) {
              context.push('${RouteNames.profileView}/add-bank', extra: {'mpin': mpin});
            }),
          ),
          const Divider(height: 1),
          _ActionMenuItem(
            icon: Icons.delete_outline,
            title: 'Delete Account',
            textColor: AppColors.error,
            iconColor: AppColors.error,
            onTap: () => _requireMpin(context, ref, (mpin) {
              // Delete action comes from inside the MPIN sheet now, so we don't need to do anything here if it succeeds.
            }, isDelete: true),
          ),
        ],
      ),
    );
  }

  void _requireMpin(BuildContext context, WidgetRef ref, void Function(String mpin) onSuccess, {bool isDelete = false}) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MpinVerificationSheet(
        isDelete: isDelete,
      ),
    );

    if (result is String) {
      onSuccess(result);
    }
  }
}

class _BankCard extends StatelessWidget {
  final BankDetails bank;
  const _BankCard({required this.bank});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)], // Premium Bank Card Gradient
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    bank.bankName.toUpperCase(),
                    style: AppTextTheme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              _StatusBadge(status: bank.verificationStatus),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            bank.accountNumber,
            style: AppTextTheme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 4.0,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACCOUNT HOLDER',
                    style: AppTextTheme.textTheme.labelSmall?.copyWith(
                      color: Colors.white60,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bank.accountHolderName.toUpperCase(),
                    style: AppTextTheme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'IFSC / TYPE',
                    style: AppTextTheme.textTheme.labelSmall?.copyWith(
                      color: Colors.white60,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${bank.ifsc} • ${bank.accountType}',
                    style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (bank.verificationRemarks != null && bank.verificationRemarks!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bank.verificationRemarks!,
                      style: AppTextTheme.textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'verified':
        color = AppColors.success;
        text = 'Verified';
        icon = Icons.check_circle;
        break;
      case 'rejected':
        color = AppColors.error;
        text = 'Rejected';
        icon = Icons.cancel;
        break;
      case 'pending':
      default:
        color = AppColors.warning;
        text = 'Pending';
        icon = Icons.pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _ActionMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextTheme.textTheme.titleMedium?.copyWith(
                  color: textColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

class _MpinVerificationSheet extends ConsumerStatefulWidget {
  final bool isDelete;
  
  const _MpinVerificationSheet({required this.isDelete});

  @override
  ConsumerState<_MpinVerificationSheet> createState() => _MpinVerificationSheetState();
}

class _MpinVerificationSheetState extends ConsumerState<_MpinVerificationSheet> {
  bool _isLoading = false;
  String? _error;

  void _verify(String mpin) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (widget.isDelete) {
      final success = await ref.read(bankDetailsProvider.notifier).deleteBankDetails(mpin);
      if (success) {
        if (mounted) {
          Navigator.pop(context, mpin);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bank details deleted'), backgroundColor: AppColors.success),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _error = ref.read(bankDetailsProvider).errorMessage ?? 'Invalid MPIN';
          });
        }
      }
    } else {
      // For Edit/Replace, just navigating after MPIN validation.
      // Wait, we need to validate MPIN before navigating. We can't validate MPIN without a backend call unless we have a specific /verify-mpin route.
      // Since we don't have a standalone /verify-mpin route, we will just pass the MPIN to the next screen and validate on save!
      // But the requirements say: "Before changing bank account, Require OTP or 6-digit MPIN. Show confirmation dialog."
      // Let's pass the MPIN to the AddBankScreen so it can use it when calling PUT /api/bank.
      // Wait, passing the MPIN around might be okay, or we can just pop and pass it back.
      Navigator.pop(context, mpin); 
      // wait, `onSuccess` doesn't take args. I will change `onSuccess` to not be used for edit.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSpacing.pagePadding,
        right: AppSpacing.pagePadding,
        top: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Security Verification',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.isDelete 
              ? 'Enter your 6-digit MPIN to delete your bank account.'
              : 'Enter your 6-digit MPIN to modify your bank account.',
            textAlign: TextAlign.center,
            style: AppTextTheme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          PinEntryWidget(
            length: 6,
            autofocus: true,
            errorText: _error,
            onCompleted: _isLoading ? (_) {} : (pin) {
              if (widget.isDelete) {
                _verify(pin);
              } else {
                // If not delete, just pop with the pin
                Navigator.pop(context, pin);
              }
            },
          ),
          const SizedBox(height: 32),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
