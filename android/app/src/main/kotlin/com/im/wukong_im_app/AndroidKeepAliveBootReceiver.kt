package com.im.wukong_im_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AndroidKeepAliveBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            AndroidKeepAliveForegroundService.start(context.applicationContext)
        }
    }
}
