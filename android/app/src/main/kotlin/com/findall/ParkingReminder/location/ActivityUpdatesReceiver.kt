package com.findall.ParkingReminder.location

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity

class ActivityUpdatesReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (!ActivityRecognitionResult.hasResult(intent)) return
        val result = ActivityRecognitionResult.extractResult(intent) ?: return
        val probable = result.mostProbableActivity ?: return
        if (probable.type == DetectedActivity.TILTING) return
        val i = Intent()
            .setAction(ParkingMonitorService.ACTION_ACTIVITY)
            .putExtra(ParkingMonitorService.EXTRA_ACTIVITY, probable.type)
        ParkingMonitorService.start(context, i)
    }
}
