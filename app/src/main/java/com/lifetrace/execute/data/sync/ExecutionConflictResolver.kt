package com.lifetrace.execute.data.sync

import androidx.room.withTransaction
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.data.local.SyncOutboxEntity
import java.time.Instant
import java.util.UUID

/** Explicit conflict resolution shared by all registered execution entities. */
class ExecutionConflictResolver(
    private val database: LifeTraceExecuteDatabase,
    adapters: List<SyncEntityAdapter> = ExecutionSyncRegistry.create(database),
) {
    private val dao = database.dao()
    private val adapterByType = adapters.associateBy { it.entityType }

    suspend fun keepServer(conflictId: String) {
        database.withTransaction {
            val conflict = dao.getConflict(conflictId) ?: return@withTransaction
            val adapter = adapterByType[conflict.entityType]
                ?: error("未注册的冲突实体类型：${conflict.entityType}")

            dao.deleteOutboxForEntity(conflict.userId, conflict.entityType, conflict.entityId)
            if (conflict.serverDeleted) {
                adapter.applyRemoteDelete(conflict.userId, conflict.entityId)
            } else {
                adapter.applyRemoteUpsert(
                    userId = conflict.userId,
                    entityId = conflict.entityId,
                    payloadJson = requireNotNull(conflict.serverEntityJson) { "服务器冲突结果缺少实体内容" },
                    serverVersion = conflict.currentServerVersion,
                )
            }
            dao.deleteConflictsForEntity(conflict.userId, conflict.entityType, conflict.entityId)
        }
    }

    suspend fun keepLocal(conflictId: String, deviceId: String) {
        database.withTransaction {
            val conflict = dao.getConflict(conflictId) ?: return@withTransaction
            val adapter = adapterByType[conflict.entityType]
                ?: error("未注册的冲突实体类型：${conflict.entityType}")
            val conflictedChange = dao.firstOutboxForEntity(
                conflict.userId,
                conflict.entityType,
                conflict.entityId,
            ) ?: error("冲突缺少对应的本地待同步变更")

            dao.deleteOutboxForEntity(conflict.userId, conflict.entityType, conflict.entityId)

            when (conflictedChange.operation) {
                "upsert" -> {
                    val rebased = adapter.rebaseLocalConflict(
                        userId = conflict.userId,
                        entityId = conflict.entityId,
                        currentServerVersion = conflict.currentServerVersion,
                        deviceId = deviceId,
                    )
                    dao.insertOutbox(
                        SyncOutboxEntity(
                            changeId = UUID.randomUUID().toString(),
                            userId = conflict.userId,
                            entityType = conflict.entityType,
                            entityId = conflict.entityId,
                            operation = "upsert",
                            baseServerVersion = conflict.currentServerVersion,
                            entitySchemaVersion = adapter.schemaVersion,
                            clientModifiedAt = rebased.clientModifiedAt,
                            payloadJson = rebased.payloadJson,
                            atomicGroupId = null,
                            dependenciesJson = rebased.dependenciesJson,
                            createdAt = rebased.clientModifiedAt,
                        )
                    )
                }

                "delete" -> {
                    adapter.applyRemoteDelete(conflict.userId, conflict.entityId)
                    val now = Instant.now().toString()
                    dao.insertOutbox(
                        SyncOutboxEntity(
                            changeId = UUID.randomUUID().toString(),
                            userId = conflict.userId,
                            entityType = conflict.entityType,
                            entityId = conflict.entityId,
                            operation = "delete",
                            baseServerVersion = conflict.currentServerVersion,
                            entitySchemaVersion = adapter.schemaVersion,
                            clientModifiedAt = now,
                            payloadJson = null,
                            atomicGroupId = null,
                            dependenciesJson = "[]",
                            createdAt = now,
                        )
                    )
                }

                else -> error("不支持的冲突变更类型：${conflictedChange.operation}")
            }

            dao.deleteConflictsForEntity(conflict.userId, conflict.entityType, conflict.entityId)
        }
    }
}
