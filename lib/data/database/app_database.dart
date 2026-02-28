import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Wallets extends Table {
  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get currency => text()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Assets extends Table {
  TextColumn get id => text()();

  TextColumn get walletId =>
      text().references(Wallets, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get type => text()();

  TextColumn get currency => text()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'asset_events_asset_id_idx', columns: {#assetId})
@TableIndex(name: 'asset_events_created_at_idx', columns: {#createdAt})
class AssetEvents extends Table {
  TextColumn get id => text()();

  TextColumn get assetId =>
      text().references(Assets, #id, onDelete: KeyAction.cascade)();

  TextColumn get type => text()();

  RealColumn get quantityDelta => real().nullable()();

  RealColumn get pricePerUnit => real().nullable()();

  TextColumn get note => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppSettingsEntries extends Table {
  IntColumn get id => integer()();

  TextColumn get mainCurrency => text().withDefault(const Constant('IDR'))();

  RealColumn get usdToIdrRate => real().withDefault(const Constant(16000))();

  RealColumn get sgdToIdrRate => real().withDefault(const Constant(12000))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Wallets, Assets, AssetEvents, AppSettingsEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor}) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettingsEntries).insert(
        AppSettingsEntriesCompanion.insert(id: const Value(1)),
        mode: InsertMode.insertOrIgnore,
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(appSettingsEntries);
        await into(appSettingsEntries).insert(
          AppSettingsEntriesCompanion.insert(id: const Value(1)),
          mode: InsertMode.insertOrIgnore,
        );
      }
      if (from < 3) {
        await m.addColumn(appSettingsEntries, appSettingsEntries.sgdToIdrRate);
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'fiapp.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
