package com.lifetrace.execute.data.repository

import com.lifetrace.execute.domain.task.ExecutionTask
import com.lifetrace.execute.domain.task.ExecutionTaskPriority
import com.lifetrace.execute.domain.task.ExecutionTaskStatus
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class TaskWireMapperTest {
    @Test
    fun roundTripPreservesTaskFieldsAndUsesAcceptedServerVersion() {
        val task = ExecutionTask(
            id = "task-1",
            userId = "user-1",
            title = "Write tests",
            description = "Cover the production mapper",
            projectId = "project-1",
            status = ExecutionTaskStatus.IN_PROGRESS,
            priority = ExecutionTaskPriority.HIGH,
            dueAt = "2026-09-02T12:00:00Z",
            scheduledAt = "2026-09-01T10:00:00Z",
            completedAt = null,
            createdAt = "2026-09-01T08:00:00Z",
            updatedAt = "2026-09-01T09:00:00Z",
            localVersion = 4,
            serverVersion = "11",
            modifiedByDevice = "device-a",
        )

        val payload = TaskWireMapper.toPayload(task)
        val decoded = TaskWireMapper.fromPayload(payload, serverVersion = "12")

        assertEquals(task.copy(serverVersion = "12"), decoded)
        val root = JSONObject(payload)
        assertEquals("task-1", root.getJSONObject("meta").getString("id"))
        assertEquals("project-1", root.getString("projectId"))
    }

    @Test
    fun nullableFieldsSurviveRoundTrip() {
        val task = ExecutionTask(
            id = "task-2",
            userId = "user-1",
            title = "Offline task",
            createdAt = "2026-09-01T08:00:00Z",
            updatedAt = "2026-09-01T08:00:00Z",
            localVersion = 1,
        )

        val decoded = TaskWireMapper.fromPayload(
            TaskWireMapper.toPayload(task),
            serverVersion = "1",
        )

        assertNull(decoded.description)
        assertNull(decoded.projectId)
        assertNull(decoded.dueAt)
        assertNull(decoded.scheduledAt)
        assertNull(decoded.completedAt)
        assertEquals(ExecutionTaskStatus.TODO, decoded.status)
        assertEquals(ExecutionTaskPriority.NORMAL, decoded.priority)
    }
}
