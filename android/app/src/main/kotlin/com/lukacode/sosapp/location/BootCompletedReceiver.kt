package com.lukacode.sosapp.location

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            return
        }
        val wanted = context.getSharedPreferences(
            ParkingMonitorService.PREFS,
            Context.MODE_PRIVATE,
        ).getBoolean(ParkingMonitorService.PREF_WANTED, false)
        if (wanted) {
            ParkingMonitorService.start(context)
        }
    }
}
