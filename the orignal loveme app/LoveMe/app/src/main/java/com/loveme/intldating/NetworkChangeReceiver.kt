package com.loveme.intldating

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager

class NetworkChangeReceiver(private val callback: (isConnected: Boolean) -> Unit) : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        val isConnected = NetworkUtil.isInternetAvailable(context ?: return)
        callback(isConnected)
    }
}
