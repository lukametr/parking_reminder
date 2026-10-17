package com.findall.ParkingReminder.location

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import org.json.JSONObject

object MonitorBridge {
    private val main = Handler(Looper.getMainLooper())
    @Volatile
    var sink: EventChannel.EventSink? = null

    fun emit(json: JSONObject) {
        val map = HashMap<String, Any?>()
        val keys = json.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            val v = json.get(k)
            map[k] = when (v) {
                is org.json.JSONArray -> {
                    val list = ArrayList<Any?>()
                    for (i in 0 until v.length()) list.add(v.get(i))
                    list
                }
                JSONObject.NULL -> null
                else -> v
            }
        }
        main.post { sink?.success(map) }
    }
}
