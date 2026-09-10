package com.lifetrace.execute.presentation.tasks

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.lifetrace.execute.core.cloud.DeviceIdentityStore
import com.lifetrace.execute.core.cloud.SecureSessionStore
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.data.local.SyncConflictEntity
import com.lifetrace.execute.data.repository.ProjectRepository
import com.lifetrace.execute.data.repository.TaskRepository
import com.lifetrace.execute.data.sync.SyncScheduler
import com.lifetrace.execute.data.sync.TaskConflictResolver
import com.lifetrace.execute.data.sync.TaskSyncCoordinator
import com.lifetrace.execute.domain.project.ExecutionProject
import com.lifetrace.execute.domain.task.ExecutionTask
import com.lifetrace.execute.domain.task.ExecutionTaskPriority
import com.lifetrace.execute.domain.task.ExecutionTaskStatus
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import org.json.JSONObject

data class TaskConflictUi(
    val conflictId: String,
    val taskId: String,
    val localTitle: String?,
    val serverTitle: String?,
    val serverDeleted: Boolean,
    val reason: String,
)

data class TasksUiState(
    val connected: Boolean = false,
    val tasks: List<ExecutionTask> = emptyList(),
    val projects: List<ExecutionProject> = emptyList(),
    val loading: Boolean = true,
    val syncing: Boolean = false,
    val pendingSyncCount: Int = 0,
    val blockedSyncCount: Int = 0,
    val conflictCount: Int = 0,
    val conflicts: List<TaskConflictUi> = emptyList(),
    val resolvingConflictId: String? = null,
    val message: String? = null,
    val error: String? = null,
)

private data class TaskObservation(
    val tasks: List<ExecutionTask>,
    val projects: List<ExecutionProject>,
    val pendingSyncCount: Int,
    val blockedSyncCount: Int,
    val conflicts: List<TaskConflictUi>,
)

class TasksViewModel(application: Application) : AndroidViewModel(application) {
    private val appContext = application.applicationContext
    private val database = LifeTraceExecuteDatabase.get(application)
    private val dao = database.dao()
    private val repository = TaskRepository(database)
    private val projectRepository = ProjectRepository(database)
    private val sessionStore = SecureSessionStore(application)
    private val deviceIdentityStore = DeviceIdentityStore(application)
    private val syncCoordinator = TaskSyncCoordinator(application, database = database)
    private val conflictResolver = TaskConflictResolver(database)

    private val _state = MutableStateFlow(TasksUiState())
    val state: StateFlow<TasksUiState> = _state.asStateFlow()

    private var observeJob: Job? = null
    private var activeUserId: String? = null

    init {
        refreshSession()
    }

    fun refreshSession() {
        val session = sessionStore.load()
        val userId = session?.userId
        if (userId == activeUserId && _state.value.loading.not()) return

        activeUserId = userId
        observeJob?.cancel()

        if (userId == null) {
            _state.value = TasksUiState(
                connected = false,
                tasks = emptyList(),
                projects = emptyList(),
                loading = false,
            )
            return
        }

        _state.value = _state.value.copy(
            connected = true,
            loading = true,
            error = null,
        )
        observeJob = viewModelScope.launch {
            combine(
                repository.observeTasks(userId),
                projectRepository.observeProjects(userId),
                dao.observePendingOutboxCount(userId),
                dao.observeBlockedOutboxCount(userId),
                dao.observeConflicts(userId),
            ) { tasks, projects, pending, blocked, conflicts ->
                val taskConflicts = conflicts
                    .filter { it.entityType == TaskRepository.ENTITY_TYPE }
                    .map { it.toUi(tasks) }
                TaskObservation(
                    tasks = tasks,
                    projects = projects,
                    pendingSyncCount = pending,
                    blockedSyncCount = blocked,
                    conflicts = taskConflicts,
                )
            }.collect { observation ->
                _state.value = _state.value.copy(
                    connected = true,
                    tasks = observation.tasks,
                    projects = observation.projects,
                    pendingSyncCount = observation.pendingSyncCount,
                    blockedSyncCount = observation.blockedSyncCount,
                    conflictCount = observation.conflicts.size,
                    conflicts = observation.conflicts,
                    loading = false,
                )
            }
        }
    }

    fun createTask(
        title: String,
        description: String?,
        projectId: String?,
        priority: ExecutionTaskPriority,
        dueAt: String?,
        scheduledAt: String?,
    ) {
        val userId = activeUserId ?: run {
            _state.value = _state.value.copy(error = "请先连接 LifeTrace Cloud")
            return
        }
        viewModelScope.launch {
            try {
                repository.createTask(
                    userId = userId,
                    deviceId = deviceIdentityStore.deviceId(),
                    title = title,
                    description = description,
                    projectId = projectId,
                    priority = priority,
                    dueAt = dueAt,
                    scheduledAt = scheduledAt,
                )
                SyncScheduler.enqueueAfterLocalChange(appContext)
                _state.value = _state.value.copy(
                    message = "任务已保存到本地，并进入待同步队列",
                    error = null,
                )
            } catch (error: Throwable) {
                _state.value = _state.value.copy(error = error.message ?: "新建任务失败")
            }
        }
    }

    fun updateTask(
        task: ExecutionTask,
        title: String,
        description: String?,
        projectId: String?,
        status: ExecutionTaskStatus,
        priority: ExecutionTaskPriority,
        dueAt: String?,
        scheduledAt: String?,
    ) {
        viewModelScope.launch {
            try {
                repository.updateTask(
                    task = task,
                    deviceId = deviceIdentityStore.deviceId(),
                    title = title,
                    description = description,
                    projectId = projectId,
                    status = status,
                    priority = priority,
                    dueAt = dueAt,
                    scheduledAt = scheduledAt,
                )
                SyncScheduler.enqueueAfterLocalChange(appContext)
                _state.value = _state.value.copy(
                    message = "任务修改已保存到本地，并进入待同步队列",
                    error = null,
                )
            } catch (error: Throwable) {
                _state.value = _state.value.copy(error = error.message ?: "保存任务失败")
            }
        }
    }

    fun toggleCompleted(task: ExecutionTask) {
        viewModelScope.launch {
            try {
                repository.updateTask(
                    task = task,
                    deviceId = deviceIdentityStore.deviceId(),
                    status = if (task.status == ExecutionTaskStatus.DONE) {
                        ExecutionTaskStatus.TODO
                    } else {
                        ExecutionTaskStatus.DONE
                    },
                )
                SyncScheduler.enqueueAfterLocalChange(appContext)
                _state.value = _state.value.copy(
                    message = if (task.status == ExecutionTaskStatus.DONE) "任务已恢复" else "任务已完成",
                    error = null,
                )
            } catch (error: Throwable) {
                _state.value = _state.value.copy(error = error.message ?: "更新任务失败")
            }
        }
    }

    fun deleteTask(task: ExecutionTask) {
        val userId = activeUserId ?: return
        viewModelScope.launch {
            try {
                repository.deleteTask(userId, task.id)
                SyncScheduler.enqueueAfterLocalChange(appContext)
                _state.value = _state.value.copy(message = "任务已删除，并进入待同步队列", error = null)
            } catch (error: Throwable) {
                _state.value = _state.value.copy(error = error.message ?: "删除任务失败")
            }
        }
    }

    fun keepServer(conflictId: String) {
        if (_state.value.resolvingConflictId != null) return
        viewModelScope.launch {
            _state.value = _state.value.copy(
                resolvingConflictId = conflictId,
                message = null,
                error = null,
            )
            try {
                conflictResolver.keepServer(conflictId)
                _state.value = _state.value.copy(
                    resolvingConflictId = null,
                    message = "已接受云端版本，相关本地冲突队列已清理",
                )
            } catch (error: Throwable) {
                _state.value = _state.value.copy(
                    resolvingConflictId = null,
                    error = error.message ?: "接受云端版本失败",
                )
            }
        }
    }

    fun keepLocal(conflictId: String) {
        if (_state.value.resolvingConflictId != null) return
        viewModelScope.launch {
            _state.value = _state.value.copy(
                resolvingConflictId = conflictId,
                message = null,
                error = null,
            )
            try {
                conflictResolver.keepLocal(
                    conflictId = conflictId,
                    deviceId = deviceIdentityStore.deviceId(),
                )
                SyncScheduler.enqueueAfterLocalChange(appContext)
                _state.value = _state.value.copy(
                    resolvingConflictId = null,
                    message = "已保留本地版本，并基于最新云端版本重新排队同步",
                )
            } catch (error: Throwable) {
                _state.value = _state.value.copy(
                    resolvingConflictId = null,
                    error = error.message ?: "保留本地版本失败",
                )
            }
        }
    }

    fun syncNow() {
        if (!_state.value.connected || _state.value.syncing) return
        viewModelScope.launch {
            _state.value = _state.value.copy(syncing = true, message = null, error = null)
            try {
                val summary = syncCoordinator.syncNow()
                _state.value = _state.value.copy(
                    syncing = false,
                    message = buildString {
                        append("同步完成")
                        if (summary.snapshotItems > 0) append(" · 恢复 ${summary.snapshotItems}")
                        if (summary.pushed > 0) append(" · 上传 ${summary.pushed}")
                        if (summary.pulled > 0) append(" · 下载 ${summary.pulled}")
                        if (summary.conflicts > 0) append(" · 冲突 ${summary.conflicts}")
                        if (summary.rejected > 0) append(" · 拒绝 ${summary.rejected}")
                    },
                )
            } catch (error: Throwable) {
                _state.value = _state.value.copy(
                    syncing = false,
                    error = error.message ?: "同步失败，本地任务不会丢失",
                )
            }
        }
    }

    fun clearFeedback() {
        if (_state.value.message != null || _state.value.error != null) {
            _state.value = _state.value.copy(message = null, error = null)
        }
    }
}

private fun SyncConflictEntity.toUi(tasks: List<ExecutionTask>): TaskConflictUi {
    val localTitle = tasks.firstOrNull { it.id == entityId }?.title
    val serverTitle = if (serverDeleted) {
        null
    } else {
        serverEntityJson?.let { payload ->
            runCatching {
                JSONObject(payload).optString("title").takeIf { it.isNotBlank() }
            }.getOrNull()
        }
    }
    return TaskConflictUi(
        conflictId = conflictId,
        taskId = entityId,
        localTitle = localTitle,
        serverTitle = serverTitle,
        serverDeleted = serverDeleted,
        reason = reason,
    )
}
