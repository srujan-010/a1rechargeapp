import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/route_names.dart';
import '../../../../../core/services/recharge_session_manager.dart';
import '../../../../../core/theme/app_colors.dart';

class FastagOperatorSelectionScreen extends ConsumerStatefulWidget {
  const FastagOperatorSelectionScreen({super.key});

  @override
  ConsumerState<FastagOperatorSelectionScreen> createState() => _FastagOperatorSelectionScreenState();
}

class _FastagOperatorSelectionScreenState extends ConsumerState<FastagOperatorSelectionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(rechargeSessionProvider);
      if (session.sessionId == null || session.serviceType != 'FASTAG') {
        ref.read(rechargeSessionProvider.notifier).startNewSession('FASTAG');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select FASTag Issuer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Mock Bank FASTag'),
            subtitle: const Text('National'),
            leading: const Icon(Icons.directions_car, color: AppColors.primaryBlue),
            onTap: () => context.push(RouteNames.fastagFetch.replaceAll(':billerId', '1')),
          ),
        ],
      ),
    );
  }
}
