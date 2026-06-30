package com.example.vigil1

import android.accessibilityservice.AccessibilityService
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject

/**
 * FEATURE B — On-screen capture.
 *
 * Once the child enables Vigil under Settings → Accessibility, Android streams
 * UI events from the target apps (restricted via `android:packageNames` in
 * `res/xml/accessibility_service_config.xml`). For each event we walk the live
 * view tree and pull every visible text node, then write the lines to the shared
 * JSONL queue.
 *
 * Coverage: the FULL text currently rendered on screen (no 100-char limit),
 * including the open chat's contact/group name. Limit: only what's on screen
 * right now — nothing is captured while the app is in the background, and we
 * can't reliably tell sent vs received.
 */
class VigilAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "VigilA11y"
        private const val FILE = "a11y_queue.jsonl"
        private const val MAX_DEPTH = 60
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        try {
            val e = event ?: return
            val pkg = e.packageName?.toString() ?: return
            if (!SocialApps.isTarget(pkg)) return

            when (e.eventType) {
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
                AccessibilityEvent.TYPE_VIEW_SCROLLED -> Unit
                else -> return
            }

            val root = rootInActiveWindow ?: return
            val texts = ArrayList<String>()
            collectText(root, texts, 0)
            if (texts.isEmpty()) return

            val conversation = guessConversation(texts)
            val now = System.currentTimeMillis()
            val appName = SocialApps.nameFor(pkg)

            for (raw in texts) {
                val clean = raw.trim()
                if (clean.length < 2) continue
                if (clean == conversation) continue
                if (isUiChrome(clean)) continue

                val obj = JSONObject().apply {
                    put("source", "accessibility")
                    put("package", pkg)
                    put("app", appName)
                    put("conversation", conversation ?: "")
                    put("text", clean)
                    put("capturedAt", now)
                }
                // De-dup on app + open-chat + text so scrolling doesn't re-log the
                // same visible bubble repeatedly.
                val dedup = "$pkg|$conversation|$clean"
                SocialQueueWriter.append(applicationContext, FILE, obj, dedup)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "capture failed", t)
        }
    }

    private fun collectText(node: AccessibilityNodeInfo?, out: MutableList<String>, depth: Int) {
        if (node == null || depth > MAX_DEPTH) return
        node.text?.let { if (it.isNotBlank()) out.add(it.toString()) }
        for (i in 0 until node.childCount) {
            collectText(node.getChild(i), out, depth + 1)
        }
    }

    /** Best-effort guess of the open chat's name: the first short, non-chrome
     *  line (usually the toolbar title). */
    private fun guessConversation(texts: List<String>): String? {
        for (t in texts) {
            val c = t.trim()
            if (c.length in 1..40 && !c.contains('\n') && !isUiChrome(c)) return c
        }
        return null
    }

    private fun isUiChrome(s: String): Boolean = s.lowercase().trim() in CHROME

    override fun onInterrupt() { /* no-op */ }

    private val CHROME = setOf(
        "type a message", "type a message…", "message", "search", "online",
        "typing…", "typing", "tap here for contact info", "tap for more info",
        "voice call", "video call", "camera", "attach", "emoji", "send", "back",
        "today", "yesterday"
    )
}
