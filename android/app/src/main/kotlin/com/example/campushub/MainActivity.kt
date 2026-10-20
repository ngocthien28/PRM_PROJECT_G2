package com.example.campushub

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build

class MainActivity : FlutterActivity() {
    private var notifications: MethodChannel? = null
    private val channelId = "campushub_updates"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notifications = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "campushub/notifications")
        notifications?.setMethodCallHandler { call, result ->
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            when (call.method) {
                "initialize" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        manager.createNotificationChannel(NotificationChannel(
                            channelId, "CampusHub updates", NotificationManager.IMPORTANCE_HIGH
                        ).apply { description = "Club membership and campus updates" })
                    }
                    result.success(null)
                    dispatchNotificationIntent(intent)
                }
                "show" -> {
                    val id = call.argument<String>("id")
                    if (id == null) { result.error("invalid-id", "Notification ID required", null) }
                    else try {
                        val target = Intent(this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                            putExtra("campushub_notification_id", id)
                        }
                        val pending = PendingIntent.getActivity(this, id.hashCode(), target,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                            Notification.Builder(this, channelId) else Notification.Builder(this)
                        val body = call.argument<String>("body") ?: ""
                        manager.notify(id, 0, builder
                            .setSmallIcon(R.drawable.ic_notification)
                            .setContentTitle(call.argument<String>("title") ?: "CampusHub")
                            .setContentText(body)
                            .setStyle(Notification.BigTextStyle().bigText(body))
                            .setPriority(Notification.PRIORITY_HIGH)
                            .setAutoCancel(true).setContentIntent(pending).build())
                        result.success(null)
                    } catch (error: SecurityException) {
                        result.error("permission-denied", "Notification permission is disabled", null)
                    }
                }
                "cancelAll" -> { manager.cancelAll(); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchNotificationIntent(intent)
    }

    private fun dispatchNotificationIntent(intent: Intent?) {
        val id = intent?.getStringExtra("campushub_notification_id") ?: return
        notifications?.invokeMethod("tap", id)
        intent.removeExtra("campushub_notification_id")
    }
}
