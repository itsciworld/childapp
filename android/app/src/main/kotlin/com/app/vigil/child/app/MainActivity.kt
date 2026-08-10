package com.app.vigil.child.app

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the two special-access permissions to Flutter. These can't be granted
 * through the normal runtime-permission dialog — the child has to flip a switch
 * on a system Settings page — so the [PermissionService] on the Dart side calls
 * these methods to (a) check the current state and (b) open the right page.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "vigil/special_access"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationAccessEnabled" -> result.success(isNotificationAccessEnabled())
                    "openNotificationAccessSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())
                    "openAccessibilitySettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** True when "Notification access" is enabled for this app (FEATURE A). */
    private fun isNotificationAccessEnabled(): Boolean =
        NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)

    /** True when [VigilAccessibilityService] is enabled in Settings (FEATURE B). */
    private fun isAccessibilityEnabled(): Boolean {
        val full = "$packageName/$packageName.VigilAccessibilityService"
        val short = "$packageName/.VigilAccessibilityService"
        val enabled = Settings.Secure.getString(
            contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val splitter = TextUtils.SimpleStringSplitter(':')
        splitter.setString(enabled)
        for (component in splitter) {
            if (component.equals(full, ignoreCase = true) ||
                component.equals(short, ignoreCase = true)
            ) return true
        }
        return false
    }
}
