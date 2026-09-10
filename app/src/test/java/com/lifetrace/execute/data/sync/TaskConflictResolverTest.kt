package com.lifetrace.execute.data.sync

import android.app.Application
import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.lifetrace.execute.data.local.LifeTraceExecuteDatabase
import com.lifetrace.execute.data.local.SyncConflictEntity
import com.lifetrace.execute.data.local.SyncOutboxEntity
import com.lifetrace.execute.data.local.toEntity
import com.lifetrace.execute.data.repository.TaskRepository
import com.lifetrace.execute.data.repository.TaskWireMapper
import com.lifetrace.execute.domain.task.ExecutionTask
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], application = Application::class)
class TaskConflictResolverTest {
    private lateinit var database: LifeTraceExecuteDatabase
    private lateinit var resolver: TaskConflictResolver

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(
            context,
            LifeTraceExecuteDatabase::class.java,
        ).allowMainThreadQueries().build()
        resolver = TaskConflictResolver(database)
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun keepServerReplacesLocalDraftAndClearsBlockedQueue() = runBlocking {
        val local = task(title = "Local title", serverVersion = "3")
        val server = local.copy(
            title = "Server title",
            serverVersion = "4",
            updatedAt = "2026-09-01T09:30:00Z",
        )
        seedConflict(local, server, conflictId = "conflict-server", changeId = "change-server")

        resolver.keepServer("conflict-server")

        val stored = database.dao().getTask(USER_ID, TASK_ID)
        assertEquals("Server title", stored!!.title)
        assertEquals("4", stored.serverVersion)
        assertNull(database.dao().firstOutboxForEntity(USER_ID, TaskRepository.ENTITY_TYPE, TASK_ID))
        assertEquals(0, database.dao().observeConflicts(USER_ID).first().size)
    }

    @Test
    fun keepLocalRebasesDraftOnLatestServerVersionAndGeneratesFreshChangeId() = runBlocking {
        val local = task(title = "Keep this local", serverVersion = "3")
        val server = local.copy(title = "Server changed", serverVersion = "4")
        seedConflict(local, server, conflictId = "conflict-local", changeId = "old-change")

        resolver.keepLocal("conflict-local", deviceId = "device-resolver")

        val stored = database.dao().getTask(USER_ID, TASK_ID)!!
        val rebased = database.dao().firstOutboxForEntity(
            USER_ID,
            TaskRepository.ENTITY_TYPE,
            TASK_ID,
        )!!

        assertEquals("Keep this local", stored.title)
        assertEquals("4", stored.serverVersion)
        assertEquals(2, stored.localVersion)
        assertEquals("device-resolver", stored.modifiedByDevice)
        assertEquals("4", rebased.baseServerVersion)
        assertEquals("upsert", rebased.operation)
        assertNotEquals("old-change", rebased.changeId)
        assertEquals("Keep this local", TaskWireMapper.fromPayload(rebased.payloadJson!!, "4").title)
        assertEquals(0, database.dao().observeConflicts(USER_ID).first().size)
    }

    @Test
    fun keepServerHonorsServerTombstone() = runBlocking {
        val local = task(title = "Deleted on cloud", serverVersion = "3")
        seedConflict(
            local = local,
            server = null,
            conflictId = "conflict-delete",
            changeId = "change-delete",
            serverDeleted = true,
        )

        resolver.keepServer("conflict-delete")

        assertNull(database.dao().getTask(USER_ID, TASK_ID))
        assertNull(database.dao().firstOutboxForEntity(USER_ID, TaskRepository.ENTITY_TYPE, TASK_ID))
    }

    private suspend fun seedConflict(
        local: ExecutionTask,
        server: ExecutionTask?,
        conflictId: String,
        changeId: String,
        serverDeleted: Boolean = false,
    ) {
        val dao = database.dao()
        dao.upsertTask(local.toEntity())
        dao.insertOutbox(
            SyncOutboxEntity(
                changeId = changeId,
                userId = USER_ID,
                entityType = TaskRepository.ENTITY_TYPE,
                entityId = TASK_ID,
                operation = "upsert",
                baseServerVersion = "3",
                entitySchemaVersion = 1,
                clientModifiedAt = local.updatedAt,
                payloadJson = TaskWireMapper.toPayload(local),
                atomicGroupId = null,
                dependenciesJson = "[]",
                attemptCount = 1,
                blocked = true,
                lastErrorCode = "SYNC_CONFLICT",
                lastErrorMessage = "base_version_mismatch",
                createdAt = local.updatedAt,
            )
        )
        dao.upsertConflict(
            SyncConflictEntity(
                conflictId = conflictId,
                userId = USER_ID,
                changeId = changeId,
                entityType = TaskRepository.ENTITY_TYPE,
                entityId = TASK_ID,
                clientBaseServerVersion = "3",
                currentServerVersion = "4",
                serverEntityJson = server?.let(TaskWireMapper::toPayload),
                serverDeleted = serverDeleted,
                reason = "base_version_mismatch",
                createdAt = "2026-09-01T10:00:00Z",
            )
        )
    }

    private fun task(title: String, serverVersion: String) = ExecutionTask(
        id = TASK_ID,
        userId = USER_ID,
        title = title,
        createdAt = "2026-09-01T08:00:00Z",
        updatedAt = "2026-09-01T09:00:00Z",
        localVersion = 1,
        serverVersion = serverVersion,
        modifiedByDevice = "device-a",
    )

    companion object {
        private const val USER_ID = "user-1"
        private const val TASK_ID = "task-1"
    }
}
