import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/route_names.dart';
import '../../../../../core/theme/app_colors.dart';

import '../../domain/models/gas_models.dart';

class GasFetchScreen extends StatelessWidget {
  const GasFetchScreen({super.key, required this.operator});
  final GasOperator operator;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter Details - ${operator.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Consumer Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.push(RouteNames.gasPayConfirm.replaceAll(':billerId', operator.id)),
              child: const Text('Fetch Bill'),
            ),
          ],
        ),
      ),
    );
  }
}
