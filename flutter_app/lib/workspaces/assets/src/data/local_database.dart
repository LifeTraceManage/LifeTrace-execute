import 'package:sembast/sembast.dart';

import 'local_database_stub.dart'
    if (dart.library.io) 'local_database_io.dart'
    if (dart.library.js_interop) 'local_database_web.dart' as platform;

Future<Database> openAssetDatabase() => platform.openAssetDatabase();
