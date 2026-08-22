// Web HTML/JS implementation for Razorpay Checkout with runtime fallback injection
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void ensureRazorpayWebBridgeRegistered() {
  try {
    final globalObj = globalContext;

    // Check if openRazorpayWebCheckout already exists
    JSAny? bridgeObj = globalObj.getProperty('openRazorpayWebCheckout'.toJS);
    if ((bridgeObj == null || !bridgeObj.isDefinedAndNotNull) && globalObj.has('window')) {
      final winObj = globalObj.getProperty('window'.toJS) as JSObject?;
      if (winObj != null && winObj.has('openRazorpayWebCheckout')) {
        bridgeObj = winObj.getProperty('openRazorpayWebCheckout'.toJS);
      }
    }

    if (bridgeObj != null && bridgeObj.isDefinedAndNotNull) {
      print('[RAZORPAY BRIDGE DART] Bridge already registered on global scope.');
      return;
    }

    print('[RAZORPAY BRIDGE DART] Bridge function missing on global scope. Injecting openRazorpayWebCheckout from Dart...');

    final injectedBridge = ((JSAny? optionsInput, JSFunction? successCb, JSFunction? errorCb, JSFunction? dismissCb) {
      print('[RAZORPAY BRIDGE DART INJECTED] openRazorpayWebCheckout called with options: $optionsInput');

      final rzConstructor = globalContext.getProperty('Razorpay'.toJS);
      if (rzConstructor == null || !rzConstructor.isDefinedAndNotNull) {
        print('[RAZORPAY BRIDGE DART INJECTED ERROR] window.Razorpay SDK is undefined!');
        errorCb?.callAsFunction(
          null,
          jsonEncode({
            'code': 'SDK_NOT_LOADED',
            'description': 'Razorpay Checkout SDK failed to load. Please check internet connection.',
            'source': 'client',
            'step': 'initialization',
            'reason': 'sdk_unavailable',
            'order_id': '',
            'payment_id': ''
          }).toJS,
        );
        return;
      }

      JSObject? optsObj;
      if (optionsInput != null && optionsInput.isA<JSObject>()) {
        optsObj = optionsInput as JSObject;
      }

      final keyVal = optsObj?.getProperty('key'.toJS)?.toString() ?? '';
      final amountVal = optsObj?.getProperty('amount'.toJS)?.toString() ?? '0';
      final currencyVal = optsObj?.getProperty('currency'.toJS)?.toString() ?? 'INR';
      final nameVal = optsObj?.getProperty('name'.toJS)?.toString() ?? 'A1 Recharge';
      final descVal = optsObj?.getProperty('description'.toJS)?.toString() ?? 'Wallet Add Money';
      final orderIdVal = optsObj?.getProperty('order_id'.toJS)?.toString() ?? '';

      JSObject? prefillObj;
      if (optsObj != null && optsObj.has('prefill')) {
        final rawPrefill = optsObj.getProperty('prefill'.toJS);
        if (rawPrefill != null && rawPrefill.isA<JSObject>()) {
          prefillObj = rawPrefill as JSObject;
        }
      }
      final contactVal = prefillObj?.getProperty('contact'.toJS)?.toString() ?? '';
      final emailVal = prefillObj?.getProperty('email'.toJS)?.toString() ?? '';

      JSObject? themeObj;
      if (optsObj != null && optsObj.has('theme')) {
        final rawTheme = optsObj.getProperty('theme'.toJS);
        if (rawTheme != null && rawTheme.isA<JSObject>()) {
          themeObj = rawTheme as JSObject;
        }
      }
      final colorVal = themeObj?.getProperty('color'.toJS)?.toString() ?? '#1565FF';

      final jsOptions = <String, dynamic>{
        'key': keyVal,
        'amount': int.tryParse(amountVal) ?? 0,
        'currency': currencyVal,
        'name': nameVal,
        'description': descVal,
        'order_id': orderIdVal,
        'prefill': {
          'contact': contactVal,
          'email': emailVal,
        },
        'theme': {
          'color': colorVal,
        },
        'handler': ((JSAny? response) {
          print('[RAZORPAY BRIDGE DART INJECTED] Payment Success Callback: $response');
          if (response != null && response.isA<JSObject>()) {
            final respObj = response as JSObject;
            final payId = respObj.getProperty('razorpay_payment_id'.toJS)?.toString() ?? '';
            final ordId = respObj.getProperty('razorpay_order_id'.toJS)?.toString() ?? orderIdVal;
            final sig = respObj.getProperty('razorpay_signature'.toJS)?.toString() ?? '';
            successCb?.callAsFunction(null, payId.toJS, ordId.toJS, sig.toJS);
          } else {
            successCb?.callAsFunction(null, ''.toJS, orderIdVal.toJS, ''.toJS);
          }
        }).toJS,
        'modal': {
          'ondismiss': (() {
            print('[RAZORPAY BRIDGE DART INJECTED] Checkout Modal Dismissed');
            dismissCb?.callAsFunction(null);
          }).toJS,
        }
      }.jsify();

      try {
        final rzpInst = (rzConstructor as JSFunction).callAsConstructor<JSObject>(jsOptions);

        if (rzpInst.has('on')) {
          final onMethod = rzpInst.getProperty('on'.toJS) as JSFunction?;
          onMethod?.callAsFunction(rzpInst, 'payment.failed'.toJS, ((JSAny? resp) {
            print('[RAZORPAY BRIDGE DART INJECTED] Payment Failed Event: $resp');
            String errCode = 'PAYMENT_FAILED';
            String desc = 'Payment failed on Razorpay';
            String src = 'gateway';
            String stp = 'checkout';
            String rsn = 'payment_failed';
            String payId = '';
            String ordId = orderIdVal;

            if (resp != null && resp.isA<JSObject>()) {
              final respObj = resp as JSObject;
              if (respObj.has('error')) {
                final errObj = respObj.getProperty('error'.toJS) as JSObject?;
                if (errObj != null) {
                  errCode = errObj.getProperty('code'.toJS)?.toString() ?? errCode;
                  desc = errObj.getProperty('description'.toJS)?.toString() ?? desc;
                  src = errObj.getProperty('source'.toJS)?.toString() ?? src;
                  stp = errObj.getProperty('step'.toJS)?.toString() ?? stp;
                  rsn = errObj.getProperty('reason'.toJS)?.toString() ?? rsn;

                  if (errObj.has('metadata')) {
                    final metaObj = errObj.getProperty('metadata'.toJS) as JSObject?;
                    if (metaObj != null) {
                      ordId = metaObj.getProperty('order_id'.toJS)?.toString() ?? ordId;
                      payId = metaObj.getProperty('payment_id'.toJS)?.toString() ?? payId;
                    }
                  }
                }
              }
            }

            print('[RAZORPAY] PAYMENT FAILURE');
            print('[RAZORPAY] code: $errCode');
            print('[RAZORPAY] description: $desc');
            print('[RAZORPAY] source: $src');
            print('[RAZORPAY] step: $stp');
            print('[RAZORPAY] reason: $rsn');
            print('[RAZORPAY] order_id: $ordId');
            print('[RAZORPAY] payment_id: $payId');

            final errJson = jsonEncode({
              'code': errCode,
              'description': desc,
              'source': src,
              'step': stp,
              'reason': rsn,
              'order_id': ordId,
              'payment_id': payId,
            });

            errorCb?.callAsFunction(null, errJson.toJS);
          }).toJS);
        }

        final openMethod = rzpInst.getProperty('open'.toJS) as JSFunction?;
        openMethod?.callAsFunction(rzpInst);
        print('[RAZORPAY BRIDGE DART INJECTED] rzp.open() executed successfully from Dart injection');
      } catch (err) {
        print('[RAZORPAY BRIDGE DART INJECTED EXCEPTION] $err');
        errorCb?.callAsFunction(
          null,
          jsonEncode({
            'code': 'EXCEPTION',
            'description': err.toString(),
            'source': 'client',
            'step': 'initialization',
            'reason': 'exception',
            'order_id': orderIdVal,
            'payment_id': '',
          }).toJS,
        );
      }
    }).toJS;

    globalObj.setProperty('openRazorpayWebCheckout'.toJS, injectedBridge);
    if (globalObj.has('window')) {
      final winObj = globalObj.getProperty('window'.toJS) as JSObject?;
      winObj?.setProperty('openRazorpayWebCheckout'.toJS, injectedBridge);
    }

    print('[RAZORPAY BRIDGE DART] Dynamically injected openRazorpayWebCheckout onto globalThis & window!');
  } catch (e) {
    print('[RAZORPAY BRIDGE DART INJECTION ERROR] $e');
  }
}

void openRazorpayWebCheckoutImpl({
  required String key,
  required int amount,
  required String orderId,
  required String contact,
  required String email,
  required Function(String paymentId, String orderId, String signature) onSuccess,
  required Function(String error) onError,
  required Function() onDismiss,
}) {
  try {
    print('[RAZORPAY BRIDGE] Starting initialization in Dart...');

    ensureRazorpayWebBridgeRegistered();

    final globalObj = globalContext;

    final sdkObj = globalObj.getProperty('Razorpay'.toJS);
    final isSdkLoaded = sdkObj != null && sdkObj.isDefinedAndNotNull;
    print('[RAZORPAY BRIDGE] Razorpay SDK: ${isSdkLoaded ? "function" : "undefined"}');

    JSAny? bridgeObj = globalObj.getProperty('openRazorpayWebCheckout'.toJS);
    if ((bridgeObj == null || !bridgeObj.isDefinedAndNotNull) && globalObj.has('window')) {
      final winObj = globalObj.getProperty('window'.toJS) as JSObject?;
      if (winObj != null && winObj.has('openRazorpayWebCheckout')) {
        bridgeObj = winObj.getProperty('openRazorpayWebCheckout'.toJS);
      }
    }

    final isBridgeRegistered = bridgeObj != null && bridgeObj.isDefinedAndNotNull;
    print('[RAZORPAY BRIDGE] Bridge type: ${isBridgeRegistered ? "function" : "undefined"}');
    print('[RAZORPAY BRIDGE] Bridge registered: $isBridgeRegistered');

    if (!isBridgeRegistered) {
      print('[RAZORPAY BRIDGE ERROR] openRazorpayWebCheckout is not registered on window/globalThis.');
      onError(jsonEncode({
        'code': 'BRIDGE_NOT_REGISTERED',
        'description': 'Payment gateway bridge is not registered.',
        'source': 'client',
        'step': 'initialization',
        'reason': 'bridge_unavailable',
        'order_id': orderId,
        'payment_id': '',
      }));
      return;
    }

    print('[RAZORPAY WEB DART] Invoking openRazorpayWebCheckout JS function for order: $orderId');

    final optionsMap = {
      'key': key,
      'amount': amount,
      'currency': 'INR',
      'name': 'A1 Recharge',
      'description': 'Wallet Add Money',
      'order_id': orderId,
      'prefill': {
        'contact': contact,
        'email': email,
      },
      'theme': {
        'color': '#1565FF',
      }
    };

    final jsOptions = optionsMap.jsify()!;

    final jsOnSuccess = ((JSAny? paymentId, JSAny? orderIdRes, JSAny? signature) {
      print('[RAZORPAY WEB DART] Success callback received from JS');
      onSuccess(
        paymentId?.toString() ?? '',
        orderIdRes?.toString() ?? orderId,
        signature?.toString() ?? '',
      );
    }).toJS;

    final jsOnError = ((JSAny? err) {
      print('[RAZORPAY WEB DART] Error callback received from JS: $err');
      onError(err?.toString() ?? 'Payment failed on Razorpay');
    }).toJS;

    final jsOnDismiss = (() {
      print('[RAZORPAY WEB DART] Dismiss callback received from JS');
      onDismiss();
    }).toJS;

    final jsFunc = bridgeObj as JSFunction;
    jsFunc.callAsFunction(globalObj, jsOptions, jsOnSuccess, jsOnError, jsOnDismiss);

    print('[RAZORPAY WEB DART] JS Function invoked successfully');
  } catch (e, st) {
    print('[RAZORPAY WEB DART EXCEPTION] $e');
    print('[RAZORPAY WEB DART STACKTRACE] $st');
    onError(jsonEncode({
      'code': 'EXCEPTION',
      'description': e.toString(),
      'source': 'client',
      'step': 'invocation',
      'reason': 'exception',
      'order_id': orderId,
      'payment_id': '',
    }));
  }
}
