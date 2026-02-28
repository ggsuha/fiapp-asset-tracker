import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/formatters.dart';
import '../database/app_database.dart';
import 'asset_repository.dart';

class DataTransferRepository {
  const DataTransferRepository(this._db, this._assetRepository);

  final AppDatabase _db;
  final AssetRepository _assetRepository;

  Future<String> exportDataToJsonFile() async {
    final settings =
        await (_db.select(_db.appSettingsEntries)
              ..where((t) => t.id.equals(1))
              ..limit(1))
            .getSingleOrNull();
    final wallets = await _db.select(_db.wallets).get();
    final assets = await _db.select(_db.assets).get();
    final events = await _db.select(_db.assetEvents).get();

    final payload = <String, Object?>{
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'settings': settings == null
          ? null
          : {
              'id': settings.id,
              'main_currency': settings.mainCurrency,
              'usd_to_idr_rate': settings.usdToIdrRate,
              'sgd_to_idr_rate': settings.sgdToIdrRate,
            },
      'wallets': wallets
          .map(
            (w) => {
              'id': w.id,
              'name': w.name,
              'currency': w.currency,
              'created_at': w.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      'assets': assets
          .map(
            (a) => {
              'id': a.id,
              'wallet_id': a.walletId,
              'name': a.name,
              'type': a.type,
              'currency': a.currency,
              'created_at': a.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      'asset_events': events
          .map(
            (e) => {
              'id': e.id,
              'asset_id': e.assetId,
              'type': e.type,
              'quantity_delta': e.quantityDelta,
              'price_per_unit': e.pricePerUnit,
              'note': e.note,
              'created_at': e.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false),
    };

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'fiapp_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file.path;
  }

  Future<void> importDataFromJsonFile(String filePath) async {
    final source = File(filePath);
    final content = await source.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format');
    }

    final settings = decoded['settings'] as Map<String, dynamic>?;
    final wallets = (decoded['wallets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final assets = (decoded['assets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final events = (decoded['asset_events'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      await _db.delete(_db.assetEvents).go();
      await _db.delete(_db.assets).go();
      await _db.delete(_db.wallets).go();
      await _db.delete(_db.appSettingsEntries).go();

      if (settings != null) {
        await _db
            .into(_db.appSettingsEntries)
            .insert(
              AppSettingsEntriesCompanion.insert(
                id: Value((settings['id'] as num?)?.toInt() ?? 1),
                mainCurrency: Value(
                  settings['main_currency']?.toString() ?? 'IDR',
                ),
                usdToIdrRate: Value(
                  (settings['usd_to_idr_rate'] as num?)?.toDouble() ?? 16000,
                ),
                sgdToIdrRate: Value(
                  (settings['sgd_to_idr_rate'] as num?)?.toDouble() ?? 12000,
                ),
              ),
            );
      } else {
        await _db
            .into(_db.appSettingsEntries)
            .insert(
              AppSettingsEntriesCompanion.insert(
                id: const Value(1),
                mainCurrency: const Value('IDR'),
                usdToIdrRate: const Value(16000),
                sgdToIdrRate: const Value(12000),
              ),
            );
      }

      await _db.batch((batch) {
        batch.insertAll(
          _db.wallets,
          wallets
              .map(
                (w) => WalletsCompanion.insert(
                  id: w['id'].toString(),
                  name: w['name'].toString(),
                  currency: w['currency'].toString(),
                  createdAt: Value(DateTime.parse(w['created_at'].toString())),
                ),
              )
              .toList(growable: false),
        );
      });

      await _db.batch((batch) {
        batch.insertAll(
          _db.assets,
          assets
              .map(
                (a) => AssetsCompanion.insert(
                  id: a['id'].toString(),
                  walletId: a['wallet_id'].toString(),
                  name: a['name'].toString(),
                  type: a['type'].toString(),
                  currency: a['currency'].toString(),
                  createdAt: Value(DateTime.parse(a['created_at'].toString())),
                ),
              )
              .toList(growable: false),
        );
      });

      await _db.batch((batch) {
        batch.insertAll(
          _db.assetEvents,
          events
              .map(
                (e) => AssetEventsCompanion.insert(
                  id: e['id'].toString(),
                  assetId: e['asset_id'].toString(),
                  type: e['type'].toString(),
                  quantityDelta: Value(
                    (e['quantity_delta'] as num?)?.toDouble(),
                  ),
                  pricePerUnit: Value(
                    (e['price_per_unit'] as num?)?.toDouble(),
                  ),
                  note: Value(e['note']?.toString()),
                  createdAt: Value(DateTime.parse(e['created_at'].toString())),
                ),
              )
              .toList(growable: false),
        );
      });
    });
  }

  Future<String> exportAssetsPdfFile() async {
    final wallets = await _db.select(_db.wallets).get();
    final doc = pw.Document();

    final rows = <List<String>>[];

    for (final wallet in wallets) {
      final assets = await _assetRepository
          .watchAssetSnapshotsForWallet(wallet.id)
          .first;
      for (final asset in assets) {
        rows.add([
          wallet.name,
          asset.name,
          asset.currency,
          asWholeNumber(asset.currentQuantity),
          asWholeNumber(asset.currentPrice),
          asWholeNumber(asset.totalValue),
        ]);
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Fiapp Asset Export',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Generated: ${DateTime.now().toIso8601String()}'),
          pw.SizedBox(height: 12),
          if (rows.isEmpty)
            pw.Text('No assets available')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Wallet',
                'Asset',
                'Currency',
                'Qty',
                'Price',
                'Total',
              ],
              data: rows,
            ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'fiapp_assets_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(await doc.save());
    return file.path;
  }
}
