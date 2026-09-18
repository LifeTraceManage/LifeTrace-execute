package com.lifetrace.execute.data.sync

import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.data.local.toDomain
import com.lifetrace.execute.data.local.toEntity
import com.lifetrace.execute.data.repository.ProjectRepository
import com.lifetrace.execute.data.repository.ProjectWireMapper
import java.time.Instant

class ProjectSyncEntityAdapter(
    private val database: LifeTraceExecuteDatabase,
) : SyncEntityAdapter {
    private val dao = database.dao()

    override val entityType: String = ProjectRepository.ENTITY_TYPE
    override val priority: Int = 10

    override suspend fun applyRemoteUpsert(
        userId: String,
        entityId: String,
        payloadJson: String,
        serverVersion: String,
    ) {
        val project = ProjectWireMapper.fromPayload(payloadJson, serverVersion)
        require(project.userId == userId) { "项目 payload 用户不匹配" }
        require(project.id == entityId) { "项目 payload id 不匹配" }
        dao.upsertProject(project.toEntity())
    }

    override suspend fun applyRemoteDelete(userId: String, entityId: String) {
        dao.deleteProject(userId, entityId)
    }

    override suspend fun updateServerVersion(userId: String, entityId: String, serverVersion: String) {
        dao.updateProjectServerVersion(userId, entityId, serverVersion)
    }

    override suspend fun payloadForRebase(
        userId: String,
        entityId: String,
        serverVersion: String,
    ): String? = dao.getProject(userId, entityId)
        ?.toDomain()
        ?.copy(serverVersion = serverVersion)
        ?.let(ProjectWireMapper::toPayload)

    override suspend fun rebaseLocalConflict(
        userId: String,
        entityId: String,
        currentServerVersion: String,
        deviceId: String,
    ): RebasedLocalEntity {
        val current = dao.getProject(userId, entityId)?.toDomain()
            ?: error("本地项目已不存在，无法保留本地版本")
        val now = Instant.now().toString()
        val rebased = current.copy(
            updatedAt = now,
            localVersion = current.localVersion + 1,
            serverVersion = currentServerVersion,
            modifiedByDevice = deviceId,
        )
        dao.upsertProject(rebased.toEntity())
        return RebasedLocalEntity(
            payloadJson = ProjectWireMapper.toPayload(rebased),
            clientModifiedAt = now,
        )
    }
}
