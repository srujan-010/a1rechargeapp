import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import 'bbps_providers.dart';

class BbpsFetchScreen extends ConsumerStatefulWidget {
  const BbpsFetchScreen({super.key, required this.billerId});
  final String billerId;

  @override
  ConsumerState<BbpsFetchScreen> createState() => _BbpsFetchScreenState();
}

class _BbpsFetchScreenState extends ConsumerState<BbpsFetchScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _fetchBill() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
      });

      try {
        await ref.read(bbpsFlowProvider.notifier).fetchBill();
        if (!mounted) return;
        
        context.push(RouteNames.bbpsPayConfirm.replaceFirst(':billerId', widget.billerId));
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMsg = e is AppException ? e.message : e.toString();
          });
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bbpsFlowProvider);
    final biller = state.selectedBiller;

    if (biller == null || biller.id != widget.billerId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fetch Bill')),
        body: const Center(child: Text('Invalid state. Please go back and select a biller.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(biller.name),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryBlueLight,
                        child: Text(
                          biller.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(biller.name, style: AppTextTheme.textTheme.titleSmall),
                            Text(biller.category, style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                
                Text('Enter Details', style: AppTextTheme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.md),
                
                // Dynamically build fields for each parameter
                ...biller.parameters.map((param) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(param.displayName, style: AppTextTheme.textTheme.bodyMedium),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          initialValue: state.enteredParameters[param.name],
                          decoration: InputDecoration(
                            hintText: 'Enter ${param.displayName}',
                          ),
                          onChanged: (value) {
                            ref.read(bbpsFlowProvider.notifier).updateParameter(param.name, value);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '${param.displayName} is required';
                            }
                            if (value.length < param.minLength) {
                              return 'Must be at least ${param.minLength} characters';
                            }
                            if (value.length > param.maxLength) {
                              return 'Cannot exceed ${param.maxLength} characters';
                            }
                            if (param.regex.isNotEmpty && !RegExp(param.regex).hasMatch(value)) {
                              return 'Invalid format';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  );
                }),

                if (_errorMsg != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _errorMsg!,
                      style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
                
                const SizedBox(height: AppSpacing.xl),
                
                if (biller.isFetchRequirement)
                  AppButton(
                    label: 'Fetch Bill',
                    isLoading: _isLoading,
                    onPressed: _fetchBill,
                  )
                else
                  AppButton(
                    label: 'Proceed to Pay',
                    onPressed: () {
                      context.push(RouteNames.bbpsPayConfirm.replaceFirst(':billerId', widget.billerId));
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
