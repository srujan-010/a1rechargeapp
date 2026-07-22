import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_theme.dart';
import 'bbps_providers.dart';
import 'dart:math';

class BbpsStateSelectionScreen extends ConsumerStatefulWidget {
  const BbpsStateSelectionScreen({super.key, required this.category});
  final String category;

  @override
  ConsumerState<BbpsStateSelectionScreen> createState() => _BbpsStateSelectionScreenState();
}

class _BbpsStateSelectionScreenState extends ConsumerState<BbpsStateSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Helper to generate a consistent gradient color based on state name
  List<Color> _getGradientForState(String stateName) {
    final colors = [
      [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
      [const Color(0xFF10B981), const Color(0xFF34D399)],
      [const Color(0xFFF59E0B), const Color(0xFFFBBF24)],
      [const Color(0xFFEF4444), const Color(0xFFF87171)],
      [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
      [const Color(0xFFEC4899), const Color(0xFFF472B6)],
      [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
      [const Color(0xFF06B6D4), const Color(0xFF22D3EE)],
    ];
    final hash = stateName.hashCode.abs();
    return colors[hash % colors.length];
  }

  // Get initials for state icon
  String _getInitials(String stateName) {
    final words = stateName.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return stateName.substring(0, min(2, stateName.length)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.category[0].toUpperCase()}${widget.category.substring(1)} Bill';
    final statesAsync = ref.watch(statesProvider(widget.category));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header area
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select your state to continue',
                    style: AppTextTheme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search State',
                        hintStyle: TextStyle(color: AppColors.textHint),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // State List
            Expanded(
              child: statesAsync.when(
                data: (states) {
                  final filteredStates = states.where(
                    (s) => s.toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();

                  if (states.isEmpty) {
                    return Center(
                      child: Text('No states available for ${widget.category}.'),
                    );
                  }

                  if (filteredStates.isEmpty) {
                    return Center(
                      child: Text('No states found matching "$_searchQuery".'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                    itemCount: filteredStates.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final stateName = filteredStates[index];
                      return _StateCard(
                        stateName: stateName,
                        gradient: _getGradientForState(stateName),
                        initials: _getInitials(stateName),
                        onTap: () {
                          // Pass state as query parameter to bbpsBiller
                          context.pushNamed(
                            'bbps-biller',
                            pathParameters: {'category': widget.category},
                            queryParameters: {'state': stateName},
                          );
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Failed to load states',
                          style: AppTextTheme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: AppTextTheme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(statesProvider(widget.category)),
                          child: const Text('Retry'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final String stateName;
  final List<Color> gradient;
  final String initials;
  final VoidCallback onTap;

  const _StateCard({
    required this.stateName,
    required this.gradient,
    required this.initials,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  stateName,
                  style: AppTextTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
