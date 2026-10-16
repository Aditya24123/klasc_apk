import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'store.dart';

Future<ItemStore> openLocalStore() => ItemStore.open(
    factory: databaseFactoryFfiWebNoWebWorker, path: 'klasc-preview.db');
