package com.lukacode.sosapp.location

import android.content.SharedPreferences

/** 10-minute global cooldown + same-lot silence until the user leaves. */
class LotPromptPolicy(private val prefs: SharedPreferences) {
    fun decline(lots: Collection<String>, lat: Double, lng: Double) {
        prefs.edit()
            .putLong(PREF_SUPPRESS_UNTIL, System.currentTimeMillis() + GLOBAL_COOLDOWN_MS)
            .putString(PREF_DECLINED_LOTS, lots.filter { it.isNotBlank() }.joinToString("\n"))
            .putString(PREF_DECLINED_LAT, lat.toString())
            .putString(PREF_DECLINED_LNG, lng.toString())
            .apply()
    }

    fun noteFix(nearbyLots: List<String>, lat: Double, lng: Double) {
        val declined = declinedLots()
        if (declined.isEmpty()) return
        val stillAtLot = nearbyLots.any { declined.contains(it) }
        val dLat = prefs.getString(PREF_DECLINED_LAT, null)?.toDoubleOrNull()
        val dLng = prefs.getString(PREF_DECLINED_LNG, null)?.toDoubleOrNull()
        val dist = if (dLat == null || dLng == null) {
            Double.POSITIVE_INFINITY
        } else {
            LotIndex.haversineMeters(lat, lng, dLat, dLng)
        }
        if (!stillAtLot && dist > LEAVE_METERS) {
            prefs.edit()
                .remove(PREF_DECLINED_LOTS)
                .remove(PREF_DECLINED_LAT)
                .remove(PREF_DECLINED_LNG)
                .apply()
        }
    }

    fun canPrompt(lots: List<String>, lat: Double, lng: Double): Boolean {
        noteFix(lots, lat, lng)
        if (lots.isEmpty()) return false
        val until = prefs.getLong(PREF_SUPPRESS_UNTIL, 0L)
        if (until > System.currentTimeMillis()) return false
        val declined = declinedLots()
        if (lots.any { declined.contains(it) }) return false
        return true
    }

    private fun declinedLots(): Set<String> {
        val raw = prefs.getString(PREF_DECLINED_LOTS, null) ?: return emptySet()
        return raw.split('\n').map { it.trim() }.filter { it.isNotEmpty() }.toSet()
    }

    companion object {
        const val GLOBAL_COOLDOWN_MS = 10 * 60 * 1000L
        const val LEAVE_METERS = 50.0
        const val PREF_SUPPRESS_UNTIL = "suppress_until"
        const val PREF_DECLINED_LOTS = "declined_lots"
        const val PREF_DECLINED_LAT = "declined_lat"
        const val PREF_DECLINED_LNG = "declined_lng"
        const val PREF_PENDING_LOTS = "pending_prompt_lots"
        const val DWELL_MS = 5_000L
    }
}
