import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/currency.dart';
import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../wallet/wallet_detail_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _showWalletFab = false;

  Future<void> _showCreateWalletDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var name = '';
    var currency = 'IDR';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('New Wallet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  onChanged: (value) => name = value,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: kSupportedCurrencies
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => currency = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final trimmedName = name.trim();
                  if (trimmedName.isEmpty) {
                    return;
                  }
                  await ref
                      .read(walletRepositoryProvider)
                      .createWallet(name: trimmedName, currency: currency);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCurrencySettingsDialog(
    BuildContext context,
    WidgetRef ref,
    CurrencySettings settings,
  ) async {
    var mainCurrency = settings.mainCurrency;
    var usdToIdrRateText = settings.usdToIdrRate.toStringAsFixed(2);
    var sgdToIdrRateText = settings.sgdToIdrRate.toStringAsFixed(2);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Currency Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: mainCurrency,
                decoration: const InputDecoration(labelText: 'Main Currency'),
                items: kSupportedCurrencies
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => mainCurrency = value);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: usdToIdrRateText,
                onChanged: (value) => usdToIdrRateText = value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'USD to IDR Rate',
                  helperText: '1 USD = ? IDR',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: sgdToIdrRateText,
                onChanged: (value) => sgdToIdrRateText = value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'SGD to IDR Rate',
                  helperText: '1 SGD = ? IDR',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final usdRate = double.tryParse(usdToIdrRateText.trim());
                final sgdRate = double.tryParse(sgdToIdrRateText.trim());
                if (usdRate == null || usdRate <= 0) {
                  return;
                }
                if (sgdRate == null || sgdRate <= 0) {
                  return;
                }
                await ref
                    .read(settingsRepositoryProvider)
                    .updateCurrencySettings(
                      mainCurrency: mainCurrency,
                      usdToIdrRate: usdRate,
                      sgdToIdrRate: sgdRate,
                    );
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportJsonBackup(BuildContext context, WidgetRef ref) async {
    final path = await ref
        .read(dataTransferRepositoryProvider)
        .exportDataToJsonFile();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Fiapp backup JSON'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup exported: $path')));
    }
  }

  Future<void> _importJsonBackup(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) {
      return;
    }

    await ref.read(dataTransferRepositoryProvider).importDataFromJsonFile(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup imported successfully')),
      );
    }
  }

  Future<void> _exportAssetsPdf(BuildContext context, WidgetRef ref) async {
    final path = await ref
        .read(dataTransferRepositoryProvider)
        .exportAssetsPdfFile();
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: 'Fiapp assets PDF'),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assets PDF exported: $path')));
    }
  }

  LineChartData _buildNetWorthChartData(
    List<NetWorthPoint> points,
    String currency,
  ) {
    final fixedPoints = points.length == 1
        ? [
            points.first,
            NetWorthPoint(
              date: points.first.date.add(const Duration(days: 1)),
              value: points.first.value,
            ),
          ]
        : points;

    final maxValue = fixedPoints.fold<double>(
      0,
      (prev, item) => max(prev, item.value),
    );
    final yInterval = max(maxValue / 4, 1.0);

    return LineChartData(
      minX: 0,
      maxX: (fixedPoints.length - 1).toDouble(),
      minY: 0,
      maxY: max(maxValue * 1.2, 1.0),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(show: true, horizontalInterval: yInterval),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: max((fixedPoints.length / 4).floorToDouble(), 1.0),
            getTitlesWidget: (value, _) {
              final index = value.round();
              if (index < 0 || index >= fixedPoints.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  asCompactDate(fixedPoints[index].date),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(currency, style: const TextStyle(fontSize: 10)),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: yInterval,
            getTitlesWidget: (value, _) => Text(
              value >= 1000
                  ? '${(value / 1000).toStringAsFixed(0)}K'
                  : value.toStringAsFixed(0),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          isCurved: true,
          color: const Color(0xFF2563EB),
          dotData: FlDotData(show: points.length == 1),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFFBFDBFE).withValues(alpha: 0.5),
          ),
          barWidth: 3,
          spots: [
            for (var i = 0; i < fixedPoints.length; i++)
              FlSpot(i.toDouble(), fixedPoints[i].value),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final netWorth = ref.watch(netWorthProvider);
    final walletSummariesAsync = ref.watch(walletSummariesProvider);
    final settingsAsync = ref.watch(currencySettingsProvider);
    final settings = settingsAsync.asData?.value ?? CurrencySettings.defaults;
    final netWorthHistoryAsync = ref.watch(netWorthHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiapp'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showWalletFab = !_showWalletFab),
            tooltip: _showWalletFab ? 'Hide Add Wallet' : 'Show Add Wallet',
            icon: Icon(
              _showWalletFab
                  ? Icons.visibility_off_outlined
                  : Icons.account_balance_wallet_outlined,
            ),
          ),
          IconButton(
            onPressed: () =>
                _showCurrencySettingsDialog(context, ref, settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export_json') {
                await _exportJsonBackup(context, ref);
              } else if (value == 'import_json') {
                await _importJsonBackup(context, ref);
              } else if (value == 'export_pdf') {
                await _exportAssetsPdf(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export_json',
                child: Text('Export Backup (JSON)'),
              ),
              PopupMenuItem(
                value: 'import_json',
                child: Text('Import Backup (JSON)'),
              ),
              PopupMenuItem(
                value: 'export_pdf',
                child: Text('Export Assets (PDF)'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: _showWalletFab
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateWalletDialog(context, ref),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Wallet'),
            )
          : null,
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, _showWalletFab ? 96 : 16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Net Worth'),
                  const SizedBox(height: 4),
                  Text(
                    asMoney(netWorth, currency: settings.mainCurrency),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Net Worth Over Time'),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: netWorthHistoryAsync.when(
              data: (points) {
                if (points.isEmpty) {
                  return const Center(child: Text('No history yet'));
                }
                return LineChart(
                  _buildNetWorthChartData(points, settings.mainCurrency),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Wallets'),
          const SizedBox(height: 8),
          walletSummariesAsync.when(
            data: (wallets) {
              if (wallets.isEmpty) {
                return const Text('Create your first wallet');
              }
              return Column(
                children: wallets
                    .map(
                      (wallet) => Card(
                        child: ListTile(
                          title: Text(wallet.name),
                          subtitle: Text(wallet.currency),
                          trailing: Text(
                            asMoney(
                              wallet.totalValue,
                              currency: wallet.currency,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WalletDetailScreen(
                                  walletId: wallet.walletId,
                                  walletName: wallet.name,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}
