package com.example.vigil1

import android.content.Context
import org.json.JSONObject
import java.io.File
import java.util.ArrayDeque

/**
 * Append-only JSONL queue shared between the native capture services (writers)
 * and the Flutter background isolate (reader / drainer).
 *
 * Why a file: a [NotificationListenerService] / [AccessibilityService] runs as a
 * plain Android component with no Flutter engine, and the Dart code that ships
 * the data lives in a *separate* background isolate. A line-delimited file under
 * the app's private `filesDir` is the one channel both sides can reach, and it
 * survives the app being killed.
 *
 * - One JSON object per line (`\n`-terminated).
 * - Writes are guarded by [lock] and de-duplicated by a small in-memory ring so
 *   the same message isn't appended twice when a service re-fires.
 * - The Dart side drains by *atomic rename* (see `SocialQueueFile.drain`), so a
 *   write that lands here after a drain simply goes into the fresh file and is
 *   picked up on the next pass.
 */
object SocialQueueWriter {
    private const val DIR = "vigil_social"

    /** Trim the file once it grows past this, so a backend outage can't let it
     *  balloon unbounded. Oldest lines are dropped first. */
    private const val MAX_BYTES = 2_000_000L

    /** How many recent message fingerprints to remember per file for de-dup. */
    private const val DEDUP_CAPACITY = 400

    private val lock = Any()
    private val recentOrder = HashMap<String, ArrayDeque<Int>>()
    private val recentSet = HashMap<String, HashSet<Int>>()

    /** `<filesDir>/vigil_social/` — created on first use. Mirrors the Dart side's
     *  `getApplicationSupportDirectory()/vigil_social`. */
    fun dir(context: Context): File {
        val d = File(context.filesDir, DIR)
        if (!d.exists()) d.mkdirs()
        return d
    }

    /**
     * Append [obj] to [fileName] unless [dedupKey] was seen recently.
     * Never throws — capture must never crash the host app.
     */
    fun append(context: Context, fileName: String, obj: JSONObject, dedupKey: String) {
        synchronized(lock) {
            try {
                val h = dedupKey.hashCode()
                val seen = recentSet.getOrPut(fileName) { HashSet() }
                if (!seen.add(h)) return
                val order = recentOrder.getOrPut(fileName) { ArrayDeque() }
                order.addLast(h)
                if (order.size > DEDUP_CAPACITY) seen.remove(order.removeFirst())

                val file = File(dir(context), fileName)
                if (file.exists() && file.length() > MAX_BYTES) trimHalf(file)
                file.appendText(obj.toString() + "\n")
            } catch (_: Throwable) {
                // Swallow: a full disk / IO error must not take down WhatsApp etc.
            }
        }
    }

    /** Keep only the newest half of the lines when the file gets too big. */
    private fun trimHalf(file: File) {
        try {
            val lines = file.readLines()
            if (lines.size <= 2) return
            val keep = lines.subList(lines.size / 2, lines.size)
            file.writeText(keep.joinToString("\n", postfix = "\n"))
        } catch (_: Throwable) {
        }
    }
}
