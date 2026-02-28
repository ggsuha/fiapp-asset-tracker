import 'package:drift/drift.dart';

import '../database/app_database.dart';

class AssetEventRepository {
  const AssetEventRepository(this._db);

  final AppDatabase _db;

  Stream<List<AssetEvent>> watchAllEvents() {
    return (_db.select(_db.assetEvents)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<AssetEvent>> watchEventsForAsset(String assetId) {
    return (_db.select(_db.assetEvents)
          ..where((t) => t.assetId.equals(assetId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<AssetEvent>> getEventsForAsset(String assetId) {
    return (_db.select(_db.assetEvents)
          ..where((t) => t.assetId.equals(assetId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> insertEvent(AssetEventsCompanion event) {
    return _db.into(_db.assetEvents).insert(event);
  }

  Future<double> getCurrentQuantity(String assetId) async {
    final totalExpr = _db.assetEvents.quantityDelta.sum();
    final query = _db.selectOnly(_db.assetEvents)
      ..addColumns([totalExpr])
      ..where(_db.assetEvents.assetId.equals(assetId));
    final row = await query.getSingle();
    return row.read(totalExpr) ?? 0;
  }

  Future<double> getCurrentPrice(String assetId) async {
    final latest = await (_db.select(_db.assetEvents)
          ..where(
            (t) => t.assetId.equals(assetId) & t.pricePerUnit.isNotNull(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(1))
        .getSingleOrNull();
    return latest?.pricePerUnit ?? 0;
  }

  Future<double> getAssetTotal(String assetId) async {
    final qty = await getCurrentQuantity(assetId);
    final price = await getCurrentPrice(assetId);
    return qty * price;
  }

  Future<double> getWalletTotal(String walletId) async {
    final assets = await (_db.select(_db.assets)
          ..where((t) => t.walletId.equals(walletId)))
        .get();
    double sum = 0;
    for (final asset in assets) {
      sum += await getAssetTotal(asset.id);
    }
    return sum;
  }

  Future<double> getNetWorth() async {
    final wallets = await _db.select(_db.wallets).get();
    double sum = 0;
    for (final wallet in wallets) {
      sum += await getWalletTotal(wallet.id);
    }
    return sum;
  }
}
