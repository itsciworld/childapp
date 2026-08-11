package com.app.vigil.child.app

/**
 * The single source of truth for which social / messaging apps the capture
 * services watch, and their human-friendly display names.
 *
 * Both [VigilNotificationListenerService] and [VigilAccessibilityService] read
 * this list, and the same package list is mirrored in
 * `res/xml/accessibility_service_config.xml` (`android:packageNames`) so the
 * accessibility service is only ever woken for these apps.
 *
 * Add a new app here AND in that XML to start capturing it.
 */
object SocialApps {
    val TARGET_APPS: Map<String, String> = mapOf(
        "com.whatsapp" to "WhatsApp",
        "com.whatsapp.w4b" to "WhatsApp Business",
        "org.telegram.messenger" to "Telegram",
        "org.telegram.plus" to "Telegram Plus",
        "com.instagram.android" to "Instagram",
        "com.facebook.orca" to "Messenger",
        "com.facebook.mlite" to "Messenger Lite",
        "com.snapchat.android" to "Snapchat",
        "com.discord" to "Discord",
        "org.thoughtcrime.securesms" to "Signal",
        "com.viber.voip" to "Viber",
        "com.twitter.android" to "X (Twitter)",
        "com.zhiliaoapp.musically" to "TikTok",
        "jp.naver.line.android" to "LINE",
        "kik.android" to "Kik"
    )

    fun isTarget(pkg: String?): Boolean = pkg != null && TARGET_APPS.containsKey(pkg)

    fun nameFor(pkg: String?): String = TARGET_APPS[pkg] ?: (pkg ?: "Unknown")
}
