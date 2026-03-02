import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/currency.dart';
import '../../core/event_sourcing.dart';
import '../../domain/models.dart';
import '../database/app_database.dart';

class AssetRepository {
  AssetRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<Asset>> watchAssetsInWallet(String walletId) {
    return (_db.select(_db.assets)
          ..where((t) => t.walletId.equals(walletId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<Asset?> watchAssetById(String assetId) {
    return (_db.select(
      _db.assets,
    )..where((t) => t.id.equals(assetId))).watchSingleOrNull();
  }

  Future<Asset?> getAssetById(String assetId) {
    return (_db.select(
      _db.assets,
    )..where((t) => t.id.equals(assetId))).getSingleOrNull();
  }

  Future<String> createAsset({
    required String walletId,
    required String name,
    required AssetType type,
    required String currency,
    required double quantity,
    required double price,
    String? note,
  }) async {
    final assetId = _uuid.v4();
    await _db.transaction(() async {
      await _db
          .into(_db.assets)
          .insert(
            AssetsCompanion.insert(
              id: assetId,
              walletId: walletId,
              name: name,
              type: type.dbValue,
              currency: currency,
            ),
          );

      if (quantity != 0) {
        await _db
            .into(_db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                id: _uuid.v4(),
                assetId: assetId,
                type: AssetEventType.adjustment.dbValue,
                quantityDelta: Value(quantity),
                note: Value(note),
              ),
            );
      }

      if (price != 0) {
        await _db
            .into(_db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                id: _uuid.v4(),
                assetId: assetId,
                type: AssetEventType.priceUpdate.dbValue,
                pricePerUnit: Value(price),
                note: Value(note),
              ),
            );
      }
    });

    return assetId;
  }

  Future<void> editAsset({
    required String assetId,
    required String name,
    required AssetType type,
    required String currency,
    required double quantity,
    required double price,
    String? note,
  }) async {
    await _db.transaction(() async {
      final previousQuantity = await getCurrentQuantity(assetId);
      final previousPrice = await getCurrentPrice(assetId);

      await (_db.update(_db.assets)..where((t) => t.id.equals(assetId))).write(
        AssetsCompanion(
          name: Value(name),
          type: Value(type.dbValue),
          currency: Value(currency),
        ),
      );

      final diff = EventMath.editDiff(
        oldQuantity: previousQuantity,
        oldPrice: previousPrice,
        newQuantity: quantity,
        newPrice: price,
      );

      if (diff.quantityDelta != null) {
        await _db
            .into(_db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                id: _uuid.v4(),
                assetId: assetId,
                type: AssetEventType.adjustment.dbValue,
                quantityDelta: Value(diff.quantityDelta),
                note: Value(note),
              ),
            );
      }

      if (diff.newPrice != null) {
        await _db
            .into(_db.assetEvents)
            .insert(
              AssetEventsCompanion.insert(
                id: _uuid.v4(),
                assetId: assetId,
                type: AssetEventType.priceUpdate.dbValue,
                pricePerUnit: Value(diff.newPrice),
                note: Value(note),
              ),
            );
      }
    });
  }

  Future<void> deleteAsset(String assetId) {
    return (_db.delete(_db.assets)..where((t) => t.id.equals(assetId))).go();
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
    final latest =
        await (_db.select(_db.assetEvents)
              ..where(
                (t) => t.assetId.equals(assetId) & t.pricePerUnit.isNotNull(),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.id),
              ])
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
    final assets = await (_db.select(
      _db.assets,
    )..where((t) => t.walletId.equals(walletId))).get();
    double sum = 0;
    for (final asset in assets) {
      sum += await getAssetTotal(asset.id);
    }
    return sum;
  }

  Stream<double> watchWalletTotal(String walletId) {
    return watchAssetSnapshotsForWallet(walletId).map(
      (assets) =>
          assets.fold<double>(0, (sum, asset) => sum + asset.totalValue),
    );
  }

  Future<double> getNetWorth() async {
    final wallets = await _db.select(_db.wallets).get();
    double sum = 0;
    for (final wallet in wallets) {
      sum += await getWalletTotal(wallet.id);
    }
    return sum;
  }

  Stream<List<AssetSnapshot>> watchAssetSnapshotsForWallet(String walletId) {
    final query = _db.customSelect(
      '''
      SELECT
        a.id AS asset_id,
        a.name AS asset_name,
        a.type AS asset_type,
        a.currency AS asset_currency,
        e.quantity_delta AS quantity_delta,
        e.price_per_unit AS price_per_unit,
        e.created_at AS event_created_at
      FROM assets a
      LEFT JOIN asset_events e ON e.asset_id = a.id
      WHERE a.wallet_id = ?
      ORDER BY a.id, e.created_at ASC, e.id ASC
      ''',
      variables: [Variable.withString(walletId)],
      readsFrom: {_db.assets, _db.assetEvents},
    );

    return query.watch().map((rows) {
      final byAsset = <String, _AssetAccumulator>{};

      for (final row in rows) {
        final assetId = row.read<String>('asset_id');
        final accumulator = byAsset.putIfAbsent(
          assetId,
          () => _AssetAccumulator(
            assetId: assetId,
            name: row.read<String>('asset_name'),
            type: AssetType.fromDb(row.read<String>('asset_type')),
            currency: row.read<String>('asset_currency'),
          ),
        );

        final quantityDelta = row.read<double?>('quantity_delta');
        final pricePerUnit = row.read<double?>('price_per_unit');

        if (quantityDelta != null) {
          accumulator.quantity += quantityDelta;
        }
        if (pricePerUnit != null) {
          accumulator.price = pricePerUnit;
        }
      }

      return byAsset.values
          .map(
            (a) => AssetSnapshot(
              assetId: a.assetId,
              name: a.name,
              type: a.type,
              currency: a.currency,
              currentQuantity: a.quantity,
              currentPrice: a.price,
            ),
          )
          .toList(growable: false);
    });
  }

  Stream<List<NetWorthPoint>> watchNetWorthHistory({
    required CurrencySettings settings,
    required String targetCurrency,
  }) {
    final query = _db.customSelect(
      '''
      SELECT
        e.asset_id AS asset_id,
        e.quantity_delta AS quantity_delta,
        e.price_per_unit AS price_per_unit,
        e.created_at AS event_created_at,
        a.currency AS asset_currency
      FROM asset_events e
      INNER JOIN assets a ON a.id = e.asset_id
      ORDER BY e.created_at ASC
      ''',
      readsFrom: {_db.assetEvents, _db.assets},
    );

    return query.watch().map((rows) {
      final quantityByAsset = <String, double>{};
      final priceByAsset = <String, double>{};
      final currencyByAsset = <String, String>{};
      final convertedValueByAsset = <String, double>{};
      final dailyNetWorth = <DateTime, double>{};
      double total = 0;

      for (final row in rows) {
        final assetId = row.read<String>('asset_id');
        final quantityDelta = row.read<double?>('quantity_delta');
        final pricePerUnit = row.read<double?>('price_per_unit');
        final createdAt = row.read<DateTime>('event_created_at');
        final assetCurrency = row.read<String>('asset_currency');
        currencyByAsset[assetId] = assetCurrency;
        final oldValue = convertedValueByAsset[assetId] ?? 0;

        if (quantityDelta != null) {
          quantityByAsset[assetId] =
              (quantityByAsset[assetId] ?? 0) + quantityDelta;
        }
        if (pricePerUnit != null) {
          priceByAsset[assetId] = pricePerUnit;
        }

        final newAssetValue =
            (quantityByAsset[assetId] ?? 0) * (priceByAsset[assetId] ?? 0);
        final newValue = convertCurrency(
          newAssetValue,
          from: currencyByAsset[assetId] ?? targetCurrency,
          to: targetCurrency,
          settings: settings,
        );
        convertedValueByAsset[assetId] = newValue;
        total += newValue - oldValue;

        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        dailyNetWorth[day] = total;
      }

      return dailyNetWorth.entries
          .map((entry) => NetWorthPoint(date: entry.key, value: entry.value))
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Stream<List<NetWorthPoint>> watchWalletValueHistory(
    String walletId, {
    required CurrencySettings settings,
    required String targetCurrency,
  }) {
    final query = _db.customSelect(
      '''
      SELECT
        e.asset_id AS asset_id,
        e.quantity_delta AS quantity_delta,
        e.price_per_unit AS price_per_unit,
        e.created_at AS event_created_at,
        a.currency AS asset_currency
      FROM asset_events e
      INNER JOIN assets a ON a.id = e.asset_id
      WHERE a.wallet_id = ?
      ORDER BY e.created_at ASC, e.id ASC
      ''',
      variables: [Variable.withString(walletId)],
      readsFrom: {_db.assetEvents, _db.assets},
    );

    return query.watch().map((rows) {
      final quantityByAsset = <String, double>{};
      final priceByAsset = <String, double>{};
      final currencyByAsset = <String, String>{};
      final convertedValueByAsset = <String, double>{};
      final dailyValue = <DateTime, double>{};
      double total = 0;

      for (final row in rows) {
        final assetId = row.read<String>('asset_id');
        final quantityDelta = row.read<double?>('quantity_delta');
        final pricePerUnit = row.read<double?>('price_per_unit');
        final createdAt = row.read<DateTime>('event_created_at');
        final assetCurrency = row.read<String>('asset_currency');
        currencyByAsset[assetId] = assetCurrency;
        final oldValue = convertedValueByAsset[assetId] ?? 0;

        if (quantityDelta != null) {
          quantityByAsset[assetId] =
              (quantityByAsset[assetId] ?? 0) + quantityDelta;
        }
        if (pricePerUnit != null) {
          priceByAsset[assetId] = pricePerUnit;
        }

        final newAssetValue =
            (quantityByAsset[assetId] ?? 0) * (priceByAsset[assetId] ?? 0);
        final newValue = convertCurrency(
          newAssetValue,
          from: currencyByAsset[assetId] ?? targetCurrency,
          to: targetCurrency,
          settings: settings,
        );
        convertedValueByAsset[assetId] = newValue;
        total += newValue - oldValue;

        final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
        dailyValue[day] = total;
      }

      return dailyValue.entries
          .map((entry) => NetWorthPoint(date: entry.key, value: entry.value))
          .toList(growable: false)
        ..sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Stream<List<AssetValuePoint>> watchAssetValueHistory(String assetId) {
    return (_db.select(_db.assetEvents)
          ..where((t) => t.assetId.equals(assetId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((events) {
          final dailyValues = <DateTime, double>{};
          double quantity = 0;
          double price = 0;

          for (final event in events) {
            if (event.quantityDelta != null) {
              quantity += event.quantityDelta!;
            }
            if (event.pricePerUnit != null) {
              price = event.pricePerUnit!;
            }

            final day = DateTime(
              event.createdAt.year,
              event.createdAt.month,
              event.createdAt.day,
            );
            dailyValues[day] = quantity * price;
          }

          return dailyValues.entries
              .map(
                (entry) => AssetValuePoint(date: entry.key, value: entry.value),
              )
              .toList(growable: false)
            ..sort((a, b) => a.date.compareTo(b.date));
        });
  }
}

class _AssetAccumulator {
  _AssetAccumulator({
    required this.assetId,
    required this.name,
    required this.type,
    required this.currency,
  });

  final String assetId;
  final String name;
  final AssetType type;
  final String currency;
  double quantity = 0;
  double price = 0;
}
