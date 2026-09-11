import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'app_database.g.dart';

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get status => text()();
  TextColumn get priority => text()();
  TextColumn get dueAt => text().nullable()();
  TextColumn get scheduledAt => text().nullable()();
  TextColumn get completedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get localVersion => integer()();
  TextColumn get serverVersion => text().nullable()();
  TextColumn get modifiedByDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()();
  TextColumn get startAt => text().nullable()();
  TextColumn get dueAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get localVersion => integer()();
  TextColumn get serverVersion => text().nullable()();
  TextColumn get modifiedByDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get startAt => text()();
  TextColumn get endAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get localVersion => integer()();
  TextColumn get serverVersion => text().nullable()();
  TextColumn get modifiedByDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Memos extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get kind => text()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get sourceUrl => text().nullable()();
  BoolColumn get important => boolean().withDefault(const Constant(false))();
  TextColumn get status => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get localVersion => integer()();
  TextColumn get serverVersion => text().nullable()();
  TextColumn get modifiedByDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class EntityLinks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text()();
  TextColumn get relationType => text()();
  TextColumn get metadataJson => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get localVersion => integer()();
  TextColumn get serverVersion => text().nullable()();
  TextColumn get modifiedByDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncOutbox extends Table {
  TextColumn get changeId => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get baseServerVersion => text()();
  IntColumn get entitySchemaVersion => integer().withDefault(const Constant(1))();
  TextColumn get clientModifiedAt => text()();
  TextColumn get payloadJson => text().nullable()();
  TextColumn get atomicGroupId => text().nullable()();
  TextColumn get dependenciesJson => text().withDefault(const Constant('[]'))();
  TextColumn get createdAt => text()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
  TextColumn get errorCode => text().nullable()();
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {changeId};
}

class SyncState extends Table {
  TextColumn get scope => text()();
  TextColumn get userId => text()();
  TextColumn get cursor => text().nullable()();
  TextColumn get updatedAt => text()();
  TextColumn get snapshotId => text().nullable()();
  TextColumn get snapshotPageToken => text().nullable()();
  TextColumn get snapshotCursor => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {scope, userId};
}

class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get changeId => text().withDefault(const Constant(''))();
  TextColumn get clientBaseServerVersion => text().withDefault(const Constant(''))();
  TextColumn get localPayloadJson => text().nullable()();
  TextColumn get serverPayloadJson => text().nullable()();
  TextColumn get serverVersion => text().nullable()();
  BoolColumn get serverDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Tasks, Projects, CalendarEvents, Memos, EntityLinks, SyncOutbox, SyncState, SyncConflicts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  AppDatabase.production() : super(openProductionConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(syncOutbox, syncOutbox.attemptCount);
            await migrator.addColumn(syncOutbox, syncOutbox.errorMessage);
            await migrator.addColumn(syncState, syncState.snapshotId);
            await migrator.addColumn(syncState, syncState.snapshotPageToken);
            await migrator.addColumn(syncState, syncState.snapshotCursor);
            await migrator.addColumn(syncConflicts, syncConflicts.changeId);
            await migrator.addColumn(
              syncConflicts,
              syncConflicts.clientBaseServerVersion,
            );
            await migrator.addColumn(syncConflicts, syncConflicts.serverDeleted);
            await migrator.addColumn(syncConflicts, syncConflicts.reason);
          }
          if (from < 3) {
            await migrator.createTable(projects);
          }
          if (from < 4) {
            await migrator.createTable(calendarEvents);
          }
          if (from < 5) {
            await migrator.createTable(memos);
            await migrator.createTable(entityLinks);
          }
        },
      );
}
