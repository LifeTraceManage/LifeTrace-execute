import 'package:drift/drift.dart';

QueryExecutor openProductionConnection() {
  throw UnsupportedError(
    'Persistent SQLite is not initialized for the Web preview. '
    'The browser preview uses an in-memory TaskRepository instead.',
  );
}
