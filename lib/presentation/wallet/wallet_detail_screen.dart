import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currency.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../asset/add_edit_asset_screen.dart';
import '../asset/asset_detail_screen.dart';

class WalletDetailScreen extends ConsumerWidget {
  const WalletDetailScreen({
    super.key,
    required this.walletId,
    required this.walletName,
  });

  final String walletId;
  final String walletName;

  static const _chartColors = <Color>[
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  Color _assetColor(int index) => _chartColors[index % _chartColors.length];

  List<PieChartSectionData> _buildAllocationSections(
    List<AssetSnapshot> assets,
    CurrencySettings settings,
  ) {
    final convertedValues = assets
        .map(
          (asset) => convertCurrency(
            asset.totalValue,
            from: asset.currency,
            to: settings.mainCurrency,
            settings: settings,
          ),
        )
        .toList(growable: false);

    final total = convertedValues.fold<double>(0, (sum, value) => sum + value);

    return [
      for (var i = 0; i < assets.length; i++)
        PieChartSectionData(
          value: max(convertedValues[i], 0.0001),
          color: _assetColor(i),
          title: total == 0
              ? '0%'
              : '${((convertedValues[i] / total) * 100).toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          radius: 62,
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(currencySettingsProvider);
    final assetsAsync = ref.watch(walletAssetsProvider(walletId));
    final settings = settingsAsync.asData?.value ?? CurrencySettings.defaults;

    return Scaffold(
      appBar: AppBar(title: Text(walletName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditAssetScreen(walletId: walletId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Asset'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF1F9FF), Color(0xFFF8FBFF), Color(0xFFF8FCFA)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            assetsAsync.when(
              data: (assets) {
                final total = assets.fold<double>(
                  0,
                  (sum, asset) =>
                      sum +
                      convertCurrency(
                        asset.totalValue,
                        from: asset.currency,
                        to: settings.mainCurrency,
                        settings: settings,
                      ),
                );
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  child: Text(
                    'Wallet Total: ${asMoney(total, currency: settings.mainCurrency)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            Text(
              'Allocation in Wallet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            assetsAsync.when(
              data: (assets) {
                if (assets.isEmpty) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: Text('No assets yet')),
                  );
                }
                if (assets.every((asset) => asset.totalValue <= 0)) {
                  return const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'All asset totals are 0. Update quantity/price to see allocation.',
                      ),
                    ),
                  );
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 38,
                          sections: _buildAllocationSections(assets, settings),
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            Text('Assets', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            assetsAsync.when(
              data: (assets) {
                if (assets.isEmpty) {
                  return const Text('No assets yet');
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: assets.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.45,
                  ),
                  itemBuilder: (context, index) {
                    final asset = assets[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AssetDetailScreen(
                                assetId: asset.assetId,
                                walletId: walletId,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: _assetColor(index),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      asset.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const Spacer(),
                                    Text(
                                      asWholeNumber(asset.totalValue),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
