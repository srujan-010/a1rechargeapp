import 'dart:developer' as developer;
import 'package:flutter/services.dart';

class UpiHandler {
  static const MethodChannel _channel = MethodChannel('com.a1recharge.app/upi');

  static Future<bool> startUpiPayment({
    required double amount,
    required String upiId,
    required String name,
    required String transactionNote,
  }) async {
    try {
      final String trId = DateTime.now().millisecondsSinceEpoch.toString();
      final String encodedName = Uri.encodeComponent(name);
      final String encodedNote = Uri.encodeComponent(transactionNote);
      
      final String url = 'upi://pay?pa=$upiId&pn=$encodedName&tr=$trId&am=${amount.toStringAsFixed(2)}&cu=INR&tn=$encodedNote';
      
      // Log the complete generated UPI URI as requested
      print('UPI URL Generated: $url');
      developer.log('UPI URL Generated: $url', name: 'UpiHandler');
      
      final String? response = await _channel.invokeMethod<String>('startUpiPayment', {'url': url});
      
      if (response == null || response.isEmpty) return false;

      // Typical UPI response looks like:
      // txnId=...&responseCode=...&Status=SUCCESS&txnRef=...
      final lowerResponse = response.toLowerCase();
      if (lowerResponse.contains('status=success') || lowerResponse.contains('status=submitted')) {
        return true;
      }
      return false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}
