package com.lifetrace.execute.ui.screens

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material.icons.outlined.Sync
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lifetrace.execute.domain.project.ExecutionProject
import com.lifetrace.execute.domain.project.ExecutionProjectStatus
import com.lifetrace.execute.domain.project.ProjectProgress
import com.lifetrace.execute.presentation.projects.ProjectConflictUi
import com.lifetrace.execute.presentation.projects.ProjectsUiState
import com.lifetrace.execute.presentation.projects.ProjectsViewModel
import com.lifetrace.execute.ui.components.DateTimePickerField
import com.lifetrace.execute.ui.components.ScreenHeader
import com.lifetrace.execute.ui.theme.LifeBorder
import com.lifetrace.execute.ui.theme.LifeMuted
import com.lifetrace.execute.ui.theme.LifeSurface
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun ProjectsScreen(
    contentPadding: PaddingValues,
    onProfile: () -> Unit,
    onCloudConnection: () -> Unit = {},
    viewModel: ProjectsViewModel = viewModel(),
) {
    val state by viewModel.state.collectAsState()
    var filter by rememberSaveable { mutableStateOf("全部") }
    var showNew by rememberSaveable { mutableStateOf(false) }
    var editing by remember { mutableStateOf<ExecutionProject?>(null) }
    var showConflicts by rememberSaveable { mutableStateOf(false) }
    var conflictSignature by rememberSaveable { mutableStateOf("") }

    LaunchedEffect(Unit) { viewModel.refreshSession() }
    val currentSignature = state.conflicts.joinToString("|") { it.conflictId }
    LaunchedEffect(currentSignature) {
        if (currentSignature.isNotBlank() && currentSignature != conflictSignature) {
            conflictSignature = currentSignature
            showConflicts = true
        }
        if (currentSignature.isBlank()) {
            conflictSignature = ""
            showConflicts = false
        }
    }

    val visible = remember(state.projects, filter) {
        state.projects.filter { item ->
            when (filter) {
                "进行中" -> item.project.status == ExecutionProjectStatus.ACTIVE
                "已暂停" -> item.project.status == ExecutionProjectStatus.PAUSED
                "已完成" -> item.project.status == ExecutionProjectStatus.COMPLETED
                "已归档" -> item.project.status == ExecutionProjectStatus.ARCHIVED
                else -> true
            }
        }
    }

    Scaffold(
        modifier = Modifier
            .fillMaxSize()
            .padding(bottom = contentPadding.calculateBottomPadding()),
        containerColor = MaterialTheme.colorScheme.surface,
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { if (state.connected) showNew = true else onCloudConnection() },
                icon = { Icon(Icons.Outlined.Add, contentDescription = null) },
                text = { Text(if (state.connected) "新建项目" else "连接 Cloud") },
            )
        },
    ) { scaffoldPadding ->
        LazyColumn(
            contentPadding = PaddingValues(
                start = 16.dp,
                end = 16.dp,
                top = contentPadding.calculateTopPadding() + scaffoldPadding.calculateTopPadding() + 18.dp,
                bottom = scaffoldPadding.calculateBottomPadding() + 96.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                ScreenHeader("项目", "真实任务进度 · 本地优先", onProfile)
                Spacer(Modifier.height(14.dp))
                if (!state.connected) {
                    ProjectCloudRequiredCard(onCloudConnection)
                    Spacer(Modifier.height(14.dp))
                } else {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "${state.projects.size} 个项目",
                            modifier = Modifier.weight(1f),
                            style = MaterialTheme.typography.titleMedium,
                        )
                        OutlinedButton(onClick = viewModel::syncNow, enabled = !state.syncing) {
                            if (state.syncing) {
                                CircularProgressIndicator(strokeWidth = 2.dp, modifier = Modifier.height(18.dp))
                            } else {
                                Icon(Icons.Outlined.Sync, contentDescription = null)
                            }
                            Text(if (state.syncing) " 同步中" else " 同步")
                        }
                    }
                    if (state.conflicts.isNotEmpty()) {
                        Spacer(Modifier.height(8.dp))
                        Button(onClick = { showConflicts = true }, modifier = Modifier.fillMaxWidth()) {
                            Text("处理 ${state.conflicts.size} 个项目冲突")
                        }
                    }
                    Spacer(Modifier.height(12.dp))
                }

                state.message?.let {
                    AssistChip(onClick = viewModel::clearFeedback, label = { Text(it) })
                    Spacer(Modifier.height(8.dp))
                }
                state.error?.let {
                    Card(
                        modifier = Modifier.fillMaxWidth().clickable(onClick = viewModel::clearFeedback),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                    ) {
                        Text(it, modifier = Modifier.padding(14.dp), color = MaterialTheme.colorScheme.onErrorContainer)
                    }
                    Spacer(Modifier.height(8.dp))
                }

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("全部", "进行中", "已暂停", "已完成", "已归档").forEach { label ->
                        FilterChip(
                            selected = filter == label,
                            onClick = { filter = label },
                            label = { Text(label) },
                        )
                    }
                }
            }

            if (state.loading) {
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(32.dp),
                        horizontalArrangement = Arrangement.Center,
                    ) { CircularProgressIndicator() }
                }
            } else if (state.connected && visible.isEmpty()) {
                item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = LifeSurface),
                        border = BorderStroke(1.dp, LifeBorder),
                    ) {
                        Column(
                            modifier = Modifier.padding(20.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Text("没有项目", style = MaterialTheme.typography.titleMedium)
                            Text("创建项目后，可在任务中归属项目并自动汇总完成进度。", color = LifeMuted)
                        }
                    }
                }
            } else {
                items(visible, key = { it.project.id }) { item ->
                    RealProjectCard(
                        progress = item,
                        onOpen = { editing = item.project },
                        onDelete = { viewModel.deleteProject(item.project) },
                    )
                }
            }
        }
    }

    if (showNew) {
        ProjectEditorSheet(
            project = null,
            onDismiss = { showNew = false },
            onSave = { name, description, _, dueAt ->
                viewModel.createProject(name, description, dueAt)
                showNew = false
            },
        )
    }

    editing?.let { project ->
        ProjectEditorSheet(
            project = project,
            onDismiss = { editing = null },
            onSave = { name, description, status, dueAt ->
                viewModel.updateProject(project, name, description, status, dueAt)
                editing = null
            },
        )
    }

    if (showConflicts && state.conflicts.isNotEmpty()) {
        ProjectConflictSheet(
            conflicts = state.conflicts,
            resolvingId = state.resolvingConflictId,
            onDismiss = { showConflicts = false },
            onKeepServer = viewModel::keepServer,
            onKeepLocal = viewModel::keepLocal,
        )
    }
}

@Composable
private fun RealProjectCard(
    progress: ProjectProgress,
    onOpen: () -> Unit,
    onDelete: () -> Unit,
) {
    val project = progress.project
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen),
        colors = CardDefaults.cardColors(containerColor = LifeSurface),
        border = BorderStroke(1.dp, LifeBorder),
        shape = RoundedCornerShape(18.dp),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    Text(project.name, style = MaterialTheme.typography.titleMedium)
                    project.description?.let { Text(it, color = LifeMuted, style = MaterialTheme.typography.bodyMedium) }
                }
                IconButton(onClick = onDelete) {
                    Icon(Icons.Outlined.DeleteOutline, contentDescription = "删除项目", tint = LifeMuted)
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AssistChip(onClick = {}, label = { Text(project.status.label()) })
                Text(
                    "${progress.completedTaskCount}/${progress.taskCount} 任务",
                    color = LifeMuted,
                    style = MaterialTheme.typography.labelLarge,
                    modifier = Modifier.align(Alignment.CenterVertically),
                )
            }
            LinearProgressIndicator(
                progress = { progress.completionRatio.coerceIn(0f, 1f) },
                modifier = Modifier.fillMaxWidth(),
            )
            project.dueAt?.let {
                Text("截止 ${formatProjectDate(it)}", color = LifeMuted, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun ProjectEditorSheet(
    project: ExecutionProject?,
    onDismiss: () -> Unit,
    onSave: (String, String?, ExecutionProjectStatus, String?) -> Unit,
) {
    var name by remember(project?.id) { mutableStateOf(project?.name.orEmpty()) }
    var description by remember(project?.id) { mutableStateOf(project?.description.orEmpty()) }
    var status by remember(project?.id) { mutableStateOf(project?.status ?: ExecutionProjectStatus.ACTIVE) }
    var dueAt by remember(project?.id) { mutableStateOf(project?.dueAt) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Text(if (project == null) "新建项目" else "编辑项目", style = MaterialTheme.typography.headlineSmall)
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("项目名称") },
                singleLine = true,
            )
            OutlinedTextField(
                value = description,
                onValueChange = { description = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("描述") },
                minLines = 2,
                maxLines = 5,
            )
            if (project != null) {
                Text("状态", style = MaterialTheme.typography.labelLarge)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    ExecutionProjectStatus.entries.forEach { option ->
                        FilterChip(
                            selected = option == status,
                            onClick = { status = option },
                            label = { Text(option.label()) },
                        )
                    }
                }
            }
            DateTimePickerField(label = "截止时间", value = dueAt, onValueChange = { dueAt = it })
            Button(
                onClick = {
                    onSave(name.trim(), description.trim().takeIf { it.isNotEmpty() }, status, dueAt)
                },
                enabled = name.isNotBlank(),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("保存到本地") }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun ProjectConflictSheet(
    conflicts: List<ProjectConflictUi>,
    resolvingId: String?,
    onDismiss: () -> Unit,
    onKeepServer: (String) -> Unit,
    onKeepLocal: (String) -> Unit,
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        LazyColumn(
            contentPadding = PaddingValues(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Text("处理项目同步冲突", style = MaterialTheme.typography.headlineSmall)
                Text("不会自动最后写入覆盖，请明确选择保留哪一侧。", color = LifeMuted)
            }
            items(conflicts, key = { it.conflictId }) { conflict ->
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(conflict.localName ?: conflict.serverName ?: "项目 ${conflict.projectId.take(8)}")
                        Text("本地：${conflict.localName ?: "已删除"}")
                        Text("云端：${if (conflict.serverDeleted) "已删除" else conflict.serverName ?: "项目"}")
                        Text(conflict.reason, style = MaterialTheme.typography.bodySmall)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(
                                onClick = { onKeepServer(conflict.conflictId) },
                                enabled = resolvingId == null,
                                modifier = Modifier.weight(1f),
                            ) { Text("接受云端") }
                            Button(
                                onClick = { onKeepLocal(conflict.conflictId) },
                                enabled = resolvingId == null,
                                modifier = Modifier.weight(1f),
                            ) { Text("保留本地") }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProjectCloudRequiredCard(onConnect: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("连接 LifeTrace Cloud", style = MaterialTheme.typography.titleMedium)
            Text("项目按用户隔离；连接后写入仍然是本地优先。", color = LifeMuted)
            Button(onClick = onConnect) { Text("前往连接") }
        }
    }
}

private fun ExecutionProjectStatus.label(): String = when (this) {
    ExecutionProjectStatus.ACTIVE -> "进行中"
    ExecutionProjectStatus.PAUSED -> "已暂停"
    ExecutionProjectStatus.COMPLETED -> "已完成"
    ExecutionProjectStatus.ARCHIVED -> "已归档"
}

private fun formatProjectDate(value: String): String = runCatching {
    DateTimeFormatter.ofPattern("yyyy/M/d HH:mm")
        .withZone(ZoneId.systemDefault())
        .format(Instant.parse(value))
}.getOrDefault(value)
