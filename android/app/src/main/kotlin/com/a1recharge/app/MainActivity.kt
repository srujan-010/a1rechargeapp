package com.a1recharge.app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.a1recharge.app/upi"
    private var upiResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startUpiPayment") {
                val upiUrl = call.argument<String>("url")
                if (upiUrl != null) {
                    this.upiResult = result
                    val intent = Intent(Intent.ACTION_VIEW)
                    intent.data = Uri.parse(upiUrl)
                    val chooser = Intent.createChooser(intent, "Pay with")
                    startActivityForResult(chooser, 1001)
                } else {
                    result.error("INVALID_URL", "UPI URL is null", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            if (data != null) {
                // The response from standard UPI intents usually comes as a string extra "response"
                val response = data.getStringExtra("response") ?: ""
                upiResult?.success(response)
            } else {
                // If user backs out of the intent
                upiResult?.success("Status=Failed")
            }
            upiResult = null
        }
    }
}
