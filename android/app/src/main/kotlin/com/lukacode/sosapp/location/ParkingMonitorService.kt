package com.lukacode.sosapp.location

import android.Manifest
import android.app.ActivityManager
import android.app.ForegroundServiceStartNotAllowedException
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
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
import java.util.concurrent.Executors

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
    private var lastGeofenceUpdateMs = 0L
    private var dwellLotsKey: String? = null
    private var dwellSinceMs = 0L
    private var lastPromptedKey: String? = null
    private var lastLat = 0.0
    private var lastLng = 0.0
    private var lastSpeed = 0.0
    private var lastLots: List<String> = emptyList()
    private val promptPolicy by lazy { LotPromptPolicy(prefs()) }
    private val handler = Handler(Looper.getMainLooper())
    private val dwellRunnable = Runnable { fireStayPromptIfReady("timer") }
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private var promoted = false
    private var initialized = false

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            val loc = result.lastLocation ?: return
            val speed = if (loc.hasSpeed() && loc.speed >= 0f) loc.speed.toDouble() else 0.0
            onFix(
                loc.latitude,
                loc.longitude,
                loc.accuracy.toDouble(),
                speed,
            )
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        // Promote within the FGS start window BEFORE any I/O or Play Services work.
        ParkingNotifier.ensureChannels(this)
        if (!startAsForeground()) {
            isRunning = false
            ParkingNotifier.showResumeMonitoring(applicationContext)
            stopSelf()
            return
        }
        promoted = true
        prefs().edit().putBoolean(PREF_WANTED, true).apply()
        ensureInitialized()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                prefs().edit().putBoolean(PREF_WANTED, false).apply()
                teardownAndStopForeground()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_ACTIVITY -> {
                lastActivity = intent.getIntExtra(EXTRA_ACTIVITY, lastActivity)
                Log.i(TAG, "activity=${activityName(lastActivity)}")
                // Do not restart GPS here — remove+request dropped fixes in the field.
            }
            ACTION_GEOFENCE_ENTER -> {
                lastActivity = DetectedActivity.STILL
            }
            ACTION_RELOAD_LOTS -> {
                ioExecutor.execute {
                    val lots = LotStore.load(this)
                    handler.post {
                        index = LotIndex(lots)
                        Log.i(TAG, "reload lots n=${index.size}")
                    }
                }
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
            ACTION_DECLINE -> {
                val lots = intent.getStringExtra(EXTRA_LOTS)
                    ?.split(" ან ", ",", "\n")
                    ?.map { it.trim() }
                    ?.filter { it.isNotEmpty() }
                    ?: lastLots
                val lat = intent.getDoubleExtra(EXTRA_LAT, lastLat)
                val lng = intent.getDoubleExtra(EXTRA_LNG, lastLng)
                promptPolicy.decline(lots, lat, lng)
                lastPromptedKey = null
                prefs().edit().remove(LotPromptPolicy.PREF_PENDING_LOTS).apply()
            }
        }
        if (!promoted) {
            ParkingNotifier.ensureChannels(this)
            if (!startAsForeground()) {
                isRunning = false
                ParkingNotifier.showResumeMonitoring(applicationContext)
                stopSelf()
                return START_NOT_STICKY
            }
            promoted = true
            prefs().edit().putBoolean(PREF_WANTED, true).apply()
            ensureInitialized()
        } else if (!startAsForeground()) {
            // Already promoted once; a later denial should not crash — keep running if possible.
            Log.w(TAG, "startForeground refresh denied; continuing with existing FGS state")
        }
        return START_STICKY
    }

    override fun onDestroy() {
        teardownAndStopForeground()
        isRunning = false
        promoted = false
        initialized = false
        super.onDestroy()
    }

    private fun ensureInitialized() {
        if (initialized) return
        initialized = true
        ioExecutor.execute {
            val lots = try {
                LotStore.load(this)
            } catch (e: Exception) {
                Log.e(TAG, "LotStore.load failed", e)
                emptyList()
            }
            handler.post {
                index = LotIndex(lots)
                Log.i(TAG, "initialized lots=${index.size} fine=${hasFine()}")
                startActivityUpdates()
                applyLocationMode(DetectedActivity.UNKNOWN)
            }
        }
    }

    private fun teardownAndStopForeground() {
        handler.removeCallbacks(dwellRunnable)
        try {
            fused.removeLocationUpdates(locationCallback)
        } catch (_: Exception) {
        }
        try {
            geofences.removeGeofences(geofencePendingIntent())
        } catch (_: Exception) {
        }
        try {
            activityClient.removeActivityUpdates(activityPendingIntent())
        } catch (_: Exception) {
        }
        try {
            ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
        }
        try {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .cancel(ParkingNotifier.MONITOR_ID)
        } catch (_: Exception) {
        }
    }

    /**
     * @return true if the service is now in the foreground (or already was).
     * Never throws [ForegroundServiceStartNotAllowedException] out of process.
     */
    private fun startAsForeground(): Boolean {
        val n = ParkingNotifier.monitorNotification(
            this,
            "აპი ამოწმებს თბილისის ფასიან პარკირების ლოტებს",
        )
        return try {
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
            true
        } catch (e: Exception) {
            if (isStartNotAllowed(e)) {
                Log.e(TAG, "startForeground not allowed (background FGS restriction)", e)
                recordNonFatal(e)
                false
            } else {
                Log.e(TAG, "startForeground failed", e)
                recordNonFatal(e)
                false
            }
        }
    }

    private fun applyLocationMode(activity: Int) {
        if (!hasFine()) {
            Log.w(TAG, "no ACCESS_FINE_LOCATION — cannot request GPS")
            return
        }
        // Always high-accuracy while FGS runs. Coarse IN_VEHICLE intervals
        // (60s / 80m) missed real parking stops in field tests.
        val interval = if (activity == DetectedActivity.STILL) 3_000L else 4_000L
        val request = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY,
            interval,
        ).setMinUpdateIntervalMillis(2_000L)
            .setMinUpdateDistanceMeters(0f)
            .setWaitForAccurateLocation(false)
            .setGranularity(Granularity.GRANULARITY_FINE)
            .build()
        fused.removeLocationUpdates(locationCallback)
        fused.requestLocationUpdates(request, locationCallback, mainLooper)
        Log.i(TAG, "gps mode activity=${activityName(activity)} intervalMs=$interval")
    }

    private fun onFix(lat: Double, lng: Double, accuracy: Double, speed: Double) {
        lastLat = lat
        lastLng = lng
        lastSpeed = speed
        val still = isStationary(speed)
        // Tight GPS match: single nearest lot only, and only if within ~8 m.
        val match = index.nearby(lat, lng, MATCH_RADIUS_M).firstOrNull()
        val lots = if (match != null) listOf(match.lotNumber) else emptyList()
        lastLots = lots
        promptPolicy.noteFix(lots, lat, lng)
        val nearestHint = index.nearest(lat, lng, limit = 1, maxMeters = 80.0).firstOrNull()
        val nearestM = nearestHint?.let {
            LotIndex.haversineMeters(lat, lng, it.lat, it.lng)
        }
        Log.i(
            TAG,
            "fix still=$still speed=${"%.2f".format(speed)} acc=${"%.0f".format(accuracy)} " +
                "match=${lots} nearest=${nearestHint?.lotNumber}@${nearestM?.let { "%.1f".format(it) }}m " +
                "r=${MATCH_RADIUS_M} index=${index.size} act=${activityName(lastActivity)}",
        )
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
            dwellLotsKey = null
            lastPromptedKey = null
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
        maybePromptStay(lots, lat, lng, still)
    }

    /**
     * Speed-only stop gate. AR often stays IN_VEHICLE after the car is parked,
     * which previously blocked every stay prompt.
     */
    private fun isStationary(speed: Double): Boolean = speed < STOP_SPEED_MPS

    private fun maybePromptStay(lots: List<String>, lat: Double, lng: Double, still: Boolean) {
        if (!still || lots.isEmpty()) {
            handler.removeCallbacks(dwellRunnable)
            dwellLotsKey = null
            dwellSinceMs = 0L
            if (!still) lastPromptedKey = null
            return
        }
        val key = lots.sorted().joinToString("|")
        val now = System.currentTimeMillis()
        if (key != dwellLotsKey) {
            dwellLotsKey = key
            dwellSinceMs = now
            handler.removeCallbacks(dwellRunnable)
            handler.postDelayed(dwellRunnable, LotPromptPolicy.DWELL_MS)
            Log.i(TAG, "dwell start ${LotPromptPolicy.DWELL_MS}ms lots=$lots")
        }
        fireStayPromptIfReady("fix")
    }

    private fun fireStayPromptIfReady(reason: String) {
        val lots = lastLots
        if (lots.isEmpty() || lastSpeed >= STOP_SPEED_MPS) return
        val key = dwellLotsKey ?: lots.sorted().joinToString("|")
        if (key == lastPromptedKey) return
        val elapsed = System.currentTimeMillis() - dwellSinceMs
        if (dwellSinceMs == 0L || elapsed < LotPromptPolicy.DWELL_MS) {
            Log.i(TAG, "dwell wait ${elapsed}ms reason=$reason")
            return
        }
        if (!promptPolicy.canPrompt(lots, lastLat, lastLng)) {
            Log.i(TAG, "prompt suppressed cooldown/same-lot lots=$lots")
            return
        }
        lastPromptedKey = key
        val joined = lots.joinToString(" ან ")
        prefs().edit().putString(LotPromptPolicy.PREF_PENDING_LOTS, joined).apply()
        Log.i(TAG, "PROMPT $reason lots=$joined")
        MonitorBridge.emit(
            JSONObject()
                .put("type", "prompt")
                .put("lots", org.json.JSONArray(lots))
                .put("lat", lastLat)
                .put("lng", lastLng)
                .put("accuracy", 0)
                .put("speed", lastSpeed)
                .put("activity", activityName(lastActivity)),
        )
        ParkingNotifier.showStayPrompt(
            this,
            "ფასიანი პარკირების ლოტი",
            "ლოტი $joined — გსურთ დარჩეთ და ოფიციალურ აპში ჩართოთ პარკირება?",
            joined,
        )
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
        const val ACTION_DECLINE = "com.lukacode.sosapp.DECLINE"
        const val EXTRA_ACTIVITY = "activity"
        const val EXTRA_LOT = "lot"
        const val EXTRA_LOTS = "lots"
        const val EXTRA_LAT = "lat"
        const val EXTRA_LNG = "lng"
        @Volatile
        var appInForeground = false
        @Volatile
        var isRunning = false
        private const val TAG = "ParkingMon"
        const val STOP_SPEED_MPS = 2.8
        /** Stay-prompt match: nearest lot only, and only inside this radius. */
        const val MATCH_RADIUS_M = 8.0
        const val PREFS = "parking_monitor"
        const val PREF_WANTED = "monitor_wanted"
        const val PREF_ACTIVE_LOT = "active_lot"
        const val PREF_PARK_LAT = "park_lat"
        const val PREF_PARK_LNG = "park_lng"
        const val PREF_LEFT_NOTIFIED = "left_notified"
        const val EXIT_BUFFER_METERS = 80.0

        /**
         * Start (or command) the parking FGS only when Android allows it.
         * Background / boot / dead-process wakes fall back to a high-priority
         * "tap to resume" notification instead of crashing.
         */
        fun start(context: Context, extras: Intent? = null) {
            val app = context.applicationContext
            app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(PREF_WANTED, true)
                .apply()
            val i = (extras ?: Intent()).setClass(app, ParkingMonitorService::class.java)
            if (!canStartForegroundService(app)) {
                Log.w(TAG, "FGS start skipped — app not eligible; showing resume notification")
                ParkingNotifier.showResumeMonitoring(app)
                return
            }
            try {
                ContextCompat.startForegroundService(app, i)
            } catch (e: Exception) {
                if (isStartNotAllowed(e)) {
                    Log.e(TAG, "startForegroundService not allowed", e)
                    recordNonFatal(e)
                    ParkingNotifier.showResumeMonitoring(app)
                } else {
                    Log.e(TAG, "startForegroundService failed", e)
                    recordNonFatal(e)
                    ParkingNotifier.showResumeMonitoring(app)
                }
            }
        }

        fun stop(context: Context) {
            val app = context.applicationContext
            app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(PREF_WANTED, false)
                .apply()
            val i = Intent(app, ParkingMonitorService::class.java).setAction(ACTION_STOP)
            if (isRunning && canStartForegroundService(app)) {
                try {
                    ContextCompat.startForegroundService(app, i)
                } catch (e: Exception) {
                    Log.w(TAG, "stop via FGS failed; falling back to stopService", e)
                }
            }
            try {
                app.stopService(Intent(app, ParkingMonitorService::class.java))
            } catch (_: Exception) {
            }
            try {
                val nm = app.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(ParkingNotifier.MONITOR_ID)
                nm.cancel(ParkingNotifier.RESUME_ID)
            } catch (_: Exception) {
            }
        }

        fun shutdown(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putBoolean(PREF_WANTED, false)
                .remove(PREF_ACTIVE_LOT)
                .remove(PREF_PARK_LAT)
                .remove(PREF_PARK_LNG)
                .putBoolean(PREF_LEFT_NOTIFIED, false)
                .apply()
            stop(context)
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(ParkingNotifier.MONITOR_ID)
                nm.cancel(ParkingNotifier.ALERT_ID)
                nm.cancel(ParkingNotifier.REMINDER_ID)
                nm.cancel(ParkingNotifier.RESUME_ID)
            } catch (_: Exception) {
            }
        }

        fun decline(context: Context, lots: String, lat: Double, lng: Double) {
            start(
                context,
                Intent()
                    .setAction(ACTION_DECLINE)
                    .putExtra(EXTRA_LOTS, lots)
                    .putExtra(EXTRA_LAT, lat)
                    .putExtra(EXTRA_LNG, lng),
            )
        }

        fun consumePendingLots(context: Context): String? {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val lots = p.getString(LotPromptPolicy.PREF_PENDING_LOTS, null)
            if (!lots.isNullOrBlank()) {
                p.edit().remove(LotPromptPolicy.PREF_PENDING_LOTS).apply()
            }
            return lots
        }

        /** True when Android is likely to allow startForegroundService / startForeground. */
        fun canStartForegroundService(context: Context): Boolean {
            if (appInForeground) return true
            // Existing FGS in this process is an Android exemption.
            if (isRunning) return true
            return try {
                val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val proc = am.runningAppProcesses?.firstOrNull { it.pid == Process.myPid() }
                val importance = proc?.importance ?: ActivityManager.RunningAppProcessInfo.IMPORTANCE_GONE
                importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
            } catch (_: Exception) {
                false
            }
        }

        fun isStartNotAllowed(e: Throwable): Boolean {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                e is ForegroundServiceStartNotAllowedException
            ) {
                return true
            }
            var cur: Throwable? = e
            while (cur != null) {
                if (cur.javaClass.name.contains("ForegroundServiceStartNotAllowed")) return true
                cur = cur.cause
            }
            return false
        }

        fun recordNonFatal(t: Throwable) {
            try {
                val clazz = Class.forName("com.google.firebase.crashlytics.FirebaseCrashlytics")
                val instance = clazz.getMethod("getInstance").invoke(null)
                clazz.getMethod("recordException", Throwable::class.java).invoke(instance, t)
            } catch (_: Exception) {
            }
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
