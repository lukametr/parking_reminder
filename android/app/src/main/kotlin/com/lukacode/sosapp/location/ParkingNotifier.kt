package com.lukacode.sosapp.location

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.lukacode.sosapp.MainActivity
import com.lukacode.sosapp.R

object ParkingNotifier {
    /** New id: old `parking_monitor` was IMPORTANCE_LOW and Android never upgrades it. */
    const val CHANNEL_MONITOR = "parking_monitor_ongoing"
    const val CHANNEL_ALERTS = "parking_alerts_heads"
    const val MONITOR_ID = 888
    const val ALERT_ID = 890
    const val REMINDER_ID = 891

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
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ALERTS,
                "პარკინგის შეხსენებები",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Stay / leave prompts — heads-up and lock screen"
                enableVibration(true)
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
            useFullScreen = !ParkingMonitorService.appInForeground,
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
        )
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
        val pi = PendingIntent.getActivity(context, requestCode, intent, pendingFlags())
        val builder = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_notification)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
        if (useFullScreen) {
            builder.setFullScreenIntent(pi, true)
        }
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(id, builder.build())
    }

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
