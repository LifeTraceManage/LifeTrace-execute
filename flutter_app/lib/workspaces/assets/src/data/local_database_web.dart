import 'package:sembast_web/sembast_web.dart';

Future<Database> openAssetDatabase() {
  return databaseFactoryWeb.openDatabase('lifetrace_assets.db');
}
