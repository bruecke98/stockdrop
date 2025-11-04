package com.example.stockdrop

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIDGET_CHANNEL = "com.example.stockdrop/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setApiKey" -> {
                        val apiKey = call.argument<String>("apiKey")
                        if (apiKey != null) {
                            saveApiKey(apiKey)
                            result.success(true)
                        } else {
                            result.error("INVALID_ARGUMENT", "API key is null", null)
                        }
                    }
                    "refreshWidget" -> {
                        refreshWidget()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun saveApiKey(apiKey: String) {
        val prefs = getSharedPreferences("stockdrop_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString("fmp_api_key", apiKey).apply()
    }

    private fun refreshWidget() {
        // Trigger widget refresh
        val intent = android.content.Intent(this, StockWidgetProvider::class.java)
        intent.action = android.appwidget.AppWidgetManager.ACTION_APPWIDGET_UPDATE
        sendBroadcast(intent)
    }
}
