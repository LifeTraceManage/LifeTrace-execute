package com.lifetrace.execute.data.sync

import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase

/** Compatibility facade for the task ViewModel; conflict semantics are generic. */
class TaskConflictResolver(
    database: LifeTraceExecuteDatabase,
) {
    private val delegate = ExecutionConflictResolver(database)

    suspend fun keepServer(conflictId: String) = delegate.keepServer(conflictId)

    suspend fun keepLocal(conflictId: String, deviceId: String) =
        delegate.keepLocal(conflictId, deviceId)
}
