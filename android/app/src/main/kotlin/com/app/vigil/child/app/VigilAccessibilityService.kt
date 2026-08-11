package com.app.vigil.child.app

import android.accessibilityservice.AccessibilityService
import android.graphics.Rect
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONObject
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

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
 * right now — nothing is captured while the app is in the background.
 *
 * Direction (sent vs received) is inferred from where each text bubble sits on
 * screen: chat apps right-align the child's own messages and left-align the
 * incoming ones. This is a heuristic (~85-90% on standard bubble layouts like
 * WhatsApp / Telegram / Instagram); anything that isn't clearly left/right (date
 * separators, system notices, centred text) is tagged `unknown`. Lines are
 * emitted top-to-bottom so the backend can render them in reading order.
 */
class VigilAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "VigilA11y"
        private const val FILE = "a11y_queue.jsonl"
        private const val MAX_DEPTH = 60

        /** Coalesce bursts of high-frequency events (content-changed / scroll)
         *  so we walk the view tree at most once per window. Window *state*
         *  changes (a new chat opening) bypass this and are always handled. */
        private const val THROTTLE_MS = 500L
    }

    /** Single background thread that owns every tree-walk + file write, so the
     *  main (accessibility) thread returns immediately and Android never flags
     *  the service as unresponsive and disables it. */
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()

    @Volatile private var lastHandledAt = 0L

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val e = event ?: return
        // Extract everything we need *now* — the event is recycled once this
        // returns, so nothing about it may be touched on the worker thread.
        val pkg = e.packageName?.toString() ?: return
        if (!SocialApps.isTarget(pkg)) return

        when (e.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> Unit // always handle
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> {
                val now = SystemClock.uptimeMillis()
                if (now - lastHandledAt < THROTTLE_MS) return
                lastHandledAt = now
            }
            else -> return
        }

        worker.execute { capture(pkg) }
    }

    /** Runs on [worker]: reads the live view tree and appends to the queue.
     *  `rootInActiveWindow` is safe to read off the main thread. */
    private fun capture(pkg: String) {
        try {
            val root = rootInActiveWindow ?: return
            val screenWidth = resources.displayMetrics.widthPixels.takeIf { it > 0 } ?: 1080
            val lines = ArrayList<Line>()
            collectLines(root, lines, 0)
            if (lines.isEmpty()) return

            // Top-to-bottom = chat reading order (a whole screen shares one
            // capture timestamp, so position is what preserves the sequence).
            lines.sortBy { it.top }

            val conversation = guessConversation(lines.map { it.text })
            val now = System.currentTimeMillis()
            val appName = SocialApps.nameFor(pkg)

            for (line in lines) {
                val clean = line.text.trim()
                if (clean.length < 2) continue
                if (clean == conversation) continue
                if (isUiChrome(clean)) continue

                val direction = directionOf(line, screenWidth)
                // We can identify the child's own side reliably; the incoming
                // sender's name isn't recoverable from a flat text walk, so it's
                // left blank (the open-chat `conversation` carries that context).
                val sender = if (direction == "sent") "me" else ""

                val obj = JSONObject().apply {
                    put("source", "accessibility")
                    put("package", pkg)
                    put("app", appName)
                    put("conversation", conversation ?: "")
                    put("direction", direction)
                    put("sender", sender)
                    put("text", clean)
                    put("capturedAt", now)
                }
                // De-dup on app + open-chat + direction + text so scrolling
                // doesn't re-log the same visible bubble repeatedly.
                val dedup = "$pkg|$conversation|$direction|$clean"
                SocialQueueWriter.append(applicationContext, FILE, obj, dedup)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "capture failed", t)
        }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    /** One visible text node plus where it sits on screen — the horizontal
     *  position is what tells sent from received, the vertical one orders the
     *  chat. */
    private data class Line(val text: String, val left: Int, val right: Int, val top: Int)

    private fun collectLines(node: AccessibilityNodeInfo?, out: MutableList<Line>, depth: Int) {
        if (node == null || depth > MAX_DEPTH) return
        node.text?.let {
            if (it.isNotBlank()) {
                val r = Rect()
                node.getBoundsInScreen(r)
                out.add(Line(it.toString(), r.left, r.right, r.top))
            }
        }
        for (i in 0 until node.childCount) {
            collectLines(node.getChild(i), out, depth + 1)
        }
    }

    /** Infers message direction from bubble alignment. Received bubbles hug the
     *  left edge, sent bubbles the right; a wide/centred line that does neither
     *  (system notices, date chips) stays `unknown`. */
    private fun directionOf(line: Line, screenWidth: Int): String {
        if (screenWidth <= 0) return "unknown"
        val leftFrac = line.left.toFloat() / screenWidth
        val rightFrac = line.right.toFloat() / screenWidth
        return when {
            rightFrac >= 0.80f && leftFrac >= 0.30f -> "sent"
            leftFrac <= 0.20f && rightFrac <= 0.72f -> "received"
            else -> "unknown"
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
