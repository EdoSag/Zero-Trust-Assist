package dev.sagron.zerotrustassist

import android.app.ActivityManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.Debug
import android.os.PowerManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

// FlutterFragmentActivity, not FlutterActivity: the fingerprint prompt that
// unlocks the app needs a fragment activity.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // What the phone test records next to its speed numbers: which phone,
        // how much memory, how hot, how much battery. Read by
        // lib/lab/device_info.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "zt_assist/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Reading this app's memory walks every mapped page of a
                    // multi-gigabyte model, so it runs off the main thread
                    // and the screen never waits for it.
                    "snapshot" -> thread {
                        val values = runCatching { snapshot() }
                        runOnUiThread {
                            values.fold(
                                onSuccess = { result.success(it) },
                                onFailure = { result.error("snapshot", it.message, null) },
                            )
                        }
                    }
                    "keepAwake" -> {
                        // A long test must not stop because the screen timed out.
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun snapshot(): Map<String, Any?> {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memory = ActivityManager.MemoryInfo().also { activityManager.getMemoryInfo(it) }
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        val battery = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val soc = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            "${Build.SOC_MANUFACTURER} ${Build.SOC_MODEL}"
        } else {
            Build.HARDWARE
        }
        // Proportional set size: this app's real share of the phone's memory,
        // model included. Reported in kilobytes.
        val appMemory = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "soc" to soc,
            "sdk" to Build.VERSION.SDK_INT,
            "totalRamBytes" to memory.totalMem,
            "availableRamBytes" to memory.availMem,
            "lowMemory" to memory.lowMemory,
            "appMemoryBytes" to appMemory.totalPss.toLong() * 1024,
            "freeStorageBytes" to filesDir.usableSpace,
            "thermalStatus" to power.currentThermalStatus,
            "batteryPercent" to battery.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY),
            "charging" to battery.isCharging,
        )
    }
}
