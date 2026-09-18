package com.lifetrace.execute.data.repository

import android.app.Application
import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.domain.task.ExecutionTaskPriority
import com.lifetrace.execute.domain.task.ExecutionTaskStatus
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class TaskRepositoryTest {
    private lateinit var database: LifeTraceExecuteDatabase
    private lateinit var repository: TaskRepository

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(
            context,
            LifeTraceExecuteDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = TaskRepository(database)
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun createPersistsEntityAndOutboxTogether() = runBlocking {
        val task = repository.createTask(
            userId = "user-1",
            deviceId = "device-a",
            title = "  Local first task  ",
            description = "  persists before network  ",
            projectId = "project-1",
            priority = ExecutionTaskPriority.HIGH,
            dueAt = "2026-09-02T12:00:00Z",
        )

        val stored = database.dao().getTask("user-1", task.id)
        val outbox = database.dao().firstOutboxForEntity(
            "user-1",
            TaskRepository.ENTITY_TYPE,
            task.id,
        )

        assertNotNull(stored)
        assertEquals("Local first task", stored!!.title)
        assertEquals("persists before network", stored.description)
        assertEquals("project-1", stored.projectId)
        assertNotNull(outbox)
        assertEquals("upsert", outbox!!.operation)
        assertEquals("0", outbox.baseServerVersion)
        assertTrue(outbox.dependenciesJson.contains("project-1"))
        assertEquals(1, database.dao().observePendingOutboxCount("user-1").first())
    }

    @Test
    fun updateIncrementsLocalVersionAndQueuesAnotherChange() = runBlocking {
        val original = repository.createTask(
            userId = "user-1",
            deviceId = "device-a",
            title = "Original",
        )

        val updated = repository.updateTask(
            task = original,
            deviceId = "device-b",
            title = "Updated",
            status = ExecutionTaskStatus.DONE,
            priority = ExecutionTaskPriority.URGENT,
        )

        val stored = database.dao().getTask("user-1", original.id)
        assertEquals(2, updated.localVersion)
        assertEquals(2, stored!!.localVersion)
        assertEquals("done", stored.status)
        assertEquals("urgent", stored.priority)
        assertNotNull(stored.completedAt)
        assertEquals("device-b", stored.modifiedByDevice)
        assertEquals(2, database.dao().observePendingOutboxCount("user-1").first())
    }

    @Test
    fun deleteRemovesVisibleEntityButKeepsDeleteIntentInOutbox() = runBlocking {
        val task = repository.createTask(
            userId = "user-1",
            deviceId = "device-a",
            title = "Delete me",
        )

        repository.deleteTask("user-1", task.id)

        assertNull(database.dao().getTask("user-1", task.id))
        assertEquals(2, database.dao().observePendingOutboxCount("user-1").first())
    }

    @Test
    fun blankTitleIsRejectedBeforeAnyDatabaseWrite() {
        assertThrows(IllegalArgumentException::class.java) {
            runBlocking {
                repository.createTask(
                    userId = "user-1",
                    deviceId = "device-a",
                    title = "   ",
                )
            }
        }
    }
}
