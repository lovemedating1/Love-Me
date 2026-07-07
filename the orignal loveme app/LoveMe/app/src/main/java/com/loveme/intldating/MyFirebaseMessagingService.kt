package com.loveme.intldating

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.RingtoneManager
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class MyFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        val title = remoteMessage.notification?.title ?: remoteMessage.data["title"] ?: "LoveMe"
        val body = remoteMessage.notification?.body ?: remoteMessage.data["body"] ?: ""
        val type = remoteMessage.data["type"] ?: ""
        val deepLink = remoteMessage.data["deep_link"] ?: ""

        val isCall = type == "call" || type == "video_call"

        if (!isCall) {
            sendNotification(title, body, type, deepLink)
        }
        // Call notifications are handled entirely by the web app — no Android notification shown
    }

    override fun onNewToken(token: String) {
        // Persist token so the WebView JS bridge can read it immediately on next load
        getSharedPreferences("loveme_prefs", Context.MODE_PRIVATE)
            .edit()
            .putString("fcm_token", token)
            .apply()
    }

    // Regular notification: messages, likes, activity
    private fun sendNotification(title: String, body: String, type: String, deepLink: String) {
        val intent = Intent(this, SplashActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (deepLink.isNotEmpty()) putExtra("deep_link", deepLink)
            if (type.isNotEmpty()) putExtra("notification_type", type)
        }
        val pendingIntent = PendingIntent.getActivity(
            this, System.currentTimeMillis().toInt(), intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, "loveme_default_channel")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 250, 250, 250))
            .setContentIntent(pendingIntent)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    // Call notification: banner with Accept/Decline buttons (no full-screen overlay)
    private fun sendCallNotification(title: String, body: String, deepLink: String) {
        val callerName = title.replace("Incoming call from ", "").trim()
        val callType = if (body.contains("video", ignoreCase = true)) "video_call" else "call"

        // Tapping the notification opens the app
        val openAppIntent = Intent(this, SplashActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            if (deepLink.isNotEmpty()) putExtra("deep_link", deepLink)
            putExtra("notification_type", callType)
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            this, 2001, openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Accept action — cancels notification then opens app via CallAcceptReceiver
        val acceptIntent = Intent(this, CallAcceptReceiver::class.java).apply {
            if (deepLink.isNotEmpty()) putExtra("deep_link", deepLink)
            putExtra("notification_type", callType)
        }
        val acceptPendingIntent = PendingIntent.getBroadcast(
            this, 2002, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Decline action — cancels notification directly
        val declineIntent = Intent(this, CallDeclineReceiver::class.java)
        val declinePendingIntent = PendingIntent.getBroadcast(
            this, 2003, declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        val notification = NotificationCompat.Builder(this, "loveme_call_channel")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setLargeIcon(BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher))
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setSound(ringtoneUri)
            .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
            .setContentIntent(openAppPendingIntent)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Decline", declinePendingIntent)
            .addAction(android.R.drawable.ic_menu_call, "Accept", acceptPendingIntent)
            .build()

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(2001, notification)
    }
}
