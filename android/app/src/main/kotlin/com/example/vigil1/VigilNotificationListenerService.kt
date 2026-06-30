package com.example.vigil1

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject

/**
 * FEATURE A — Notification capture.
 *
 * Once the child enables "Notification access" for Vigil, Android delivers every
 * notification posted on the device to [onNotificationPosted]. We keep only the
 * ones from messaging apps (see [SocialApps]) and write a compact record to the
 * shared JSONL queue, which the Flutter background isolate drains and (later)
 * uploads.
 *
 * Coverage: any app that shows a message notification — works fully in the
 * background, even when our UI is closed. Limit: the text is the notification
 * *preview* (WhatsApp truncates ~100 chars) and nothing arrives for chats the
 * child has muted or is actively reading.
 */
class VigilNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "VigilNotif"
        private const val FILE = "notif_queue.jsonl"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            val sb = sbn ?: return
            val pkg = sb.packageName
            if (!SocialApps.isTarget(pkg)) return

            val n = sb.notification ?: return
            // Skip the per-app summary line and ongoing/foreground notifications
            // (e.g. WhatsApp's "Checking for new messages") — they aren't chats.
            if ((n.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return
            if ((n.flags and Notification.FLAG_ONGOING_EVENT) != 0) return

            val extras = n.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim()
            val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
            val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim()

            // Prefer the expanded text when present (it's the fullest version).
            val body = (bigText?.takeIf { it.isNotEmpty() }
                ?: text?.takeIf { it.isNotEmpty() })
                ?: return

            if (isNoise(body)) return

            val isGroup = !subText.isNullOrEmpty()
            val postedAt = if (sb.postTime > 0L) sb.postTime else System.currentTimeMillis()

            val obj = JSONObject().apply {
                put("source", "notification")
                put("package", pkg)
                put("app", SocialApps.nameFor(pkg))
                put("title", title ?: "")
                put("text", body)
                put("subText", subText ?: "")
                put("isGroup", isGroup)
                put("postedAt", postedAt)
            }

            // Same message can be re-posted as the notification updates; fold to
            // one record per minute.
            val dedup = "$pkg|$title|$body|${postedAt / 60000L}"
            SocialQueueWriter.append(applicationContext, FILE, obj, dedup)
            Log.d(TAG, "captured ${SocialApps.nameFor(pkg)} <- ${title ?: "?"}")
        } catch (t: Throwable) {
            Log.w(TAG, "capture failed", t)
        }
    }

    /** Filters out non-chat notification text (typing indicators, counters,
     *  backup progress, etc.). */
    private fun isNoise(body: String): Boolean {
        val b = body.lowercase().trim()
        if (b.isEmpty()) return true
        if (b.contains("checking for new messages")) return true
        if (b.endsWith("new messages")) return true            // "5 new messages"
        if (b.endsWith("is typing…") || b.endsWith("is typing")) return true
        if (b == "typing…" || b == "typing") return true
        if (b.contains("backup") && b.contains("%")) return true
        return false
    }
}
