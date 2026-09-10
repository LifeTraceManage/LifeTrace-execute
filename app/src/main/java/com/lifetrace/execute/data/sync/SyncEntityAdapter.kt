package com.lifetrace.execute.data.sync

/**
 * Bridges the generic Sync v1 engine to one local Room/domain implementation.
 *
 * Entity-specific wire parsing and persistence live behind this interface so
 * push/pull/snapshot/conflict orchestration is implemented exactly once.
 */
interface SyncEntityAdapter {
    val entityType: String
    val schemaVersion: Int get() = 1
    val priority: Int get() = 100

    suspend fun applyRemoteUpsert(
        userId: String,
        entityId: String,
        payloadJson: String,
        serverVersion: String,
    )

    suspend fun applyRemoteDelete(userId: String, entityId: String)

    suspend fun updateServerVersion(
        userId: String,
        entityId: String,
        serverVersion: String,
    )

    /** Returns a full local snapshot rewritten onto [serverVersion]. */
    suspend fun payloadForRebase(
        userId: String,
        entityId: String,
        serverVersion: String,
    ): String?

    /**
     * Mutates the local record for an explicit "keep local" conflict choice and
     * returns the full snapshot that must be queued against the latest server version.
     */
    suspend fun rebaseLocalConflict(
        userId: String,
        entityId: String,
        currentServerVersion: String,
        deviceId: String,
    ): RebasedLocalEntity
}

data class RebasedLocalEntity(
    val payloadJson: String,
    val clientModifiedAt: String,
    val dependenciesJson: String = "[]",
)
