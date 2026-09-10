package com.lifetrace.execute.data.sync

import android.content.Context
import com.lifetrace.execute.core.cloud.CloudSessionManager
import com.lifetrace.execute.core.cloud.LifeTraceSyncClient
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase

/**
 * Compatibility facade retained for the existing TasksViewModel/Worker.
 * The implementation is now the shared multi-entity execution sync engine.
 */
class TaskSyncCoordinator(
    context: Context,
    database: LifeTraceExecuteDatabase = LifeTraceExecuteDatabase.get(context),
    sessionManager: CloudSessionManager = CloudSessionManager(context),
    syncClient: LifeTraceSyncClient = LifeTraceSyncClient(),
) {
    private val delegate = ExecutionSyncCoordinator(
        context = context,
        database = database,
        sessionManager = sessionManager,
        syncClient = syncClient,
        adapters = ExecutionSyncRegistry.create(database),
    )

    suspend fun syncNow(): TaskSyncSummary {
        val summary = delegate.syncNow()
        return TaskSyncSummary(
            snapshotItems = summary.snapshotItems,
            pushed = summary.pushed,
            pulled = summary.pulled,
            conflicts = summary.conflicts,
            rejected = summary.rejected,
        )
    }
}

data class TaskSyncSummary(
    val snapshotItems: Int,
    val pushed: Int,
    val pulled: Int,
    val conflicts: Int,
    val rejected: Int,
)
