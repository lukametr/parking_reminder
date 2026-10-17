package com.findall.ParkingReminder.location

import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

data class ParkingLotPoint(
    val id: String,
    val lotNumber: String,
    val lat: Double,
    val lng: Double,
)

class LotIndex(
    lots: List<ParkingLotPoint>,
    private val cellDegrees: Double = 0.00045,
) {
    private val cells = HashMap<String, MutableList<ParkingLotPoint>>()

    init {
        for (lot in lots) {
            cells.getOrPut(cellKey(lot.lat, lot.lng)) { mutableListOf() }.add(lot)
        }
    }

    fun nearby(lat: Double, lng: Double, radiusMeters: Double): List<ParkingLotPoint> {
        val i0 = kotlin.math.floor(lat / cellDegrees).toInt()
        val j0 = kotlin.math.floor(lng / cellDegrees).toInt()
        val out = ArrayList<ParkingLotPoint>()
        for (di in -1..1) {
            for (dj in -1..1) {
                val cell = cells["${i0 + di}:${j0 + dj}"] ?: continue
                for (lot in cell) {
                    if (haversineMeters(lat, lng, lot.lat, lot.lng) <= radiusMeters) {
                        out.add(lot)
                    }
                }
            }
        }
        return out.sortedBy { haversineMeters(lat, lng, it.lat, it.lng) }
    }

    fun nearest(lat: Double, lng: Double, limit: Int, maxMeters: Double): List<ParkingLotPoint> {
        // Coarse: scan neighboring cells expanding until we have enough, fallback scan all.
        val candidates = nearby(lat, lng, maxMeters)
        if (candidates.size >= limit || maxMeters < 80) {
            return candidates.take(limit)
        }
        return cells.values.flatten()
            .map { it to haversineMeters(lat, lng, it.lat, it.lng) }
            .filter { it.second <= maxMeters }
            .sortedBy { it.second }
            .take(limit)
            .map { it.first }
    }

    private fun cellKey(lat: Double, lng: Double): String {
        val i = kotlin.math.floor(lat / cellDegrees).toInt()
        val j = kotlin.math.floor(lng / cellDegrees).toInt()
        return "$i:$j"
    }

    companion object {
        fun haversineMeters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
            val r = 6371000.0
            val p1 = Math.toRadians(lat1)
            val p2 = Math.toRadians(lat2)
            val dLat = Math.toRadians(lat2 - lat1)
            val dLng = Math.toRadians(lng2 - lng1)
            val a = sin(dLat / 2) * sin(dLat / 2) +
                cos(p1) * cos(p2) * sin(dLng / 2) * sin(dLng / 2)
            return 2 * r * asin(sqrt(a.coerceAtMost(1.0)))
        }
    }
}
