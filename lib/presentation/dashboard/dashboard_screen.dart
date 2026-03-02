import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../wallet/wallet_detail_screen.dart';

enum _HomeChartRange {
  oneDay,
  oneMonth,
  threeMonths,
  ytd,
  oneYear,
  threeYears,
  fiveYears,
  all,
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const _brandGreen = Color(0xFF00A86B);
  static const _brandGreenDark = Color(0xFF0A8F5B);
  static const _bgTop = Color(0xFFF2F7F3);
  static const _bgBottom = Color(0xFFEFF6F1);

  bool _showWalletFab = false;
  _HomeChartRange _selectedHomeRange = _HomeChartRange.oneMonth;
  int? _selectedHomeSpotIndex;

  BoxDecoration get _backgroundDecoration => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [_bgTop, _bgBottom],
    ),
  );

  Future<void> _showCreateWalletDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var name = '';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('New Wallet'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Name',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  onChanged: (value) => name = value,
                  decoration: const InputDecoration(hintText: 'Wallet name'),
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
                      .createWallet(name: trimmedName, currency: 'IDR');
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

  DateTime? _homeRangeStart(_HomeChartRange range, DateTime now) {
    switch (range) {
      case _HomeChartRange.oneDay:
        return now.subtract(const Duration(days: 1));
      case _HomeChartRange.oneMonth:
        return now.subtract(const Duration(days: 30));
      case _HomeChartRange.threeMonths:
        return now.subtract(const Duration(days: 90));
      case _HomeChartRange.ytd:
        return DateTime(now.year);
      case _HomeChartRange.oneYear:
        return DateTime(now.year - 1, now.month, now.day);
      case _HomeChartRange.threeYears:
        return DateTime(now.year - 3, now.month, now.day);
      case _HomeChartRange.fiveYears:
        return DateTime(now.year - 5, now.month, now.day);
      case _HomeChartRange.all:
        return null;
    }
  }

  List<NetWorthPoint> _filterNetWorthByRange(List<NetWorthPoint> points) {
    if (points.isEmpty) {
      return points;
    }

    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final start = _homeRangeStart(_selectedHomeRange, DateTime.now());
    if (start == null) {
      return sorted;
    }

    final filtered = sorted
        .where((point) => !point.date.isBefore(start))
        .toList(growable: false);
    return filtered.isEmpty ? [sorted.last] : filtered;
  }

  String _homeRangeLabel(_HomeChartRange range) {
    switch (range) {
      case _HomeChartRange.oneDay:
        return '1D';
      case _HomeChartRange.oneMonth:
        return '1M';
      case _HomeChartRange.threeMonths:
        return '3M';
      case _HomeChartRange.ytd:
        return 'YTD';
      case _HomeChartRange.oneYear:
        return '1Y';
      case _HomeChartRange.threeYears:
        return '3Y';
      case _HomeChartRange.fiveYears:
        return '5Y';
      case _HomeChartRange.all:
        return 'All';
    }
  }

  String _rangePeriodLabel(_HomeChartRange range) {
    switch (range) {
      case _HomeChartRange.oneDay:
        return '1 Hari';
      case _HomeChartRange.oneMonth:
        return '1 Bulan';
      case _HomeChartRange.threeMonths:
        return '3 Bulan';
      case _HomeChartRange.ytd:
        return 'YTD';
      case _HomeChartRange.oneYear:
        return '1 Tahun';
      case _HomeChartRange.threeYears:
        return '3 Tahun';
      case _HomeChartRange.fiveYears:
        return '5 Tahun';
      case _HomeChartRange.all:
        return 'All Time';
    }
  }

  String _maskedMoney(double value, bool hidden) {
    if (hidden) {
      return '***';
    }
    return asMoney(value);
  }

  Widget _buildHomeRangeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _HomeChartRange.values
            .map((range) {
              final selected = range == _selectedHomeRange;
              return Padding(
                padding: const EdgeInsets.only(right: 18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedHomeRange = range;
                      _selectedHomeSpotIndex = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _homeRangeLabel(range),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? _brandGreen
                                : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 6),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          height: 3,
                          width: 20,
                          decoration: BoxDecoration(
                            color: selected ? _brandGreen : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  LineChartData _buildNetWorthChartData(
    List<NetWorthPoint> points, {
    required int selectedSpotIndex,
    required void Function(int? index) onSpotSelected,
    required bool hideValues,
  }) {
    final fixedPoints = points.length == 1
        ? [
            points.first,
            NetWorthPoint(
              date: points.first.date.add(const Duration(days: 1)),
              value: points.first.value,
            ),
          ]
        : points;
    final safeSelectedIndex = selectedSpotIndex.clamp(
      0,
      fixedPoints.length - 1,
    );

    final maxValue = fixedPoints.fold<double>(
      0,
      (prev, item) => max(prev, item.value),
    );
    final minValue = fixedPoints.fold<double>(
      fixedPoints.first.value,
      (prev, item) => min(prev, item.value),
    );
    final range = max(maxValue - minValue, 1.0);

    return LineChartData(
      minX: 0,
      maxX: (fixedPoints.length - 1).toDouble(),
      minY: max(minValue - (range * 0.18), 0),
      maxY: maxValue + (range * 0.18),
      borderData: FlBorderData(show: false),
      clipData: const FlClipData.all(),
      gridData: FlGridData(show: false),
      titlesData: const FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchCallback: (_, touchResponse) {
          final spots = touchResponse?.lineBarSpots;
          if (spots == null || spots.isEmpty) return;
          onSpotSelected(spots.first.x.toInt());
        },
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          getTooltipColor: (_) => Colors.white,
          getTooltipItems: (spots) => spots
              .map((spot) {
                final index = spot.x.toInt().clamp(0, fixedPoints.length - 1);
                final point = fixedPoints[index];
                return LineTooltipItem(
                  '${asCompactDate(point.date)}\n${_maskedMoney(point.value, hideValues)}',
                  const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    height: 1.35,
                  ),
                );
              })
              .toList(growable: false),
        ),
        getTouchedSpotIndicator: (_, spotIndexes) {
          return spotIndexes
              .map(
                (_) => TouchedSpotIndicatorData(
                  FlLine(
                    color: _brandGreenDark.withValues(alpha: 0.45),
                    strokeWidth: 1,
                  ),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                          radius: 5,
                          color: _brandGreen,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        ),
                  ),
                ),
              )
              .toList(growable: false);
        },
      ),
      lineBarsData: [
        LineChartBarData(
          isCurved: true,
          color: _brandGreen,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, barData) =>
                spot.x.toInt() == safeSelectedIndex,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 5,
                  color: _brandGreen,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _brandGreen.withValues(alpha: 0.28),
                _brandGreen.withValues(alpha: 0.02),
              ],
            ),
          ),
          barWidth: 3.2,
          showingIndicators: [safeSelectedIndex],
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
    final netWorthHistoryAsync = ref.watch(netWorthHistoryProvider);
    final hideValues = ref.watch(hideValuesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portofolio'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showWalletFab = !_showWalletFab),
            tooltip: _showWalletFab ? 'Hide Add Wallet' : 'Show Add Wallet',
            icon: Icon(
              _showWalletFab
                  ? Icons.account_balance_wallet
                  : Icons.account_balance_wallet_outlined,
            ),
          ),
          IconButton(
            onPressed: () => ref.read(hideValuesProvider.notifier).toggle(),
            tooltip: hideValues ? 'Show Values' : 'Hide Values',
            icon: Icon(
              hideValues
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
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
      body: Container(
        decoration: _backgroundDecoration,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, _showWalletFab ? 96 : 16),
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [_brandGreen, _brandGreenDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brandGreen.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Net Worth',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _maskedMoney(netWorth, hideValues),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Net Worth',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            netWorthHistoryAsync.when(
              data: (points) {
                if (points.isEmpty) {
                  return const SizedBox.shrink();
                }
                final filteredPoints = _filterNetWorthByRange(points);
                final startValue = filteredPoints.first.value;
                final endValue = filteredPoints.last.value;
                final netDiff = endValue - startValue;
                final netDiffPct = startValue == 0
                    ? 0
                    : (netDiff / startValue) * 100;
                final isUp = netDiff >= 0;
                final trendColor = isUp
                    ? _brandGreenDark
                    : const Color(0xFFB91C1C);
                final trendPrefix = isUp ? '+' : '-';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        isUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 16,
                        color: trendColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hideValues
                            ? '***'
                            : '$trendPrefix${asMoney(netDiff.abs())} ($trendPrefix${netDiffPct.abs().toStringAsFixed(2)}%)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: trendColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _rangePeriodLabel(_selectedHomeRange),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 248,
                  child: netWorthHistoryAsync.when(
                    data: (points) {
                      if (points.isEmpty) {
                        return const Center(child: Text('No history yet'));
                      }
                      final filteredPoints = _filterNetWorthByRange(points);
                      final minPoint = filteredPoints.reduce(
                        (a, b) => a.value <= b.value ? a : b,
                      );
                      final maxPoint = filteredPoints.reduce(
                        (a, b) => a.value >= b.value ? a : b,
                      );
                      final safeIndex =
                          (_selectedHomeSpotIndex != null &&
                              _selectedHomeSpotIndex! < filteredPoints.length)
                          ? _selectedHomeSpotIndex!
                          : filteredPoints.length - 1;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: LineChart(
                              _buildNetWorthChartData(
                                filteredPoints,
                                selectedSpotIndex: safeIndex,
                                hideValues: hideValues,
                                onSpotSelected: (index) {
                                  setState(() {
                                    _selectedHomeSpotIndex = index;
                                  });
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Text(
                              _maskedMoney(maxPoint.value, hideValues),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            left: 2,
                            child: Text(
                              _maskedMoney(minPoint.value, hideValues),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: const Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildHomeRangeFilter(),
            const SizedBox(height: 16),
            Text('Wallets', style: Theme.of(context).textTheme.titleMedium),
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
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _brandGreen.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: _brandGreenDark,
                              ),
                            ),
                            title: Text(wallet.name),
                            subtitle: const Text('IDR'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _maskedMoney(wallet.totalValue, hideValues),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Color(0xFF4B5563),
                                ),
                              ],
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
      ),
    );
  }
}
