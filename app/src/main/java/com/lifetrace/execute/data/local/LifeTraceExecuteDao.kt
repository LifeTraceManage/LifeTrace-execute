package com.lifetrace.execute.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface LifeTraceExecuteDao {
    @Query("SELECT * FROM tasks WHERE userId = :userId ORDER BY completedAt IS NOT NULL, dueAt IS NULL, dueAt, updatedAt DESC")
    fun observeTasks(userId: String): Flow<List<TaskEntity>>

    @Query("SELECT * FROM tasks WHERE id = :taskId AND userId = :userId LIMIT 1")
    suspend fun getTask(userId: String, taskId: String): TaskEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertTask(task: TaskEntity)

    @Query("DELETE FROM tasks WHERE id = :taskId AND userId = :userId")
    suspend fun deleteTask(userId: String, taskId: String)

    @Query("UPDATE tasks SET serverVersion = :serverVersion WHERE id = :taskId AND userId = :userId")
    suspend fun updateTaskServerVersion(userId: String, taskId: String, serverVersion: String)

    @Query("SELECT COUNT(*) FROM tasks WHERE userId = :userId AND projectId = :projectId")
    suspend fun countTasksForProject(userId: String, projectId: String): Int

    @Query("SELECT * FROM projects WHERE userId = :userId ORDER BY status, dueAt IS NULL, dueAt, updatedAt DESC")
    fun observeProjects(userId: String): Flow<List<ProjectEntity>>

    @Query("SELECT * FROM projects WHERE id = :projectId AND userId = :userId LIMIT 1")
    suspend fun getProject(userId: String, projectId: String): ProjectEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertProject(project: ProjectEntity)

    @Query("DELETE FROM projects WHERE id = :projectId AND userId = :userId")
    suspend fun deleteProject(userId: String, projectId: String)

    @Query("UPDATE projects SET serverVersion = :serverVersion WHERE id = :projectId AND userId = :userId")
    suspend fun updateProjectServerVersion(userId: String, projectId: String, serverVersion: String)

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertOutbox(change: SyncOutboxEntity)

    @Query(
        """
        SELECT o.* FROM sync_outbox o
        WHERE o.userId = :userId
          AND o.entityType = :entityType
          AND o.blocked = 0
          AND NOT EXISTS (
            SELECT 1 FROM sync_outbox older
            WHERE older.userId = o.userId
              AND older.entityType = o.entityType
              AND older.entityId = o.entityId
              AND (
                older.createdAt < o.createdAt OR
                (older.createdAt = o.createdAt AND older.changeId < o.changeId)
              )
          )
        ORDER BY o.createdAt, o.changeId
        LIMIT :limit
        """
    )
    suspend fun pendingOutboxHeads(userId: String, entityType: String, limit: Int): List<SyncOutboxEntity>

    @Query(
        "SELECT * FROM sync_outbox WHERE userId = :userId AND entityType = :entityType AND entityId = :entityId ORDER BY createdAt, changeId LIMIT 1"
    )
    suspend fun firstOutboxForEntity(userId: String, entityType: String, entityId: String): SyncOutboxEntity?

    @Query("SELECT COUNT(*) FROM sync_outbox WHERE userId = :userId AND blocked = 0")
    fun observePendingOutboxCount(userId: String): Flow<Int>

    @Query("SELECT COUNT(*) FROM sync_outbox WHERE userId = :userId AND blocked = 1")
    fun observeBlockedOutboxCount(userId: String): Flow<Int>

    @Query("DELETE FROM sync_outbox WHERE changeId = :changeId")
    suspend fun deleteOutbox(changeId: String)

    @Query(
        "DELETE FROM sync_outbox WHERE userId = :userId AND entityType = :entityType AND entityId = :entityId"
    )
    suspend fun deleteOutboxForEntity(userId: String, entityType: String, entityId: String)

    @Query(
        "UPDATE sync_outbox SET attemptCount = attemptCount + 1, lastErrorCode = NULL, lastErrorMessage = NULL WHERE changeId = :changeId"
    )
    suspend fun markOutboxAttempted(changeId: String)

    @Query(
        "UPDATE sync_outbox SET lastErrorCode = :code, lastErrorMessage = :message WHERE changeId = :changeId"
    )
    suspend fun markOutboxRetryableFailure(changeId: String, code: String?, message: String?)

    @Query(
        "UPDATE sync_outbox SET blocked = 1, lastErrorCode = :code, lastErrorMessage = :message WHERE changeId = :changeId"
    )
    suspend fun blockOutbox(changeId: String, code: String?, message: String?)

    @Query(
        "UPDATE sync_outbox SET blocked = 1, lastErrorCode = :code, lastErrorMessage = :message WHERE userId = :userId AND entityType = :entityType AND entityId = :entityId"
    )
    suspend fun blockOutboxForEntity(
        userId: String,
        entityType: String,
        entityId: String,
        code: String?,
        message: String?,
    )

    @Query(
        "UPDATE sync_outbox SET baseServerVersion = :baseServerVersion, payloadJson = :payloadJson WHERE changeId = :changeId AND attemptCount = 0"
    )
    suspend fun rebaseUnattemptedOutbox(
        changeId: String,
        baseServerVersion: String,
        payloadJson: String?,
    )

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertSyncState(state: SyncStateEntity)

    @Query("SELECT * FROM sync_state WHERE userId = :userId AND scopeKey = :scopeKey LIMIT 1")
    suspend fun getSyncState(userId: String, scopeKey: String): SyncStateEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertConflict(conflict: SyncConflictEntity)

    @Query("SELECT * FROM sync_conflicts WHERE userId = :userId ORDER BY createdAt DESC")
    fun observeConflicts(userId: String): Flow<List<SyncConflictEntity>>

    @Query("SELECT * FROM sync_conflicts WHERE conflictId = :conflictId LIMIT 1")
    suspend fun getConflict(conflictId: String): SyncConflictEntity?

    @Query("DELETE FROM sync_conflicts WHERE conflictId = :conflictId")
    suspend fun deleteConflict(conflictId: String)

    @Query(
        "DELETE FROM sync_conflicts WHERE userId = :userId AND entityType = :entityType AND entityId = :entityId"
    )
    suspend fun deleteConflictsForEntity(userId: String, entityType: String, entityId: String)
}
