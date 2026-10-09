package com.lalema.lalema

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

internal class ReminderService(private val context: Context) {
    private val prefs get() = context.getSharedPreferences("lalema_reminders", Context.MODE_PRIVATE)
    private val manager get() = context.getSystemService(NotificationManager::class.java)
    private val alarms get() = context.getSystemService(AlarmManager::class.java)
    private val enabled get() = prefs.getBoolean("enabled", false)
    private val hour get() = prefs.getInt("hour", 20)
    private val minute get() = prefs.getInt("minute", 0)
    private val generation get() = prefs.getLong("generation", 0)

    fun permission(): String {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            return if (prefs.getBoolean("asked", false)) "denied" else "notDetermined"
        }
        if (!manager.areNotificationsEnabled()) return "denied"
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return "denied"
        return "allowed"
    }

    fun markPermissionAsked() { check(prefs.edit().putBoolean("asked", true).commit()) }

    private fun alarmIntent(at: Long = 0): PendingIntent = PendingIntent.getBroadcast(
        context, DAILY_ID,
        Intent(context, ReminderReceiver::class.java).setAction(FIRE)
            .putExtra("generation", generation).putExtra("at", at),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    fun reconcile(): Long? {
        require(hour in 0..23 && minute in 0..59)
        if (!enabled || permission() != "allowed") {
            alarms.cancel(alarmIntent())
            check(prefs.edit().remove("next").commit())
            return null
        }
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "每日记录提醒", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "按你选择的时间发送通用记录提醒"
                lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            })
        }
        val next = ReminderSchedule.next(System.currentTimeMillis(), hour, minute, TimeZone.getDefault(), prefs.getString("lastDay", null))
        check(prefs.edit().putLong("next", next).commit())
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, alarmIntent(next))
        return next
    }

    fun state(): Map<String, Any?> {
        val next = reconcile()
        return mapOf("enabled" to enabled, "hour" to hour, "minute" to minute,
            "permission" to permission(), "scheduled" to (next != null), "nextAt" to next)
    }

    fun configure(active: Boolean, selectedHour: Int, selectedMinute: Int): Map<String, Any?> {
        require(selectedHour in 0..23 && selectedMinute in 0..59)
        check(!active || permission() == "allowed")
        check(prefs.edit().putBoolean("enabled", active).putInt("hour", selectedHour)
            .putInt("minute", selectedMinute).putLong("generation", generation + 1).commit())
        if (!active) { manager.cancel(DAILY_ID); manager.cancel(TEST_ID) }
        return state()
    }

    fun receive(intent: Intent) {
        if (intent.action != FIRE) { reconcile(); return }
        val now = System.currentTimeMillis()
        val valid = enabled && intent.getLongExtra("generation", -1) == generation &&
            intent.getLongExtra("at", -1) == prefs.getLong("next", 0) &&
            now >= intent.getLongExtra("at", Long.MAX_VALUE)
        val day = ReminderSchedule.dayKey(now, TimeZone.getDefault())
        if (valid && permission() == "allowed" && prefs.getString("lastDay", null) != day) {
            check(prefs.edit().putString("lastDay", day).commit())
            reconcile()
            show(DAILY_ID)
        } else reconcile()
    }

    fun showTest() { check(permission() == "allowed"); show(TEST_ID) }

    private fun show(id: Int) {
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(CHANNEL, "每日记录提醒", NotificationManager.IMPORTANCE_DEFAULT))
        val open = PendingIntent.getActivity(context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        manager.notify(id, builder.setSmallIcon(R.drawable.ic_stat_reminder)
            .setContentTitle(if (id == TEST_ID) "测试提醒" else "记录提醒")
            .setContentText("有空时，记下今天的情况。按自己的节奏来。")
            .setContentIntent(open).setAutoCancel(true).setVisibility(Notification.VISIBILITY_PRIVATE).build())
    }

    companion object {
        const val FIRE = "com.lalema.lalema.DAILY_REMINDER"
        private const val CHANNEL = "lalema_daily_reminder"
        private const val DAILY_ID = 3101
        private const val TEST_ID = 3102
        const val PERMISSION_REQUEST = 3103
    }
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // A revoked permission or failed system service must not crash app start
        // or boot. The next foreground read retries reconciliation visibly.
        try { ReminderService(context).receive(intent) } catch (_: Exception) { }
    }
}

internal class ReminderChannel(private val activity: MainActivity) {
    private val service = ReminderService(activity)
    private var permissionResult: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "getState" -> result.success(service.state())
                "configure" -> result.success(service.configure(
                    call.argument<Boolean>("enabled") ?: error("Missing enabled"),
                    call.argument<Int>("hour") ?: error("Missing hour"),
                    call.argument<Int>("minute") ?: error("Missing minute")))
                "requestPermission" -> {
                    check(permissionResult == null)
                    if (Build.VERSION.SDK_INT >= 33 && service.permission() != "allowed" &&
                        activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        service.markPermissionAsked()
                        permissionResult = result
                        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), ReminderService.PERMISSION_REQUEST)
                    } else result.success(service.state())
                }
                "openSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
                        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:${activity.packageName}"))
                    activity.startActivity(intent)
                    result.success(null)
                }
                "test" -> { service.showTest(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            if (permissionResult === result) permissionResult = null
            result.error("REMINDER_UNAVAILABLE", "Unable to update reminders", null)
        }
    }

    fun permissionReturned() {
        val result = permissionResult ?: return
        permissionResult = null
        try { result.success(service.state()) }
        catch (_: Exception) { result.error("REMINDER_UNAVAILABLE", "Unable to read reminders", null) }
    }
}
