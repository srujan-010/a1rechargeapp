import 'package:flutter/material.dart';

class GasPayConfirmScreen extends StatelessWidget {
  const GasPayConfirmScreen({super.key, required this.billerId});
  final String billerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Payment')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Pay logic
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful!')));
          },
          child: const Text('Pay ₹450.00'),
        ),
      ),
    );
  }
}
