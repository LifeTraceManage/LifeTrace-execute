package com.lifetrace.execute.data.repository

import android.app.Application
import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.domain.project.ExecutionProjectStatus
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class ProjectRepositoryTest {
    private lateinit var database: LifeTraceExecuteDatabase
    private lateinit var projects: ProjectRepository
    private lateinit var tasks: TaskRepository

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, LifeTraceExecuteDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        projects = ProjectRepository(database)
        tasks = TaskRepository(database)
    }

    @After
    fun tearDown() = database.close()

    @Test
    fun createAndUpdateAreLocalFirstAndQueueOutbox() = runBlocking {
        val project = projects.createProject(
            userId = "user-1",
            deviceId = "device-a",
            name = "  Execute 1.0  ",
            description = "  ship full product  ",
        )
        assertEquals("Execute 1.0", project.name)
        assertNotNull(database.dao().getProject("user-1", project.id))
        assertEquals(1, database.dao().observePendingOutboxCount("user-1").first())

        val updated = projects.updateProject(
            project = project,
            deviceId = "device-b",
            status = ExecutionProjectStatus.PAUSED,
        )
        assertEquals(2, updated.localVersion)
        assertEquals("paused", database.dao().getProject("user-1", project.id)!!.status)
        assertEquals(2, database.dao().observePendingOutboxCount("user-1").first())
    }

    @Test
    fun deletingProjectWithLinkedTaskIsRejected() = runBlocking {
        val project = projects.createProject("user-1", "device-a", "Project")
        tasks.createTask(
            userId = "user-1",
            deviceId = "device-a",
            title = "Linked task",
            projectId = project.id,
        )

        assertThrows(IllegalArgumentException::class.java) {
            runBlocking { projects.deleteProject("user-1", project.id) }
        }
        assertNotNull(database.dao().getProject("user-1", project.id))
    }

    @Test
    fun unreferencedProjectDeleteCreatesTombstoneIntent() = runBlocking {
        val project = projects.createProject("user-1", "device-a", "Disposable")
        projects.deleteProject("user-1", project.id)

        assertNull(database.dao().getProject("user-1", project.id))
        assertEquals(2, database.dao().observePendingOutboxCount("user-1").first())
    }
}
