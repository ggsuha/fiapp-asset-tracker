import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models.dart';
import '../database/app_database.dart';
import 'asset_repository.dart';

class WalletRepository {
  WalletRepository(this._db, this._assetRepository, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final AssetRepository _assetRepository;
  final Uuid _uuid;

  Stream<List<Wallet>> watchWallets() {
    return (_db.select(
      _db.wallets,
    )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).watch();
  }

  Future<String> createWallet({
    required String name,
    required String currency,
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.wallets)
        .insert(
          WalletsCompanion.insert(id: id, name: name, currency: currency),
        );
    return id;
  }

  Future<void> deleteWallet(String id) {
    return (_db.delete(_db.wallets)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<WalletSummary>> watchWalletSummaries() {
    final query = _db.customSelect(
      '''
      WITH latest_price_event AS (
        SELECT asset_id, MAX(created_at) AS max_created_at
        FROM asset_events
        WHERE price_per_unit IS NOT NULL
        GROUP BY asset_id
      ),
      asset_quantity AS (
        SELECT asset_id, COALESCE(SUM(quantity_delta), 0) AS quantity
        FROM asset_events
        GROUP BY asset_id
      )
      SELECT
        w.id AS wallet_id,
        w.name AS wallet_name,
        w.currency AS wallet_currency,
        COALESCE(SUM(COALESCE(q.quantity, 0) * COALESCE(pe.price_per_unit, 0)), 0) AS wallet_total
      FROM wallets w
      LEFT JOIN assets a ON a.wallet_id = w.id
      LEFT JOIN asset_quantity q ON q.asset_id = a.id
      LEFT JOIN latest_price_event lp ON lp.asset_id = a.id
      LEFT JOIN asset_events pe
        ON pe.asset_id = a.id
       AND pe.created_at = lp.max_created_at
       AND pe.price_per_unit IS NOT NULL
      GROUP BY w.id, w.name, w.currency
      ORDER BY w.created_at ASC
      ''',
      readsFrom: {_db.wallets, _db.assets, _db.assetEvents},
    );

    return query.watch().map((rows) {
      return rows
          .map(
            (row) => WalletSummary(
              walletId: row.read<String>('wallet_id'),
              name: row.read<String>('wallet_name'),
              currency: row.read<String>('wallet_currency'),
              totalValue: row.read<double>('wallet_total'),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<double> getCurrentQuantity(String assetId) {
    return _assetRepository.getCurrentQuantity(assetId);
  }

  Future<double> getCurrentPrice(String assetId) {
    return _assetRepository.getCurrentPrice(assetId);
  }

  Future<double> getAssetTotal(String assetId) {
    return _assetRepository.getAssetTotal(assetId);
  }

  Future<double> getWalletTotal(String walletId) {
    return _assetRepository.getWalletTotal(walletId);
  }

  Future<double> getNetWorth() {
    return _assetRepository.getNetWorth();
  }
}
