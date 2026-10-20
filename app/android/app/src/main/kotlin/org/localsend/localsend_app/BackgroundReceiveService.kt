// Modified by Tony Destin (limmieo), 2026: Android background receiving and incoming notification controls; AI-assisted implementation.
package org.localsend.localsend_app

import android.app.Notification
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.Bundle
import android.os.ResultReceiver
import android.os.PowerManager
import android.provider.Settings

/** Keeps the existing Flutter receiver reachable while its activity is backgrounded.
 * This does not cold-start a Flutter engine after process death or a force stop.
 */
class BackgroundReceiveService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        @Suppress("DEPRECATION")
        val result = intent?.getParcelableExtra<ResultReceiver>("result")
        try {
            startListening(intent)
            result?.send(Activity.RESULT_OK, null)
        } catch (e: Exception) {
            stopSelf()
            result?.send(Activity.RESULT_CANCELED, Bundle().apply { putString("error", e.message) })
        }
        // Do not advertise availability after process death without a receiver engine.
        return START_NOT_STICKY
    }

    private fun startListening(intent: Intent?) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(LISTEN_CHANNEL, "LocalSend availability", NotificationManager.IMPORTANCE_LOW))
        }
        val notification = builder(this, LISTEN_CHANNEL)
            .setSmallIcon(R.drawable.ic_receive_notification)
            .setContentTitle(intent?.getStringExtra("title") ?: "LocalSend")
            .setContentText(intent?.getStringExtra("text") ?: "Ready to receive")
            .setContentIntent(openApp(this))
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(LISTEN_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(LISTEN_ID, notification)
        }
        if (wakeLock == null) {
            wakeLock = getSystemService(PowerManager::class.java)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:background-receive")
                .apply { setReferenceCounted(false); acquire() }
            multicastLock = (applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager)
                .createMulticastLock("localsend-background-receive")
                .apply { setReferenceCounted(false); acquire() }
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // FlutterActivity owns the engine. Once the task is removed, no listener is guaranteed.
        stopSelf()
    }

    override fun onDestroy() {
        wakeLock?.let { if (it.isHeld) it.release() }
        multicastLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
        multicastLock = null
        @Suppress("DEPRECATION")
        stopForeground(true)
        clearRequest(this)
        super.onDestroy()
    }

    companion object {
        private const val LISTEN_CHANNEL = "localsend_background_receive"
        private const val REQUEST_CHANNEL = "localsend_incoming_requests"
        private const val LISTEN_ID = 2
        private const val REQUEST_ID = 3

        @Suppress("DEPRECATION")
        private fun builder(context: Context, channel: String): Notification.Builder =
            if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)

        private fun openApp(context: Context): PendingIntent = PendingIntent.getActivity(
            context, REQUEST_ID,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        private fun createRequestChannel(context: Context) {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(REQUEST_CHANNEL, "LocalSend incoming requests", NotificationManager.IMPORTANCE_HIGH))
            }
        }

        /** Android owns channel sound preferences, including the user's chosen tone. */
        fun openSoundSettings(context: Context) {
            createRequestChannel(context)
            val intent = if (Build.VERSION.SDK_INT >= 26) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, REQUEST_CHANNEL)
            } else {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    .putExtra("app_package", context.packageName)
                    .putExtra("app_uid", context.applicationInfo.uid)
            }
            context.startActivity(intent)
        }

        fun showRequest(context: Context, title: String, text: String) {
            createRequestChannel(context)
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(REQUEST_ID, builder(context, REQUEST_CHANNEL)
                .setSmallIcon(R.drawable.ic_receive_notification)
                .setContentTitle(title)
                .setContentText(text)
                .setContentIntent(openApp(context))
                .setCategory(Notification.CATEGORY_MESSAGE)
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setPriority(Notification.PRIORITY_HIGH)
                .setDefaults(Notification.DEFAULT_ALL)
                .setAutoCancel(true)
                .build())
        }

        fun clearRequest(context: Context) {
            context.getSystemService(NotificationManager::class.java).cancel(REQUEST_ID)
        }
    }
}
