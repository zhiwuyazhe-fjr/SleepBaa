package com.dormsleep.app

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.os.VibrationEffect
import android.os.Vibrator
import android.provider.Settings
import android.view.HapticFeedbackConstants
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val USAGE_STATS_CHANNEL_NAME = "com.dormsleep.app/usage_stats"
        private const val ENVIRONMENT_SENSORS_CHANNEL_NAME =
            "com.dormsleep.app/environment_sensors"
        private const val HAPTICS_CHANNEL_NAME = "com.dormsleep.app/haptics"
        private const val ONE_HOUR_MS = 60L * 60L * 1000L
        private const val USAGE_LOOKBACK_MS = 24L * 60L * 60L * 1000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HAPTICS_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "impact" -> result.success(performHapticImpact(call.argument<String>("style")))
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ENVIRONMENT_SENSORS_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "readAmbientLightLux" -> readAmbientLightLux(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            USAGE_STATS_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasUsageStatsPermission())
                "openPermissionSettings" -> {
                    openUsageStatsSettings()
                    result.success(null)
                }
                "getLastHourUsageMinutes" -> {
                    if (!hasUsageStatsPermission()) {
                        result.error(
                            "permission_denied",
                            "Usage access permission is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(readLastHourUsageMinutes())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun performHapticImpact(style: String?): Boolean {
        val feedback = when (style) {
            "medium", "heavy" -> HapticFeedbackConstants.LONG_PRESS
            else -> HapticFeedbackConstants.VIRTUAL_KEY
        }
        if (window.decorView.performHapticFeedback(feedback)) {
            return true
        }

        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            ?: return false
        if (!vibrator.hasVibrator()) {
            return false
        }
        val duration = if (style == "heavy") 42L else 18L
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(
                VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(duration)
        }
        return true
    }

    private fun readAmbientLightLux(result: MethodChannel.Result) {
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val lightSensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)
        if (lightSensor == null) {
            result.success(null)
            return
        }

        val samples = mutableListOf<Float>()
        var completed = false
        lateinit var listener: SensorEventListener
        lateinit var timeout: Runnable

        fun finish() {
            if (completed) {
                return
            }
            completed = true
            sensorManager.unregisterListener(listener)
            mainHandler.removeCallbacks(timeout)
            if (samples.isEmpty()) {
                result.error("sensor_unavailable", "No ambient light reading was returned.", null)
                return
            }
            val sorted = samples.sorted()
            val middle = sorted.size / 2
            val median = if (sorted.size % 2 == 1) {
                sorted[middle].toDouble()
            } else {
                (sorted[middle - 1] + sorted[middle]).toDouble() / 2.0
            }
            result.success(median)
        }

        listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val lux = event.values.firstOrNull() ?: return
                if (lux.isFinite() && lux >= 0f) {
                    samples.add(lux)
                }
                if (samples.size >= 5) {
                    finish()
                }
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        timeout = Runnable { finish() }

        val registered = sensorManager.registerListener(
            listener,
            lightSensor,
            SensorManager.SENSOR_DELAY_NORMAL,
        )
        if (!registered) {
            completed = true
            result.success(null)
            return
        }
        mainHandler.postDelayed(timeout, 1800L)
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName,
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    packageName,
                )
            }
        if (mode == AppOpsManager.MODE_ALLOWED) {
            return true
        }

        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val recent = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 60_000L,
            now,
        )
        return recent.isNotEmpty()
    }

    private fun openUsageStatsSettings() {
        startActivity(
            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            },
        )
    }

    private fun readLastHourUsageMinutes(): Int {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - ONE_HOUR_MS
        val events = usageStatsManager.queryEvents(
            startTime - USAGE_LOOKBACK_MS,
            endTime,
        )

        var activePackage: String? = null
        var activeSince = startTime
        var foregroundMs = 0L
        val event = UsageEvents.Event()

        fun closeActive(atTime: Long) {
            val currentPackage = activePackage ?: return
            val intervalStart = maxOf(activeSince, startTime)
            val intervalEnd = minOf(atTime, endTime)
            if (currentPackage != packageName && intervalEnd > intervalStart) {
                foregroundMs += intervalEnd - intervalStart
            }
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val eventPackage = event.packageName
            val eventTime = event.timeStamp
            val isForeground =
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            val isBackground =
                event.eventType == UsageEvents.Event.MOVE_TO_BACKGROUND ||
                    event.eventType == UsageEvents.Event.ACTIVITY_PAUSED
            val isScreenOff = event.eventType == UsageEvents.Event.SCREEN_NON_INTERACTIVE

            if (eventTime < startTime) {
                when {
                    isScreenOff -> activePackage = null
                    isForeground && eventPackage != null -> {
                        activePackage = eventPackage
                        activeSince = startTime
                    }
                    isBackground && activePackage == eventPackage -> activePackage = null
                }
                continue
            }

            when {
                isScreenOff -> {
                    closeActive(eventTime)
                    activePackage = null
                }
                isForeground && eventPackage != null -> {
                    closeActive(eventTime)
                    activePackage = eventPackage
                    activeSince = eventTime
                }
                isBackground && activePackage == eventPackage -> {
                    closeActive(eventTime)
                    activePackage = null
                }
            }
        }

        closeActive(endTime)
        return (foregroundMs.coerceIn(0L, ONE_HOUR_MS) / 60_000L).toInt()
    }
}
