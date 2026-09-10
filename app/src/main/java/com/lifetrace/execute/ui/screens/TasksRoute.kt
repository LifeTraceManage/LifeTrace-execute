package com.lifetrace.execute.ui.screens

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lifetrace.execute.presentation.tasks.TasksViewModel
import com.lifetrace.execute.ui.components.TaskConflictResolutionSheet

/**
 * Production route for the task feature.
 *
 * TasksScreen remains focused on task CRUD while this route owns route-level task
 * sync concerns. A newly observed conflict is surfaced immediately and can be
 * explicitly resolved without silently overwriting either side.
 */
@Composable
fun TasksRoute(
    contentPadding: PaddingValues,
    onProfile: () -> Unit,
    onCloudConnection: () -> Unit,
    viewModel: TasksViewModel = viewModel(),
) {
    val state by viewModel.state.collectAsState()
    var showConflicts by rememberSaveable { mutableStateOf(false) }
    var lastConflictSignature by rememberSaveable { mutableStateOf("") }

    val conflictSignature = state.conflicts
        .joinToString(separator = "|") { it.conflictId }

    LaunchedEffect(conflictSignature) {
        if (conflictSignature.isNotBlank() && conflictSignature != lastConflictSignature) {
            lastConflictSignature = conflictSignature
            showConflicts = true
        }
        if (conflictSignature.isBlank()) {
            lastConflictSignature = ""
            showConflicts = false
        }
    }

    TasksScreen(
        contentPadding = contentPadding,
        onProfile = onProfile,
        onCloudConnection = onCloudConnection,
        viewModel = viewModel,
    )

    if (showConflicts && state.conflicts.isNotEmpty()) {
        TaskConflictResolutionSheet(
            conflicts = state.conflicts,
            resolvingConflictId = state.resolvingConflictId,
            onDismiss = { showConflicts = false },
            onKeepServer = viewModel::keepServer,
            onKeepLocal = viewModel::keepLocal,
        )
    }
}
