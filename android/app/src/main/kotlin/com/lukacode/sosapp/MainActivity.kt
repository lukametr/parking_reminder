package com.lukacode.sosapp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat
import com.lukacode.sosapp.location.LotStore
import com.lukacode.sosapp.location.MonitorBridge
import com.lukacode.sosapp.location.ParkingMonitorService
import com.lukacode.sosapp.location.ParkingNotifier
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val minimizeChannel = "com.lukacode.sosapp/minimize"
    private val monitorChannel = "com.lukacode.sosapp/monitor"
    private val eventsChannel = "com.lukacode.sosapp/monitor_events"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ParkingNotifier.ensureChannels(this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, minimizeChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveTaskToBack" -> {
                        moveTaskToBack(false)
                        result.success(null)
                    }
                    "getSDKVersion" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, monitorChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncLots" -> {
                        val json = call.arguments as? String ?: "[]"
                        LotStore.saveJson(this, json)
                        ParkingMonitorService.start(
                            this,
                            Intent().setAction(ParkingMonitorService.ACTION_RELOAD_LOTS),
                        )
                        result.success(null)
                    }
                    "start" -> {
                        ParkingMonitorService.start(this)
                        result.success(null)
                    }
                    "stop" -> {
                        ParkingMonitorService.stop(this)
                        result.success(null)
                    }
                    "hasAlwaysLocation" -> result.success(hasAlwaysLocation())
                    "openLocationSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                            },
                        )
                        result.success(null)
                    }
                    "setSession" -> {
                        val args = call.arguments as? Map<*, *>
                        val lot = args?.get("lot") as? String
                        val lat = (args?.get("lat") as? Number)?.toDouble() ?: 0.0
                        val lng = (args?.get("lng") as? Number)?.toDouble() ?: 0.0
                        ParkingMonitorService.start(
                            this,
                            Intent()
                                .setAction(ParkingMonitorService.ACTION_SET_SESSION)
                                .putExtra(ParkingMonitorService.EXTRA_LOT, lot)
                                .putExtra(ParkingMonitorService.EXTRA_LAT, lat)
                                .putExtra(ParkingMonitorService.EXTRA_LNG, lng),
                        )
                        result.success(null)
                    }
                    "clearSession" -> {
                        ParkingMonitorService.start(
                            this,
                            Intent().setAction(ParkingMonitorService.ACTION_CLEAR_SESSION),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventsChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    MonitorBridge.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    MonitorBridge.sink = null
                }
            })
    }

    private fun hasAlwaysLocation(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }
}
