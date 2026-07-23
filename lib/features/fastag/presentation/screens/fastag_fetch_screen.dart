import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/route_names.dart';
import '../../../../../core/theme/app_colors.dart';

class FastagFetchScreen extends StatelessWidget {
  const FastagFetchScreen({super.key, required this.billerId});
  final String billerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Vehicle Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Vehicle Number (e.g. MH12AB1234)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.push(RouteNames.fastagRechargeAmount.replaceAll(':billerId', billerId)),
              child: const Text('Fetch Details'),
            ),
          ],
        ),
      ),
    );
  }
}
