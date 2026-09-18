package com.lifetrace.execute.data.repository

import androidx.room.withTransaction
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.data.local.SyncOutboxEntity
import com.lifetrace.execute.data.local.toDomain
import com.lifetrace.execute.data.local.toEntity
import com.lifetrace.execute.domain.project.ExecutionProject
import com.lifetrace.execute.domain.project.ExecutionProjectStatus
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.Instant
import java.util.UUID

class ProjectRepository(
    private val database: LifeTraceExecuteDatabase,
) {
    private val dao = database.dao()

    fun observeProjects(userId: String): Flow<List<ExecutionProject>> =
        dao.observeProjects(userId).map { rows -> rows.map { it.toDomain() } }

    suspend fun createProject(
        userId: String,
        deviceId: String,
        name: String,
        description: String? = null,
        dueAt: String? = null,
    ): ExecutionProject {
        require(name.isNotBlank()) { "项目名称不能为空" }
        val now = Instant.now().toString()
        val project = ExecutionProject(
            id = UUID.randomUUID().toString(),
            userId = userId,
            name = name.trim(),
            description = description?.trim()?.takeIf { it.isNotEmpty() },
            dueAt = dueAt,
            createdAt = now,
            updatedAt = now,
            localVersion = 1,
            modifiedByDevice = deviceId,
        )
        writeLocalChange(project)
        return project
    }

    suspend fun updateProject(
        project: ExecutionProject,
        deviceId: String,
        name: String = project.name,
        description: String? = project.description,
        status: ExecutionProjectStatus = project.status,
        dueAt: String? = project.dueAt,
    ): ExecutionProject {
        require(name.isNotBlank()) { "项目名称不能为空" }
        val updated = project.copy(
            name = name.trim(),
            description = description?.trim()?.takeIf { it.isNotEmpty() },
            status = status,
            dueAt = dueAt,
            updatedAt = Instant.now().toString(),
            localVersion = project.localVersion + 1,
            modifiedByDevice = deviceId,
        )
        writeLocalChange(updated)
        return updated
    }

    suspend fun deleteProject(userId: String, projectId: String) {
        val existing = dao.getProject(userId, projectId)?.toDomain() ?: return
        require(dao.countTasksForProject(userId, projectId) == 0) {
            "项目仍有关联任务，请先移动或清理这些任务"
        }
        val now = Instant.now().toString()
        database.withTransaction {
            dao.insertOutbox(
                SyncOutboxEntity(
                    changeId = UUID.randomUUID().toString(),
                    userId = userId,
                    entityType = ENTITY_TYPE,
                    entityId = projectId,
                    operation = "delete",
                    baseServerVersion = existing.serverVersion ?: "0",
                    entitySchemaVersion = 1,
                    clientModifiedAt = now,
                    payloadJson = null,
                    atomicGroupId = null,
                    dependenciesJson = "[]",
                    createdAt = now,
                )
            )
            dao.deleteProject(userId, projectId)
        }
    }

    private suspend fun writeLocalChange(project: ExecutionProject) {
        database.withTransaction {
            dao.upsertProject(project.toEntity())
            dao.insertOutbox(
                SyncOutboxEntity(
                    changeId = UUID.randomUUID().toString(),
                    userId = project.userId,
                    entityType = ENTITY_TYPE,
                    entityId = project.id,
                    operation = "upsert",
                    baseServerVersion = project.serverVersion ?: "0",
                    entitySchemaVersion = 1,
                    clientModifiedAt = project.updatedAt,
                    payloadJson = ProjectWireMapper.toPayload(project),
                    atomicGroupId = null,
                    dependenciesJson = "[]",
                    createdAt = project.updatedAt,
                )
            )
        }
    }

    companion object {
        const val ENTITY_TYPE = "execution.project"
    }
}
