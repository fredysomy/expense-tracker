package com.fredysomy.money_management

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.fredysomy.money_management/widget"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        )
        methodChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialAction") {
                val action = intent?.action
                result.success(if (action == "QUICK_ADD") "quick_add" else null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == "QUICK_ADD") {
            methodChannel?.invokeMethod("onAction", "quick_add")
        }
    }
}
