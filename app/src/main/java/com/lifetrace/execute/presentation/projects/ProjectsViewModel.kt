package com.lifetrace.execute.presentation.projects

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.lifetrace.execute.core.cloud.DeviceIdentityStore
import com.lifetrace.execute.core.cloud.SecureSessionStore
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.data.repository.ProjectRepository
import com.lifetrace.execute.data.repository.TaskRepository
import com.lifetrace.execute.data.sync.ExecutionConflictResolver
import com.lifetrace.execute.data.sync.ExecutionSyncCoordinator
import com.lifetrace.execute.data.sync.SyncScheduler
import com.lifetrace.execute.domain.project.ExecutionProject
import com.lifetrace.execute.domain.project.ExecutionProjectStatus
import com.lifetrace.execute.domain.project.ProjectProgress
import com.lifetrace.execute.domain.task.ExecutionTaskStatus
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import org.json.JSONObject

data class ProjectConflictUi(
    val conflictId: String,
    val projectId: String,
    val localName: String?,
    val serverName: String?,
    val serverDeleted: Boolean,
    val reason: String,
)

data class ProjectsUiState(
    val connected: Boolean = false,
    val projects: List<ProjectProgress> = emptyList(),
    val loading: Boolean = true,
    val syncing: Boolean = false,
    val conflicts: List<ProjectConflictUi> = emptyList(),
    val resolvingConflictId: String? = null,
    val message: String? = null,
    val error: String? = null,
)

class ProjectsViewModel(application: Application) : AndroidViewModel(application) {
    private val context = application.applicationContext
    private val database = LifeTraceExecuteDatabase.get(application)
    private val dao = database.dao()
    private val projectRepository = ProjectRepository(database)
    private val taskRepository = TaskRepository(database)
    private val sessionStore = SecureSessionStore(application)
    private val deviceStore = DeviceIdentityStore(application)
    private val syncCoordinator = ExecutionSyncCoordinator(application, database = database)
    private val conflictResolver = ExecutionConflictResolver(database)

    private val _state = MutableStateFlow(ProjectsUiState())
    val state: StateFlow<ProjectsUiState> = _state.asStateFlow()

    private var activeUserId: String? = null
    private var observeJob: Job? = null

    init {
        refreshSession()
    }

    fun refreshSession() {
        val userId = sessionStore.load()?.userId
        if (userId == activeUserId && !_state.value.loading) return
        activeUserId = userId
        observeJob?.cancel()

        if (userId == null) {
            _state.value = ProjectsUiState(connected = false, loading = false)
            return
        }

        _state.value = _state.value.copy(connected = true, loading = true)
        observeJob = viewModelScope.launch {
            combine(
                projectRepository.observeProjects(userId),
                taskRepository.observeTasks(userId),
                dao.observeConflicts(userId),
            ) { projects, tasks, conflicts ->
                val progress = projects.map { project ->
                    val projectTasks = tasks.filter { it.projectId == project.id }
                    ProjectProgress(
                        project = project,
                        taskCount = projectTasks.size,
                        completedTaskCount = projectTasks.count { it.status == ExecutionTaskStatus.DONE },
                    )
                }
                val projectConflicts = conflicts
                    .filter { it.entityType == ProjectRepository.ENTITY_TYPE }
                    .map { conflict ->
                        ProjectConflictUi(
                            conflictId = conflict.conflictId,
                            projectId = conflict.entityId,
                            localName = projects.firstOrNull { it.id == conflict.entityId }?.name,
                            serverName = conflict.serverEntityJson?.let { payload ->
                                runCatching { JSONObject(payload).optString("name").takeIf(String::isNotBlank) }.getOrNull()
                            },
                            serverDeleted = conflict.serverDeleted,
                            reason = conflict.reason,
                        )
                    }
                progress to projectConflicts
            }.collect { (projects, conflicts) ->
                _state.value = _state.value.copy(
                    connected = true,
                    projects = projects,
                    conflicts = conflicts,
                    loading = false,
                )
            }
        }
    }

    fun createProject(name: String, description: String?, dueAt: String?) {
        val userId = activeUserId ?: return setError("请先连接 LifeTrace Cloud")
        viewModelScope.launch {
            runCatching {
                projectRepository.createProject(
                    userId = userId,
                    deviceId = deviceStore.deviceId(),
                    name = name,
                    description = description,
                    dueAt = dueAt,
                )
            }.onSuccess {
                SyncScheduler.enqueueAfterLocalChange(context)
                setMessage("项目已保存到本地，并进入同步队列")
            }.onFailure { setError(it.message ?: "创建项目失败") }
        }
    }

    fun updateProject(
        project: ExecutionProject,
        name: String,
        description: String?,
        status: ExecutionProjectStatus,
        dueAt: String?,
    ) {
        viewModelScope.launch {
            runCatching {
                projectRepository.updateProject(
                    project = project,
                    deviceId = deviceStore.deviceId(),
                    name = name,
                    description = description,
                    status = status,
                    dueAt = dueAt,
                )
            }.onSuccess {
                SyncScheduler.enqueueAfterLocalChange(context)
                setMessage("项目修改已保存")
            }.onFailure { setError(it.message ?: "保存项目失败") }
        }
    }

    fun deleteProject(project: ExecutionProject) {
        val userId = activeUserId ?: return
        viewModelScope.launch {
            runCatching { projectRepository.deleteProject(userId, project.id) }
                .onSuccess {
                    SyncScheduler.enqueueAfterLocalChange(context)
                    setMessage("项目已删除")
                }
                .onFailure { setError(it.message ?: "删除项目失败") }
        }
    }

    fun syncNow() {
        if (_state.value.syncing || activeUserId == null) return
        viewModelScope.launch {
            _state.value = _state.value.copy(syncing = true, message = null, error = null)
            runCatching { syncCoordinator.syncNow() }
                .onSuccess { summary ->
                    _state.value = _state.value.copy(
                        syncing = false,
                        message = "同步完成 · 上传 ${summary.pushed} · 下载 ${summary.pulled}",
                    )
                }
                .onFailure {
                    _state.value = _state.value.copy(syncing = false, error = it.message ?: "同步失败")
                }
        }
    }

    fun keepServer(conflictId: String) = resolve(conflictId) {
        conflictResolver.keepServer(conflictId)
        "已接受云端项目版本"
    }

    fun keepLocal(conflictId: String) = resolve(conflictId) {
        conflictResolver.keepLocal(conflictId, deviceStore.deviceId())
        SyncScheduler.enqueueAfterLocalChange(context)
        "已保留本地项目版本并重新排队同步"
    }

    private fun resolve(conflictId: String, block: suspend () -> String) {
        if (_state.value.resolvingConflictId != null) return
        viewModelScope.launch {
            _state.value = _state.value.copy(resolvingConflictId = conflictId, message = null, error = null)
            runCatching { block() }
                .onSuccess { _state.value = _state.value.copy(resolvingConflictId = null, message = it) }
                .onFailure { _state.value = _state.value.copy(resolvingConflictId = null, error = it.message ?: "处理冲突失败") }
        }
    }

    fun clearFeedback() {
        _state.value = _state.value.copy(message = null, error = null)
    }

    private fun setMessage(message: String) {
        _state.value = _state.value.copy(message = message, error = null)
    }

    private fun setError(message: String) {
        _state.value = _state.value.copy(error = message, message = null)
    }
}
