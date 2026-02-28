import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../../core/currency.dart';

class SettingsRepository {
  const SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<CurrencySettings> watchCurrencySettings() {
    final query = _db.select(_db.appSettingsEntries)
      ..where((t) => t.id.equals(1))
      ..limit(1);

    return query.watchSingleOrNull().map((entry) {
      if (entry == null) {
        return CurrencySettings.defaults;
      }
      return CurrencySettings(
        mainCurrency: entry.mainCurrency,
        usdToIdrRate: entry.usdToIdrRate,
        sgdToIdrRate: entry.sgdToIdrRate,
      );
    });
  }

  Future<void> updateCurrencySettings({
    required String mainCurrency,
    required double usdToIdrRate,
    required double sgdToIdrRate,
  }) async {
    await _db
        .into(_db.appSettingsEntries)
        .insertOnConflictUpdate(
          AppSettingsEntriesCompanion(
            id: const Value(1),
            mainCurrency: Value(mainCurrency.toUpperCase()),
            usdToIdrRate: Value(usdToIdrRate),
            sgdToIdrRate: Value(sgdToIdrRate),
          ),
        );
  }
}
