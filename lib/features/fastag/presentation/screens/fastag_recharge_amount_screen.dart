import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/route_names.dart';
import '../../../../../core/theme/app_colors.dart';

class FastagRechargeAmountScreen extends StatelessWidget {
  const FastagRechargeAmountScreen({super.key, required this.billerId});
  final String billerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Recharge Amount')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Vehicle: MH12AB1234', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.push(RouteNames.fastagPayConfirm.replaceAll(':billerId', billerId)),
              child: const Text('Proceed to Pay'),
            ),
          ],
        ),
      ),
    );
  }
}
