package com.im.wukong_im_app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader

object DeviceBadgeUtils {
    private const val ROM_MIUI = "MIUI"
    private const val ROM_EMUI = "EMUI"
    private const val ROM_FLYME = "FLYME"
    private const val ROM_OPPO = "OPPO"
    private const val ROM_SMARTISAN = "SMARTISAN"
    private const val ROM_VIVO = "VIVO"
    private const val ROM_QIKU = "QIKU"

    private const val KEY_VERSION_MIUI = "ro.miui.ui.version.name"
    private const val KEY_VERSION_EMUI = "ro.build.version.emui"
    private const val KEY_VERSION_OPPO = "ro.build.version.opporom"
    private const val KEY_VERSION_SMARTISAN = "ro.smartisan.version"
    private const val KEY_VERSION_VIVO = "ro.vivo.os.version"

    private var romName: String? = null
    private var romVersion: String? = null

    fun setBadge(context: Context, activityClassName: String, number: Int): Boolean {
        return when {
            isEmui() -> setHuaweiBadge(context, activityClassName, number)
            isVivo() -> setVivoBadge(context, activityClassName, number)
            isOppo() -> setOppoBadge(context, number)
            else -> false
        }
    }

    private fun isEmui(): Boolean = check(ROM_EMUI)

    private fun isVivo(): Boolean = check(ROM_VIVO)

    private fun isOppo(): Boolean = check(ROM_OPPO)

    private fun mightUseSupportedBadgeProvider(): Boolean {
        val manufacturer = Build.MANUFACTURER.uppercase()
        val brand = Build.BRAND.uppercase()
        val display = Build.DISPLAY.uppercase()
        return manufacturer.contains("HUAWEI") ||
            manufacturer.contains("HONOR") ||
            manufacturer.contains(ROM_VIVO) ||
            manufacturer.contains(ROM_OPPO) ||
            manufacturer.contains("REALME") ||
            manufacturer.contains("ONEPLUS") ||
            brand.contains("HUAWEI") ||
            brand.contains("HONOR") ||
            brand.contains(ROM_VIVO) ||
            brand.contains(ROM_OPPO) ||
            brand.contains("REALME") ||
            brand.contains("ONEPLUS") ||
            display.contains(ROM_FLYME)
    }

    private fun check(rom: String): Boolean {
        val cachedName = romName
        if (cachedName != null) {
            return cachedName == rom
        }

        if (!mightUseSupportedBadgeProvider()) {
            romVersion = Build.UNKNOWN
            romName = Build.MANUFACTURER.uppercase()
            return rom == ROM_QIKU && romName == "360"
        }

        romVersion = getProp(KEY_VERSION_MIUI)
        romName = when {
            !romVersion.isNullOrBlank() -> ROM_MIUI
            !getProp(KEY_VERSION_EMUI).isNullOrBlank() -> {
                romVersion = getProp(KEY_VERSION_EMUI)
                ROM_EMUI
            }
            !getProp(KEY_VERSION_OPPO).isNullOrBlank() -> {
                romVersion = getProp(KEY_VERSION_OPPO)
                ROM_OPPO
            }
            !getProp(KEY_VERSION_VIVO).isNullOrBlank() -> {
                romVersion = getProp(KEY_VERSION_VIVO)
                ROM_VIVO
            }
            !getProp(KEY_VERSION_SMARTISAN).isNullOrBlank() -> {
                romVersion = getProp(KEY_VERSION_SMARTISAN)
                ROM_SMARTISAN
            }
            Build.DISPLAY.uppercase().contains(ROM_FLYME) -> {
                romVersion = Build.DISPLAY
                ROM_FLYME
            }
            else -> {
                romVersion = Build.UNKNOWN
                Build.MANUFACTURER.uppercase()
            }
        }

        return romName == rom || (rom == ROM_QIKU && romName == "360")
    }

    private fun getProp(name: String): String? {
        var input: BufferedReader? = null
        return try {
            val process = Runtime.getRuntime().exec("getprop $name")
            input = BufferedReader(InputStreamReader(process.inputStream), 1024)
            input.readLine()
        } catch (_: IOException) {
            null
        } finally {
            try {
                input?.close()
            } catch (_: IOException) {
            }
        }
    }

    private fun setHuaweiBadge(
        context: Context,
        activityClassName: String,
        number: Int,
    ): Boolean {
        return try {
            val bundle = Bundle().apply {
                putString("package", context.packageName)
                putString("class", activityClassName)
                putInt("badgenumber", number)
            }
            context.contentResolver.call(
                Uri.parse("content://com.huawei.android.launcher.settings/badge/"),
                "change_badge",
                null,
                bundle,
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun setVivoBadge(
        context: Context,
        activityClassName: String,
        number: Int,
    ): Boolean {
        return try {
            val intent = Intent("launcher.action.CHANGE_APPLICATION_NOTIFICATION_NUM").apply {
                putExtra("packageName", context.packageName)
                putExtra("className", activityClassName)
                putExtra("notificationNum", number)
            }
            context.sendBroadcast(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun setOppoBadge(context: Context, number: Int): Boolean {
        return try {
            val targetNumber = if (number == 0) -1 else number
            val intent = Intent("com.oppo.unsettledevent").apply {
                putExtra("pakeageName", context.packageName)
                putExtra("number", targetNumber)
                putExtra("upgradeNumber", targetNumber)
            }
            if (canResolveBroadcast(context, intent)) {
                context.sendBroadcast(intent)
                true
            } else {
                val extras = Bundle().apply {
                    putInt("app_badge_count", targetNumber)
                }
                context.contentResolver.call(
                    Uri.parse("content://com.android.badge/badge"),
                    "setAppBadgeCount",
                    null,
                    extras,
                )
                true
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun canResolveBroadcast(context: Context, intent: Intent): Boolean {
        val packageManager: PackageManager = context.packageManager
        return packageManager.queryBroadcastReceivers(intent, 0).isNotEmpty()
    }
}
