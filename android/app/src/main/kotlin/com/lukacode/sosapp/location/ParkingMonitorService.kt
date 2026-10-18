package com.lukacode.sosapp.location

import android.Manifest
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.ServiceCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.DetectedActivity
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.Granularity
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import org.json.JSONObject

/**
 * Play Services Fused Location + Activity Recognition + nearby-lot geofences.
 * High-accuracy GPS only while the user looks stationary (parking). Moving /
 * in-vehicle uses balanced power and large displacement.
 */
class ParkingMonitorService : Service() {
    private val fused by lazy { LocationServices.getFusedLocationProviderClient(this) }
    private val geofences: GeofencingClient by lazy { LocationServices.getGeofencingClient(this) }
    private val activityClient by lazy { ActivityRecognition.getClient(this) }

    private var index: LotIndex = LotIndex(emptyList())
    private var lastActivity = DetectedActivity.UNKNOWN
    private var lastNotifyMs = 0L
    private var lastGeofenceUpdateMs = 0L

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val loc = result.lastLocation ?: return
            onFix(
                loc.latitude,
                loc.longitude,
                loc.accuracy.toDouble(),
                loc.speed.toDouble(),
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        ParkingNotifier.ensureChannels(this)
        index = LotIndex(LotStore.load(this))
        startAsForeground()
        startActivityUpdates()
        applyLocationMode(DetectedActivity.UNKNOWN)
        prefs().edit().putBoolean(PREF_WANTED, true).apply()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                prefs().edit().putBoolean(PREF_WANTED, false).apply()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_ACTIVITY -> {
                lastActivity = intent.getIntExtra(EXTRA_ACTIVITY, lastActivity)
                applyLocationMode(lastActivity)
            }
            ACTION_GEOFENCE_ENTER -> {
                applyLocationMode(DetectedActivity.STILL)
            }
            ACTION_RELOAD_LOTS -> {
                index = LotIndex(LotStore.load(this))
            }
            ACTION_SET_SESSION -> {
                prefs().edit()
                    .putString(PREF_ACTIVE_LOT, intent.getStringExtra(EXTRA_LOT))
                    .putString(PREF_PARK_LAT, intent.getDoubleExtra(EXTRA_LAT, 0.0).toString())
                    .putString(PREF_PARK_LNG, intent.getDoubleExtra(EXTRA_LNG, 0.0).toString())
                    .putBoolean(PREF_LEFT_NOTIFIED, false)
                    .apply()
            }
            ACTION_CLEAR_SESSION -> {
                prefs().edit()
                    .remove(PREF_ACTIVE_LOT)
                    .remove(PREF_PARK_LAT)
                    .remove(PREF_PARK_LNG)
                    .putBoolean(PREF_LEFT_NOTIFIED, false)
                    .apply()
            }
        }
        startAsForeground()
        return START_STICKY
    }

    override fun onDestroy() {
        fused.removeLocationUpdates(locationCallback)
        try {
            geofences.removeGeofences(geofencePendingIntent())
        } catch (_: Exception) {
        }
        try {
            activityClient.removeActivityUpdates(activityPendingIntent())
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun startAsForeground() {
        val n = ParkingNotifier.monitorNotification(this, "მონიტორინგი ჩართულია")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceCompat.startForeground(
                this,
                ParkingNotifier.MONITOR_ID,
                n,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(ParkingNotifier.MONITOR_ID, n)
        }
    }

    private fun applyLocationMode(activity: Int) {
        if (!hasFine()) return
        val request = when (activity) {
            DetectedActivity.STILL -> LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                8_000L,
            ).setMinUpdateDistanceMeters(3f)
                .setMinUpdateIntervalMillis(5_000L)
                .setGranularity(Granularity.GRANULARITY_FINE)
                .build()
            DetectedActivity.IN_VEHICLE, DetectedActivity.ON_BICYCLE ->
                LocationRequest.Builder(
                    Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                    60_000L,
                ).setMinUpdateDistanceMeters(80f)
                    .setMinUpdateIntervalMillis(30_000L)
                    .build()
            else -> LocationRequest.Builder(
                Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                25_000L,
            ).setMinUpdateDistanceMeters(25f)
                .setMinUpdateIntervalMillis(15_000L)
                .build()
        }
        fused.removeLocationUpdates(locationCallback)
        fused.requestLocationUpdates(request, locationCallback, mainLooper)
    }

    private fun onFix(lat: Double, lng: Double, accuracy: Double, speed: Double) {
        val still = lastActivity == DetectedActivity.STILL || speed < 1.2
        val radius = if (still) 15.0 else 25.0
        val nearby = index.nearby(lat, lng, radius)
        val lots = nearby.map { it.lotNumber }
        MonitorBridge.emit(
            JSONObject()
                .put("type", if (lots.isNotEmpty()) "lots" else "fix")
                .put("lots", org.json.JSONArray(lots))
                .put("lat", lat)
                .put("lng", lng)
                .put("accuracy", accuracy)
                .put("speed", speed)
                .put("activity", activityName(lastActivity)),
        )
        maybeRefreshGeofences(lat, lng)
        val activeLot = prefs().getString(PREF_ACTIVE_LOT, null)
        if (activeLot != null) {
            val parkLat = prefs().getString(PREF_PARK_LAT, null)?.toDoubleOrNull()
            val parkLng = prefs().getString(PREF_PARK_LNG, null)?.toDoubleOrNull()
            if (parkLat != null && parkLng != null) {
                val dist = LotIndex.haversineMeters(lat, lng, parkLat, parkLng)
                if (dist > EXIT_BUFFER_METERS && !prefs().getBoolean(PREF_LEFT_NOTIFIED, false)) {
                    prefs().edit().putBoolean(PREF_LEFT_NOTIFIED, true).apply()
                    ParkingNotifier.showLeaveAlert(
                        this,
                        "დატოვეთ პარკირების ლოტი",
                        "$activeLot — გამორთეთ პარკირება ოფიციალურ აპში (MSDA / ge.msda.parking).",
                    )
                    prefs().edit()
                        .remove(PREF_ACTIVE_LOT)
                        .remove(PREF_PARK_LAT)
                        .remove(PREF_PARK_LNG)
                        .apply()
                }
            }
            return
        }
        if (lots.isNotEmpty() && still) {
            val now = System.currentTimeMillis()
            if (now - lastNotifyMs > 60_000) {
                lastNotifyMs = now
                ParkingNotifier.showAlert(
                    this,
                    "ფასიანი პარკირების ლოტი",
                    "ლოტი ${lots.joinToString(" ან ")} — გსურთ ჩართოთ პარკირება ოფიციალურ აპში?",
                    lots.joinToString(" ან "),
                )
            }
        }
    }

    private fun maybeRefreshGeofences(lat: Double, lng: Double) {
        val now = System.currentTimeMillis()
        if (now - lastGeofenceUpdateMs < 120_000) return
        lastGeofenceUpdateMs = now
        if (!hasFine()) return
        val nearest = index.nearest(lat, lng, limit = 90, maxMeters = 600.0)
        if (nearest.isEmpty()) return
        val fences = nearest.map { lot ->
            Geofence.Builder()
                .setRequestId(lot.id.take(64))
                .setCircularRegion(lot.lat, lot.lng, 25f)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                .build()
        }
        val request = GeofencingRequest.Builder()
            .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
            .addGeofences(fences)
            .build()
        try {
            geofences.removeGeofences(geofencePendingIntent()).addOnCompleteListener {
                try {
                    geofences.addGeofences(request, geofencePendingIntent())
                } catch (_: SecurityException) {
                }
            }
        } catch (_: SecurityException) {
        }
    }

    private fun startActivityUpdates() {
        if (Build.VERSION.SDK_INT >= 29 &&
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        try {
            activityClient.requestActivityUpdates(20_000L, activityPendingIntent())
        } catch (_: SecurityException) {
        }
    }

    private fun hasFine(): Boolean {
        return ActivityCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun activityPendingIntent(): PendingIntent {
        val intent = Intent(this, ActivityUpdatesReceiver::class.java)
        return PendingIntent.getBroadcast(this, 21, intent, immutable())
    }

    private fun geofencePendingIntent(): PendingIntent {
        val intent = Intent(this, GeofenceReceiver::class.java)
        return PendingIntent.getBroadcast(this, 22, intent, immutable())
    }

    private fun prefs() = getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    companion object {
        const val ACTION_STOP = "com.lukacode.sosapp.STOP"
        const val ACTION_ACTIVITY = "com.lukacode.sosapp.ACTIVITY"
        const val ACTION_GEOFENCE_ENTER = "com.lukacode.sosapp.GEOFENCE_ENTER"
        const val ACTION_RELOAD_LOTS = "com.lukacode.sosapp.RELOAD_LOTS"
        const val ACTION_SET_SESSION = "com.lukacode.sosapp.SET_SESSION"
        const val ACTION_CLEAR_SESSION = "com.lukacode.sosapp.CLEAR_SESSION"
        const val EXTRA_ACTIVITY = "activity"
        const val EXTRA_LOT = "lot"
        const val EXTRA_LAT = "lat"
        const val EXTRA_LNG = "lng"
        const val PREFS = "parking_monitor"
        const val PREF_WANTED = "monitor_wanted"
        const val PREF_ACTIVE_LOT = "active_lot"
        const val PREF_PARK_LAT = "park_lat"
        const val PREF_PARK_LNG = "park_lng"
        const val PREF_LEFT_NOTIFIED = "left_notified"
        const val EXIT_BUFFER_METERS = 80.0

        fun start(context: Context, extras: Intent? = null) {
            val i = (extras ?: Intent()).setClass(context, ParkingMonitorService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            val i = Intent(context, ParkingMonitorService::class.java).setAction(ACTION_STOP)
            context.startService(i)
        }

        private fun immutable(): Int {
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            return flags
        }

        fun activityName(type: Int): String = when (type) {
            DetectedActivity.STILL -> "still"
            DetectedActivity.IN_VEHICLE -> "vehicle"
            DetectedActivity.ON_BICYCLE -> "bicycle"
            DetectedActivity.ON_FOOT, DetectedActivity.WALKING, DetectedActivity.RUNNING -> "foot"
            else -> "unknown"
        }
    }
}
