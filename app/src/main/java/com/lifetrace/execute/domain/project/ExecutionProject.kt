package com.lifetrace.execute.domain.project

enum class ExecutionProjectStatus(val wireValue: String) {
    ACTIVE("active"),
    PAUSED("paused"),
    COMPLETED("completed"),
    ARCHIVED("archived");

    companion object {
        fun fromWire(value: String): ExecutionProjectStatus =
            entries.firstOrNull { it.wireValue == value } ?: ACTIVE
    }
}

data class ExecutionProject(
    val id: String,
    val userId: String,
    val name: String,
    val description: String? = null,
    val status: ExecutionProjectStatus = ExecutionProjectStatus.ACTIVE,
    val dueAt: String? = null,
    val createdAt: String,
    val updatedAt: String,
    val localVersion: Long,
    val serverVersion: String? = null,
    val modifiedByDevice: String? = null,
)

data class ProjectProgress(
    val project: ExecutionProject,
    val taskCount: Int,
    val completedTaskCount: Int,
) {
    val completionRatio: Float
        get() = if (taskCount == 0) 0f else completedTaskCount.toFloat() / taskCount.toFloat()
}
