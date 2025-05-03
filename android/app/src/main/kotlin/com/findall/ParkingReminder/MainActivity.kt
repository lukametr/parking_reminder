package com.findall.ParkingReminder

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.findall.ParkingReminder/minimize"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveTaskToBack" -> {
                        moveTaskToBack(false)
                        result.success(null)
                    }
                    "getSDKVersion" -> {
                        result.success(Build.VERSION.SDK_INT)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}