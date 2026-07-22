import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/models/bbps_models.dart';
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
  int _loadingStep = 0;
  Timer? _loadingTimer;

  final List<String> _loadingSteps = [
    'Verifying consumer details...',
    'Contacting provider securely...',
    'Fetching your latest bill...',
  ];

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchBill() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMsg = null;
        _loadingStep = 0;
      });
      
      debugPrint('[FLUTTER] Fetch Bill button pressed. Starting fetch flow for biller: ${widget.billerId}');

      // Start loading step animation
      _loadingTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
        if (!mounted) return;
        setState(() {
          if (_loadingStep < _loadingSteps.length - 1) {
            _loadingStep++;
          }
        });
      });

      try {
        await ref.read(bbpsFlowProvider.notifier).fetchBill();
        if (!mounted) return;
        
        // Before pushing, let's log the details as requested
        final flowState = ref.read(bbpsFlowProvider);
        debugPrint('--- BBPS FETCH LOG ---');
        debugPrint('Raw Navigation Argument (Biller ID): ${widget.billerId}');
        debugPrint('Entered Parameters: ${flowState.enteredParameters}');
        debugPrint('Parsed Bill Model: ${flowState.fetchedBill}');
        debugPrint('----------------------');

        context.push(RouteNames.bbpsPayConfirm.replaceFirst(':billerId', widget.billerId));
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMsg = e is AppException ? e.message : 'Something went wrong. Please check your details and try again.';
          });
        }
      } finally {
        _loadingTimer?.cancel();
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  void _showSampleBill(BuildContext context, String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: AppSpacing.md),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Sample Bill', style: AppTextTheme.textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Look for the highlighted details on your physical or digital bill.',
                      style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 400,
                            color: AppColors.surfaceVariant,
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 400,
                          color: AppColors.surfaceVariant,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 64, color: AppColors.textHint),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bbpsFlowProvider);
    final biller = state.selectedBiller;

    if (biller == null || biller.id != widget.billerId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fetch Bill')),
        body: const Center(child: Text('Invalid state. Please go back and select a provider.')),
      );
    }

    // Filter out invalid/empty parameters
    final validParameters = biller.parameters.where((param) => param.name.isNotEmpty && param.displayName.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Consumer Details'),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Premium Compact Provider Card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.divider, width: 1),
                              ),
                              child: Center(
                                child: biller.iconUrl.isNotEmpty
                                    ? Image.network(biller.iconUrl, width: 32, height: 32)
                                    : Text(
                                        biller.name.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 20),
                                      ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    biller.name,
                                    style: AppTextTheme.textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Securely fetch your latest bill',
                                    style: AppTextTheme.textTheme.labelMedium?.copyWith(color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      if (biller.requiresDistrictCode)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Consumer(
                            builder: (context, ref, _) {
                              final districtsAsync = ref.watch(billerDistrictsProvider(biller.id));

                              return districtsAsync.when(
                                data: (districts) {
                                  if (districts.isEmpty) {
                                    return const SizedBox.shrink();
                                  }

                                  return DropdownButtonFormField<BillerDistrict>(
                                    value: state.selectedDistrict,
                                    decoration: InputDecoration(
                                      labelText: 'District',
                                      hintText: 'Select District',
                                      floatingLabelBehavior: FloatingLabelBehavior.auto,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.divider),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.divider),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: AppColors.cardWhite,
                                    ),
                                    items: districts.map((d) {
                                      return DropdownMenuItem(
                                        value: d,
                                        child: Text(d.districtName),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        ref.read(bbpsFlowProvider.notifier).setDistrict(val);
                                      }
                                    },
                                    validator: (val) {
                                      if (val == null) {
                                        return 'District is required';
                                      }
                                      return null;
                                    },
                                  );
                                },
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (err, _) => Text(
                                  'Error loading districts',
                                  style: TextStyle(color: AppColors.error),
                                ),
                              );
                            },
                          ),
                        ),

                      // Dynamic Form Fields (Data Driven)
                      ...validParameters.map((param) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                initialValue: state.enteredParameters[param.name],
                                keyboardType: TextInputType.text,
                                decoration: InputDecoration(
                                  labelText: '${param.displayName}${param.isOptional ? " (Optional)" : ""}',
                                  hintText: 'Enter ${param.displayName}',
                                  floatingLabelBehavior: FloatingLabelBehavior.auto,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.divider),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.divider),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.cardWhite,
                                ),
                                onChanged: (value) {
                                  ref.read(bbpsFlowProvider.notifier).updateParameter(param.name, value);
                                },
                                validator: (value) {
                                  if (!param.isOptional && (value == null || value.isEmpty)) {
                                    return '${param.displayName} is required';
                                  }
                                  if (value != null && value.isNotEmpty) {
                                    if (value.length < param.minLength) {
                                      return 'Must be at least ${param.minLength} characters';
                                    }
                                    if (value.length > param.maxLength) {
                                      return 'Cannot exceed ${param.maxLength} characters';
                                    }
                                    if (param.regex.isNotEmpty && !RegExp(param.regex).hasMatch(value)) {
                                      return 'Invalid format for ${param.displayName}';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              if (param.helperText != null && param.helperText!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    param.helperText!,
                                    style: AppTextTheme.textTheme.labelSmall?.copyWith(color: AppColors.textHint),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                      if (biller.sampleBillUrl != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _showSampleBill(context, biller.sampleBillUrl!),
                            icon: const Icon(Icons.help_outline, size: 18),
                            label: const Text('Where can I find this?'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // Fixed Bottom Section
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                child: Column(
                  children: [
                    if (_errorMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.errorLight),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _errorMsg!,
                                style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: AppColors.primaryBlue),
                            const SizedBox(height: AppSpacing.md),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _loadingSteps[_loadingStep],
                                key: ValueKey<int>(_loadingStep),
                                style: AppTextTheme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: biller.isFetchRequirement ? 'Fetch Bill' : 'Proceed to Pay',
                          onPressed: _fetchBill,
                          isLoading: false,
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
