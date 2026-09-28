import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openAssetDatabase() async {
  final directory = await getApplicationSupportDirectory();
  final path = p.join(directory.path, 'lifetrace_assets.db');
  return databaseFactoryIo.openDatabase(path);
}
