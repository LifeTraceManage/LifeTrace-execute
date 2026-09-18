package com.lifetrace.execute.data.sync

import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase

object ExecutionSyncRegistry {
    fun create(database: LifeTraceExecuteDatabase): List<SyncEntityAdapter> =
        listOf(
            ProjectSyncEntityAdapter(database),
            TaskSyncEntityAdapter(database),
        ).sortedWith(compareBy<SyncEntityAdapter> { it.priority }.thenBy { it.entityType })
}
