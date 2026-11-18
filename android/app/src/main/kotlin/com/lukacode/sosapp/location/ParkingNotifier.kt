package com.lukacode.sosapp.location

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.lukacode.sosapp.MainActivity
import com.lukacode.sosapp.R

/**
 * Native NotificationManager path for stay/leave alerts.
 * Must work with screen off / locked — Flutter overlay alone is not enough.
 */
object ParkingNotifier {
    /** Silent ongoing FGS channel (new id: old LOW channel never upgrades). */
    const val CHANNEL_MONITOR = "parking_monitor_ongoing"

    /**
     * High-importance wake channel with custom beep.
     * New id (`…_wake_v21`) so OEM installs pick up sound + IMPORTANCE_HIGH
     * (Android never upgrades an existing channel's importance/sound).
     */
    const val CHANNEL_ALERTS = "parking_alerts_wake_v21"
    const val MONITOR_ID = 888
    const val ALERT_ID = 890
    const val REMINDER_ID = 891
    const val RESUME_ID = 892
    const val EXTRA_RESUME_MONITOR = "resume_monitor"
    private const val TAG = "ParkingNotifier"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_MONITOR,
                "პარკინგის მონიტორინგი",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "მუდმივი შეტყობინება, სანამ ლოკაცია იზომება"
                setShowBadge(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
        val soundUri = alertSoundUri(context)
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ALERTS,
                "პარკინგის განგაში",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description =
                    "Stay / leave — heads-up, lock screen, full-screen intent + short beep"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 220, 120, 220)
                enableLights(true)
                setShowBadge(true)
                setBypassDnd(false) // respect DND / notification volume
                setSound(soundUri, attrs)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
        )
    }

    fun monitorNotification(context: Context, text: String): Notification {
        ensureChannels(context)
        val launch = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            pendingFlags(),
        )
        return NotificationCompat.Builder(context, CHANNEL_MONITOR)
            .setContentTitle("პარკინგის მონიტორინგი ჩართულია")
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(launch)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    fun showStayPrompt(context: Context, title: String, body: String, extraLots: String? = null) {
        notifyFullScreen(
            context,
            ALERT_ID,
            title,
            body,
            Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                )
                putExtra("lots", extraLots)
                putExtra("show_prompt", true)
            },
            requestCode = 11,
            useFullScreen = shouldUseFullScreenIntent(context),
        )
    }

    fun showAlert(context: Context, title: String, body: String, extraLots: String? = null) {
        showStayPrompt(context, title, body, extraLots)
    }

    fun showLeaveAlert(context: Context, title: String, body: String) {
        notifyFullScreen(
            context,
            REMINDER_ID,
            title,
            body,
            Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                )
                putExtra("leave_lot", true)
            },
            requestCode = 12,
            useFullScreen = shouldUseFullScreenIntent(context),
        )
    }

    /**
     * Safe path when Android blocks background FGS starts (boot, Honor OEM, AR wake
     * after process death). User tap brings the app to foreground so FGS can start.
     */
    fun showResumeMonitoring(context: Context) {
        ensureChannels(context)
        if (!notificationsAllowed(context)) {
            Log.w(TAG, "resume notify skipped — POST_NOTIFICATIONS not granted")
            return
        }
        val launch = PendingIntent.getActivity(
            context,
            13,
            Intent(context, MainActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NEW_TASK,
                )
                putExtra(EXTRA_RESUME_MONITOR, true)
            },
            pendingFlags(),
        )
        val body = "შეეხეთ მონიტორინგის გასაგრძელებლად (ფონური შეზღუდვა)"
        val n = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setContentTitle("პარკინგის მონიტორინგი შეჩერდა")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_notification)
            .setAutoCancel(true)
            .setContentIntent(launch)
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setSound(alertSoundUri(context))
            .setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
            .build()
        notifySafe(context, RESUME_ID, n)
    }

    /**
     * Full-screen / heads-up when the user cannot see the Flutter overlay:
     * screen off, keyguard locked, or app not in foreground.
     */
    fun shouldUseFullScreenIntent(context: Context): Boolean {
        if (!ParkingMonitorService.appInForeground) return true
        if (!isScreenInteractive(context)) return true
        if (isKeyguardLocked(context)) return true
        return false
    }

    fun isScreenInteractive(context: Context): Boolean {
        return try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isInteractive
        } catch (_: Exception) {
            true
        }
    }

    fun isKeyguardLocked(context: Context): Boolean {
        return try {
            val kg = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            kg.isKeyguardLocked
        } catch (_: Exception) {
            false
        }
    }

    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        return try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.canUseFullScreenIntent()
        } catch (_: Exception) {
            true
        }
    }

    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        return try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(context.packageName)
        } catch (_: Exception) {
            true
        }
    }

    private fun notifyFullScreen(
        context: Context,
        id: Int,
        title: String,
        body: String,
        intent: Intent,
        requestCode: Int,
        useFullScreen: Boolean = true,
    ) {
        ensureChannels(context)
        if (!notificationsAllowed(context)) {
            Log.e(TAG, "ALERT skipped — notifications disabled (POST_NOTIFICATIONS / app setting)")
            return
        }
        val pi = PendingIntent.getActivity(context, requestCode, intent, pendingFlags())
        val sound = alertSoundUri(context)
        val fsiAllowed = canUseFullScreenIntent(context)
        val applyFsi = useFullScreen && fsiAllowed
        Log.i(
            TAG,
            "notify id=$id fsi=$applyFsi wantFsi=$useFullScreen fsiPerm=$fsiAllowed " +
                "interactive=${isScreenInteractive(context)} " +
                "keyguard=${isKeyguardLocked(context)} " +
                "fg=${ParkingMonitorService.appInForeground} " +
                "battOptIgnored=${isIgnoringBatteryOptimizations(context)} " +
                "channel=$CHANNEL_ALERTS",
        )
        val builder = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_notification)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setSound(sound)
            .setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
            .setOnlyAlertOnce(false)
            .setTimeoutAfter(120_000L)
        if (applyFsi) {
            // High-priority FSI can light the lock screen / show over keyguard.
            builder.setFullScreenIntent(pi, true)
        } else if (useFullScreen && !fsiAllowed) {
            Log.w(
                TAG,
                "USE_FULL_SCREEN_INTENT not granted — heads-up + sound only (API 34+ settings)",
            )
        }
        // Keep CPU briefly awake so the notify + FSI launch are not deferred when dozing.
        acquireAlertWakeLock(context)
        notifySafe(context, id, builder.build())
    }

    private fun notifySafe(context: Context, id: Int, notification: Notification) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(id, notification)
        } catch (e: SecurityException) {
            Log.e(TAG, "notify failed (permission)", e)
        } catch (e: Exception) {
            Log.e(TAG, "notify failed", e)
        }
    }

    private fun acquireAlertWakeLock(context: Context) {
        try {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            @Suppress("DEPRECATION")
            val wl = pm.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "sosapp:parking_alert",
            )
            wl.setReferenceCounted(false)
            wl.acquire(4_000L)
        } catch (e: Exception) {
            Log.w(TAG, "wake lock failed", e)
        }
    }

    fun alertSoundUri(context: Context): Uri {
        // Packaged short beep (res/raw/notification_beep.mp3). Falls back safely if missing.
        return Uri.parse(
            "android.resource://${context.packageName}/${R.raw.notification_beep}",
        )
    }

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
