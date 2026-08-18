package com.app.vigil.child.app

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.ListenableWorker
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

/**
 * FEATURE A — event-driven expedited upload.
 *
 * The instant a native capture service writes a NEW line to the social queue,
 * it asks WorkManager to run an *expedited* one-shot job. That job boots a
 * short-lived Dart isolate (via the flutter_workmanager `BackgroundWorker`) and
 * drains + POSTs the queue immediately — instead of waiting for the polling
 * background isolate, which the OS freezes in Doze.
 *
 * Why this reaches the server in seconds even in Doze:
 *  - Expedited jobs are granted a foreground execution window by the OS, so they
 *    run while the app is backgrounded / dozing.
 *  - It is a fresh isolate spun by the OS, independent of the (frozen or
 *    leader-contended) long-running background isolate.
 *
 * Safety / batching:
 *  - `enqueueUniqueWork(KEEP)` coalesces a burst of captures into a single
 *    pending job (WhatsApp writing 10 lines does not enqueue 10 jobs).
 *  - `OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST` falls back to a normal
 *    job once the expedited quota (Android 12+) is spent, so it always runs —
 *    just slightly later. The 15-second polling drain remains the final safety
 *    net if the enqueue ever fails.
 *  - Never throws: capture must never crash the host app (WhatsApp/IG/…).
 */
object ExpeditedUpload {
    private const val TAG = "VigilExpedite"

    /** Single coalescing key — one pending expedited drain at a time. */
    private const val UNIQUE_WORK = "vigil-expedited-social-upload"

    /** MUST match the task-name branch in Dart's WorkManager callback dispatcher
     *  (`work_manager_service.dart`). */
    private const val DART_TASK = "vigilExpeditedSocialUpload"

    /** flutter_workmanager reads the Dart task name from this input-data key
     *  (see `BackgroundWorker.DART_TASK_KEY`). The Dart callback handle itself is
     *  read from SharedPreferences, persisted when `Workmanager().initialize()`
     *  ran in `main()`, so a natively-enqueued job resolves the same dispatcher. */
    private const val DART_TASK_KEY = "dev.fluttercommunity.workmanager.DART_TASK"

    private const val WORKER_CLASS = "dev.fluttercommunity.workmanager.BackgroundWorker"

    fun trigger(context: Context) {
        try {
            @Suppress("UNCHECKED_CAST")
            val workerClass = Class.forName(WORKER_CLASS) as Class<out ListenableWorker>

            val request = OneTimeWorkRequest.Builder(workerClass)
                .setInputData(Data.Builder().putString(DART_TASK_KEY, DART_TASK).build())
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .setBackoffCriteria(BackoffPolicy.LINEAR, 10, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_WORK,
                ExistingWorkPolicy.KEEP,
                request,
            )
            Log.d(TAG, "ENQUEUED expedited upload job ($DART_TASK) — Dart isolate will drain + POST")
        } catch (t: Throwable) {
            // The polling isolate is the fallback if this ever fails.
            Log.w(TAG, "expedited enqueue failed", t)
        }
    }
}
