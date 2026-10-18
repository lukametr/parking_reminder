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
    const val CHANNEL_MONITOR = "parking_monitor"
    const val CHANNEL_ALERTS = "parking_alerts"
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
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "მუდმივი შეტყობინება, სანამ ლოკაცია იზომება" },
        )
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ALERTS,
                "პარკინგის შეხსენებები",
                NotificationManager.IMPORTANCE_HIGH,
            ),
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
            .setContentTitle("პარკინგის შეხსენება")
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(launch)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    fun showAlert(context: Context, title: String, body: String, extraLots: String? = null) {
        ensureChannels(context)
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("lots", extraLots)
        }
        val pi = PendingIntent.getActivity(context, 1, intent, pendingFlags())
        val n = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(ALERT_ID, n)
    }

    fun showLeaveAlert(context: Context, title: String, body: String) {
        ensureChannels(context)
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("leave_lot", true)
        }
        val pi = PendingIntent.getActivity(context, 2, intent, pendingFlags())
        val n = NotificationCompat.Builder(context, CHANNEL_ALERTS)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setAutoCancel(true)
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(REMINDER_ID, n)
    }

    private fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
