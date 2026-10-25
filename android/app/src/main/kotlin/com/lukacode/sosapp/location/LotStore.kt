package com.lukacode.sosapp.location

import android.content.Context
import org.json.JSONArray
import java.io.File

object LotStore {
    private const val FILE = "parkings_cache.json"

    fun saveJson(context: Context, json: String) {
        File(context.filesDir, FILE).writeText(json)
    }

    fun load(context: Context): List<ParkingLotPoint> {
        val file = File(context.filesDir, FILE)
        if (!file.exists()) return emptyList()
        return try {
            val arr = JSONArray(file.readText())
            val out = ArrayList<ParkingLotPoint>(arr.length())
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                out.add(
                    ParkingLotPoint(
                        id = o.optString("id", o.optString("lotNumber")),
                        lotNumber = o.optString("lotNumber"),
                        lat = o.getDouble("lat"),
                        lng = o.getDouble("lng"),
                    ),
                )
            }
            out
        } catch (_: Exception) {
            emptyList()
        }
    }
}
