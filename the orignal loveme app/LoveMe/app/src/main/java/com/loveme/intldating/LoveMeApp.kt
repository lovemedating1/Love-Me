package com.loveme.intldating

import android.app.Activity
import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager

class LoveMeApp : Application() {

    override fun onCreate() {
        super.onCreate()
        blockScreenshots()
        createNotificationChannels()
    }

    private fun blockScreenshots() {
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                activity.window.setFlags(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    WindowManager.LayoutParams.FLAG_SECURE
                )
            }
            override fun onActivityStarted(activity: Activity) {}
            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}
            override fun onActivityStopped(activity: Activity) {}
            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)

            // Channel 1: Regular notifications (likes, messages, activity)
            val generalChannel = NotificationChannel(
                "loveme_default_channel",
                "Messages & Activity",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Likes, messages, and activity from LoveMe"
                enableLights(true)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
            }
            manager.createNotificationChannel(generalChannel)

            // Channel 2: Incoming calls — uses device ringtone + long vibration, just like WhatsApp
            val ringtoneUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val callChannel = NotificationChannel(
                "loveme_call_channel",
                "Incoming Calls",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Incoming voice and video calls"
                setSound(ringtoneUri, audioAttributes)
                enableLights(true)
                enableVibration(true)
                // Long repeating vibration pattern like a phone ringing
                vibrationPattern = longArrayOf(0, 1000, 1000, 1000, 1000, 1000)
            }
            manager.createNotificationChannel(callChannel)
        }
    }
}
