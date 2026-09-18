package com.lifetrace.execute.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [
        TaskEntity::class,
        ProjectEntity::class,
        SyncOutboxEntity::class,
        SyncStateEntity::class,
        SyncConflictEntity::class,
    ],
    version = 2,
    exportSchema = true,
)
abstract class LifeTraceExecuteDatabase : RoomDatabase() {
    abstract fun dao(): LifeTraceExecuteDao

    companion object {
        @Volatile
        private var instance: LifeTraceExecuteDatabase? = null

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `projects` (
                        `id` TEXT NOT NULL,
                        `userId` TEXT NOT NULL,
                        `name` TEXT NOT NULL,
                        `description` TEXT,
                        `status` TEXT NOT NULL,
                        `dueAt` TEXT,
                        `createdAt` TEXT NOT NULL,
                        `updatedAt` TEXT NOT NULL,
                        `localVersion` INTEGER NOT NULL,
                        `serverVersion` TEXT,
                        `modifiedByDevice` TEXT,
                        PRIMARY KEY(`id`)
                    )
                    """.trimIndent()
                )
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_projects_userId_updatedAt` ON `projects` (`userId`, `updatedAt`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_projects_userId_status` ON `projects` (`userId`, `status`)")
            }
        }

        fun get(context: Context): LifeTraceExecuteDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    LifeTraceExecuteDatabase::class.java,
                    "lifetrace-execute.db",
                )
                    .addMigrations(MIGRATION_1_2)
                    .build()
                    .also { instance = it }
            }
    }
}
