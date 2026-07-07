package com.loveme.intldating

import android.app.KeyguardManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class IncomingCallActivity : AppCompatActivity() {

    private val autoDeclineHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show over lock screen like WhatsApp
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            keyguardManager.requestDismissKeyguard(this, null)
        }

        setContentView(R.layout.activity_incoming_call)

        val callerName = intent.getStringExtra("caller_name") ?: "Someone"
        val callType = intent.getStringExtra("call_type") ?: "voice"
        val deepLink = intent.getStringExtra("deep_link") ?: ""

        findViewById<TextView>(R.id.tvCallerName).text = callerName
        findViewById<TextView>(R.id.tvCallType).text =
            if (callType == "video_call") "Incoming Video Call" else "Incoming Voice Call"

        // Auto-dismiss after 60 seconds if no action
        autoDeclineHandler.postDelayed({ finishAndDismiss() }, 60_000)

        findViewById<android.widget.ImageButton>(R.id.btnAccept).setOnClickListener {
            autoDeclineHandler.removeCallbacksAndMessages(null)
            // Open the app to the call screen
            val mainIntent = Intent(this, SplashActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                if (deepLink.isNotEmpty()) putExtra("deep_link", deepLink)
                putExtra("notification_type", callType)
                putExtra("call_accepted", true)
            }
            startActivity(mainIntent)
            finishAndDismiss()
        }

        findViewById<android.widget.ImageButton>(R.id.btnDecline).setOnClickListener {
            autoDeclineHandler.removeCallbacksAndMessages(null)
            finishAndDismiss()
        }
    }

    private fun finishAndDismiss() {
        // Cancel the ongoing call notification
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(2001)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        autoDeclineHandler.removeCallbacksAndMessages(null)
    }
}
