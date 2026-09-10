package com.lifetrace.execute.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.lifetrace.execute.domain.project.ExecutionProject
import com.lifetrace.execute.domain.project.ExecutionProjectStatus

@Entity(
    tableName = "projects",
    indices = [
        Index(value = ["userId", "updatedAt"]),
        Index(value = ["userId", "status"]),
    ],
)
data class ProjectEntity(
    @PrimaryKey val id: String,
    val userId: String,
    val name: String,
    val description: String?,
    val status: String,
    val dueAt: String?,
    val createdAt: String,
    val updatedAt: String,
    val localVersion: Long,
    val serverVersion: String?,
    val modifiedByDevice: String?,
)

fun ProjectEntity.toDomain(): ExecutionProject = ExecutionProject(
    id = id,
    userId = userId,
    name = name,
    description = description,
    status = ExecutionProjectStatus.fromWire(status),
    dueAt = dueAt,
    createdAt = createdAt,
    updatedAt = updatedAt,
    localVersion = localVersion,
    serverVersion = serverVersion,
    modifiedByDevice = modifiedByDevice,
)

fun ExecutionProject.toEntity(): ProjectEntity = ProjectEntity(
    id = id,
    userId = userId,
    name = name,
    description = description,
    status = status.wireValue,
    dueAt = dueAt,
    createdAt = createdAt,
    updatedAt = updatedAt,
    localVersion = localVersion,
    serverVersion = serverVersion,
    modifiedByDevice = modifiedByDevice,
)
