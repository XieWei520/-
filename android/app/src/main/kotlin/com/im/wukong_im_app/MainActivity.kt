package com.im.wukong_im_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationSettingsChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationChannelSettings" -> {
                    val channelId = call.argument<String>("channelId")
                    result.success(openNotificationChannelSettings(channelId))
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceBadgeChannelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setBadgeCount" -> {
                    val count = call.argument<Int>("count") ?: 0
                    result.success(
                        DeviceBadgeUtils.setBadge(
                            applicationContext,
                            "$packageName.MainActivity",
                            count,
                        ),
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun openNotificationChannelSettings(channelId: String?): Boolean {
        val intent = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !channelId.isNullOrBlank()) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                }
            }
        } catch (_: Exception) {
            return false
        }

        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        private const val notificationSettingsChannelName =
            "wukong_im_app/notification_settings"
        private const val deviceBadgeChannelName =
            "wukong_im_app/device_badge"
    }
}
