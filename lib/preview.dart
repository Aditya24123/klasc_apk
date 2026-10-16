// Local browser preview. Android/iOS continue to use main.dart and native SQLite.
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'main.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await ItemStore.open(
    factory: databaseFactoryFfiWebNoWebWorker,
    path: 'klasc-preview.db',
  );
  runApp(KlascApp(store: store));
}
