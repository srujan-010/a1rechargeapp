import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Msg91WebViewScreen extends StatefulWidget {
  final String phone;
  final Function(String accessToken) onSuccess;
  final Function(String error) onFailure;

  const Msg91WebViewScreen({
    super.key,
    required this.phone,
    required this.onSuccess,
    required this.onFailure,
  });

  @override
  State<Msg91WebViewScreen> createState() => _Msg91WebViewScreenState();
}

class _Msg91WebViewScreenState extends State<Msg91WebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  static const String widgetId = "366774657459333235363431";
  static const String tokenAuth = "552144TBEkejsDLJQ6a61d514P1";

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _isLoading = false;
      return;
    }

    final cleanPhone = widget.phone.replaceAll(RegExp(r'\D'), '');

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <script src="https://control.msg91.com/app/assets/otp-provider/otp-provider.js"></script>
</head>
<body style="margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f8fafc;">
    <div id="msg91-widget"></div>
    <script>
        function initializeWidget() {
            try {
                var configuration = {
                    widgetId: "$widgetId",
                    tokenAuth: "$tokenAuth",
                    identifier: "91$cleanPhone",
                    success: (data) => {
                        window.Msg91Channel.postMessage(JSON.stringify(data));
                    },
                    failure: (error) => {
                        window.Msg91Channel.postMessage(JSON.stringify({type: 'error', message: error}));
                    }
                };
                initSendOTP(configuration);
            } catch (e) {
                window.Msg91Channel.postMessage(JSON.stringify({type: 'error', message: e.toString()}));
            }
        }

        window.onload = function() {
            setTimeout(initializeWidget, 500);
        };
    </script>
</body>
</html>
''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'Msg91Channel',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('[MSG91 WebView] Raw JS message received: \${message.message}');
          try {
            final data = jsonDecode(message.message);
            if (data['type'] == 'success' || data['message'] != null) {
              final token = data['message'] ?? data['token'];
              if (token != null && token.toString().length > 20) {
                 widget.onSuccess(token.toString());
                 return;
              }
            }
            if (data['type'] == 'error') {
               widget.onFailure(data['message']?.toString() ?? 'Unknown error');
            }
          } catch (e) {
             widget.onFailure('Failed to parse WebView message: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('[MSG91 WebView] Error: \${error.description}');
          },
        ),
      )
      ..loadHtmlString(htmlContent, baseUrl: 'https://control.msg91.com');
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('MSG91 Verification')),
        body: const Center(child: Text('Web Not Supported for OTP Widget. Please test on an Android or iOS device.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MSG91 Verification', style: TextStyle(color: Colors.black87, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}