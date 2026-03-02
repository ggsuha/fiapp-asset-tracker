import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/currency.dart';
import '../data/database/app_database.dart';
import '../data/repositories/asset_event_repository.dart';
import '../data/repositories/asset_repository.dart';
import '../data/repositories/data_transfer_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../domain/models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository(ref.watch(databaseProvider));
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(
    ref.watch(databaseProvider),
    ref.watch(assetRepositoryProvider),
  );
});

final assetEventRepositoryProvider = Provider<AssetEventRepository>((ref) {
  return AssetEventRepository(ref.watch(databaseProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseProvider));
});

final dataTransferRepositoryProvider = Provider<DataTransferRepository>((ref) {
  return DataTransferRepository(
    ref.watch(databaseProvider),
    ref.watch(assetRepositoryProvider),
  );
});

final currencySettingsProvider = StreamProvider<CurrencySettings>((ref) {
  return ref.watch(settingsRepositoryProvider).watchCurrencySettings();
});

class HideValuesNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final hideValuesProvider = NotifierProvider<HideValuesNotifier, bool>(
  HideValuesNotifier.new,
);

final walletsProvider = StreamProvider<List<Wallet>>((ref) {
  return ref.watch(walletRepositoryProvider).watchWallets();
});

final walletSummariesProvider = StreamProvider<List<WalletSummary>>((ref) {
  return ref.watch(walletRepositoryProvider).watchWalletSummaries();
});

final walletTotalProvider = StreamProvider.family<double, String>((
  ref,
  walletId,
) {
  return ref.watch(assetRepositoryProvider).watchWalletTotal(walletId);
});

final walletAssetsProvider = StreamProvider.family<List<AssetSnapshot>, String>(
  (ref, walletId) {
    return ref
        .watch(assetRepositoryProvider)
        .watchAssetSnapshotsForWallet(walletId);
  },
);

final assetSnapshotProvider =
    StreamProvider.family<AssetSnapshot?, ({String walletId, String assetId})>((
      ref,
      params,
    ) {
      return ref
          .watch(assetRepositoryProvider)
          .watchAssetSnapshotsForWallet(params.walletId)
          .map(
            (assets) => assets.firstWhere(
              (asset) => asset.assetId == params.assetId,
              orElse: () => const AssetSnapshot(
                assetId: '',
                name: '',
                type: AssetType.custom,
                currency: 'IDR',
                currentQuantity: 0,
                currentPrice: 0,
              ),
            ),
          )
          .map((asset) => asset.assetId.isEmpty ? null : asset);
    });

final assetProvider = StreamProvider.family<Asset?, String>((ref, assetId) {
  return ref.watch(assetRepositoryProvider).watchAssetById(assetId);
});

final assetQuantityProvider = FutureProvider.family<double, String>((
  ref,
  assetId,
) {
  return ref.watch(assetRepositoryProvider).getCurrentQuantity(assetId);
});

final assetPriceProvider = FutureProvider.family<double, String>((
  ref,
  assetId,
) {
  return ref.watch(assetRepositoryProvider).getCurrentPrice(assetId);
});

final assetTotalProvider = FutureProvider.family<double, String>((
  ref,
  assetId,
) {
  return ref.watch(assetRepositoryProvider).getAssetTotal(assetId);
});

final assetEventsProvider = StreamProvider.family<List<AssetEvent>, String>((
  ref,
  assetId,
) {
  return ref.watch(assetEventRepositoryProvider).watchEventsForAsset(assetId);
});

final netWorthProvider = Provider<double>((ref) {
  final walletSummariesAsync = ref.watch(walletSummariesProvider);
  final settingsAsync = ref.watch(currencySettingsProvider);

  final wallets = walletSummariesAsync.asData?.value ?? const <WalletSummary>[];
  final settings = settingsAsync.asData?.value ?? CurrencySettings.defaults;

  return wallets.fold<double>(
    0,
    (sum, wallet) =>
        sum +
        convertCurrency(
          wallet.totalValue,
          from: wallet.currency,
          to: settings.mainCurrency,
          settings: settings,
        ),
  );
});

final dashboardAllocationProvider = Provider<List<WalletSummary>>((ref) {
  final walletSummariesAsync = ref.watch(walletSummariesProvider);
  final settingsAsync = ref.watch(currencySettingsProvider);

  final wallets = walletSummariesAsync.asData?.value ?? const <WalletSummary>[];
  final settings = settingsAsync.asData?.value ?? CurrencySettings.defaults;

  return wallets
      .map(
        (wallet) => WalletSummary(
          walletId: wallet.walletId,
          name: wallet.name,
          currency: settings.mainCurrency,
          totalValue: convertCurrency(
            wallet.totalValue,
            from: wallet.currency,
            to: settings.mainCurrency,
            settings: settings,
          ),
        ),
      )
      .toList(growable: false);
});

final netWorthHistoryProvider = StreamProvider<List<NetWorthPoint>>((ref) {
  final settings = ref.watch(currencySettingsProvider).asData?.value;
  return ref
      .watch(assetRepositoryProvider)
      .watchNetWorthHistory(
        settings: settings ?? CurrencySettings.defaults,
        targetCurrency: (settings ?? CurrencySettings.defaults).mainCurrency,
      );
});

final walletValueHistoryProvider =
    StreamProvider.family<List<NetWorthPoint>, String>((ref, walletId) {
      final settings = ref.watch(currencySettingsProvider).asData?.value;
      final resolved = settings ?? CurrencySettings.defaults;
      return ref
          .watch(assetRepositoryProvider)
          .watchWalletValueHistory(
            walletId,
            settings: resolved,
            targetCurrency: resolved.mainCurrency,
          );
    });

final assetValueHistoryProvider =
    StreamProvider.family<List<AssetValuePoint>, String>((ref, assetId) {
      return ref.watch(assetRepositoryProvider).watchAssetValueHistory(assetId);
    });
