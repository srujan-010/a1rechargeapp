import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/route_names.dart';
import '../../../../../core/theme/app_colors.dart';

class FastagOperatorSelectionScreen extends StatelessWidget {
  const FastagOperatorSelectionScreen({super.key});

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
