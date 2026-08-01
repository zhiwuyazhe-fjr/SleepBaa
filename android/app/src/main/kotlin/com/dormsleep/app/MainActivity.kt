package com.dormsleep.app

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.HapticFeedbackConstants
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val USAGE_STATS_CHANNEL_NAME = "com.dormsleep.app/usage_stats"
        private const val HAPTICS_CHANNEL_NAME = "com.dormsleep.app/haptics"
    }

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
            USAGE_STATS_CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasUsageStatsPermission())
                "openPermissionSettings" -> {
                    openUsageStatsSettings()
                    result.success(null)
                }
                "getLastTwoHoursUsageMinutes" -> {
                    if (!hasUsageStatsPermission()) {
                        result.error(
                            "permission_denied",
                            "Usage access permission is required.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    result.success(readLastTwoHoursUsageMinutes())
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

    private fun readLastTwoHoursUsageMinutes(): Int {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val startTime = endTime - 2L * 60L * 60L * 1000L
        val aggregate = usageStatsManager.queryAndAggregateUsageStats(
            startTime,
            endTime,
        )
        val foregroundMs =
            aggregate.values
                .filter { it.packageName != packageName }
                .sumOf { stats -> stats.totalTimeInForeground.coerceAtLeast(0L) }
        return (foregroundMs / 60_000L).toInt()
    }
}
