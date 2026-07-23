import 'package:flutter/material.dart';

class FastagPayConfirmScreen extends StatelessWidget {
  const FastagPayConfirmScreen({super.key, required this.billerId});
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
          child: const Text('Pay Amount'),
        ),
      ),
    );
  }
}
