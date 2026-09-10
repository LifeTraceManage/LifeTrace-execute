package com.lifetrace.execute.data.repository

import com.lifetrace.execute.domain.project.ExecutionProject
import com.lifetrace.execute.domain.project.ExecutionProjectStatus
import org.junit.Assert.assertEquals
import org.junit.Test

class ProjectWireMapperTest {
    @Test
    fun roundTripPreservesProjectFields() {
        val source = ExecutionProject(
            id = "project-1",
            userId = "user-1",
            name = "Release",
            description = "Complete all gates",
            status = ExecutionProjectStatus.PAUSED,
            dueAt = "2026-10-01T00:00:00Z",
            createdAt = "2026-09-01T00:00:00Z",
            updatedAt = "2026-09-01T01:00:00Z",
            localVersion = 3,
            serverVersion = "7",
            modifiedByDevice = "device-a",
        )

        val decoded = ProjectWireMapper.fromPayload(ProjectWireMapper.toPayload(source), "8")

        assertEquals(source.copy(serverVersion = "8"), decoded)
    }
}
