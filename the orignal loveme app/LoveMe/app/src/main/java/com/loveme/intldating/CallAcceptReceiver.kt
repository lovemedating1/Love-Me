package com.loveme.intldating

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class CallAcceptReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Cancel the call notification immediately
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(2001)

        // Open the app
        val openApp = Intent(context, SplashActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            intent.getStringExtra("deep_link")?.let { putExtra("deep_link", it) }
            intent.getStringExtra("notification_type")?.let { putExtra("notification_type", it) }
            putExtra("call_accepted", true)
        }
        context.startActivity(openApp)
    }
}
