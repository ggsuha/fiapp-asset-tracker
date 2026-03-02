import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import '../asset/add_edit_asset_screen.dart';
import '../asset/asset_detail_screen.dart';

enum _WalletChartRange {
  oneDay,
  oneMonth,
  threeMonths,
  ytd,
  oneYear,
  threeYears,
  fiveYears,
  all,
}

class WalletDetailScreen extends ConsumerStatefulWidget {
  const WalletDetailScreen({
    super.key,
    required this.walletId,
    required this.walletName,
  });

  final String walletId;
  final String walletName;

  @override
  ConsumerState<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends ConsumerState<WalletDetailScreen> {
  static const _chartColors = <Color>[
    Color(0xFF00A86B),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
    Color(0xFFEC4899),
  ];
  static const _bgTop = Color(0xFFF2F7F3);
  static const _bgBottom = Color(0xFFEFF6F1);
  static const _brandGreen = Color(0xFF00A86B);
  static const _brandGreenDark = Color(0xFF0A8F5B);

  bool _showAssetFab = true;
  int? _selectedSpotIndex;
  _WalletChartRange _selectedRange = _WalletChartRange.oneMonth;

  Color _assetColor(int index) => _chartColors[index % _chartColors.length];

  String _maskedMoney(double value, bool hidden) {
    if (hidden) {
      return '***';
    }
    return asMoney(value);
  }

  DateTime? _rangeStart(_WalletChartRange range, DateTime now) {
    switch (range) {
      case _WalletChartRange.oneDay:
        return now.subtract(const Duration(days: 1));
      case _WalletChartRange.oneMonth:
        return now.subtract(const Duration(days: 30));
      case _WalletChartRange.threeMonths:
        return now.subtract(const Duration(days: 90));
      case _WalletChartRange.ytd:
        return DateTime(now.year);
      case _WalletChartRange.oneYear:
        return DateTime(now.year - 1, now.month, now.day);
      case _WalletChartRange.threeYears:
        return DateTime(now.year - 3, now.month, now.day);
      case _WalletChartRange.fiveYears:
        return DateTime(now.year - 5, now.month, now.day);
      case _WalletChartRange.all:
        return null;
    }
  }

  List<NetWorthPoint> _filterHistoryByRange(List<NetWorthPoint> points) {
    if (points.isEmpty) {
      return points;
    }
    final sorted = [...points]..sort((a, b) => a.date.compareTo(b.date));
    final start = _rangeStart(_selectedRange, DateTime.now());
    if (start == null) {
      return sorted;
    }
    final filtered = sorted
        .where((point) => !point.date.isBefore(start))
        .toList(growable: false);
    return filtered.isEmpty ? [sorted.last] : filtered;
  }

  String _rangeLabel(_WalletChartRange range) {
    switch (range) {
      case _WalletChartRange.oneDay:
        return '1D';
      case _WalletChartRange.oneMonth:
        return '1M';
      case _WalletChartRange.threeMonths:
        return '3M';
      case _WalletChartRange.ytd:
        return 'YTD';
      case _WalletChartRange.oneYear:
        return '1Y';
      case _WalletChartRange.threeYears:
        return '3Y';
      case _WalletChartRange.fiveYears:
        return '5Y';
      case _WalletChartRange.all:
        return 'All';
    }
  }

  String _rangePeriodLabel(_WalletChartRange range) {
    switch (range) {
      case _WalletChartRange.oneDay:
        return '1 Hari';
      case _WalletChartRange.oneMonth:
        return '1 Bulan';
      case _WalletChartRange.threeMonths:
        return '3 Bulan';
      case _WalletChartRange.ytd:
        return 'YTD';
      case _WalletChartRange.oneYear:
        return '1 Tahun';
      case _WalletChartRange.threeYears:
        return '3 Tahun';
      case _WalletChartRange.fiveYears:
        return '5 Tahun';
      case _WalletChartRange.all:
        return 'All Time';
    }
  }

  Widget _buildRangeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _WalletChartRange.values
            .map((range) {
              final selected = range == _selectedRange;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedRange = range;
                      _selectedSpotIndex = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _rangeLabel(range),
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

  LineChartData _buildWalletChartData(
    List<NetWorthPoint> points, {
    required int selectedSpotIndex,
    required bool hideValues,
    required void Function(int? index) onSpotSelected,
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
      ),
      lineBarsData: [
        LineChartBarData(
          isCurved: true,
          color: _brandGreen,
          barWidth: 3,
          showingIndicators: [safeSelectedIndex],
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, barData) =>
                spot.x.toInt() == safeSelectedIndex,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
                  radius: 4.5,
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
                _brandGreen.withValues(alpha: 0.25),
                _brandGreen.withValues(alpha: 0.02),
              ],
            ),
          ),
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
    final hideValues = ref.watch(hideValuesProvider);
    final assetsAsync = ref.watch(walletAssetsProvider(widget.walletId));
    final walletHistoryAsync = ref.watch(
      walletValueHistoryProvider(widget.walletId),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.walletName),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showAssetFab = !_showAssetFab),
            tooltip: _showAssetFab ? 'Hide Add Asset' : 'Show Add Asset',
            icon: Icon(
              _showAssetFab
                  ? Icons.remove_circle_outline
                  : Icons.add_circle_outline,
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
        ],
      ),
      floatingActionButton: _showAssetFab
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditAssetScreen(walletId: widget.walletId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Asset'),
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, _showAssetFab ? 96 : 16),
          children: [
            assetsAsync.when(
              data: (assets) {
                final total = assets.fold<double>(
                  0,
                  (sum, asset) => sum + asset.totalValue,
                );
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [_brandGreen, _brandGreenDark],
                    ),
                  ),
                  child: Text(
                    'Wallet Total: ${_maskedMoney(total, hideValues)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 16),
            Text(
              'Wallet Value Trend',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            walletHistoryAsync.when(
              data: (points) {
                if (points.isEmpty) {
                  return const SizedBox.shrink();
                }
                final filteredPoints = _filterHistoryByRange(points);
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
                        _rangePeriodLabel(_selectedRange),
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
                  height: 230,
                  child: walletHistoryAsync.when(
                    data: (points) {
                      if (points.isEmpty) {
                        return const Center(child: Text('No history yet'));
                      }
                      final filteredPoints = _filterHistoryByRange(points);
                      final minPoint = filteredPoints.reduce(
                        (a, b) => a.value <= b.value ? a : b,
                      );
                      final maxPoint = filteredPoints.reduce(
                        (a, b) => a.value >= b.value ? a : b,
                      );
                      final safeIndex =
                          (_selectedSpotIndex != null &&
                              _selectedSpotIndex! < filteredPoints.length)
                          ? _selectedSpotIndex!
                          : filteredPoints.length - 1;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: LineChart(
                              _buildWalletChartData(
                                filteredPoints,
                                selectedSpotIndex: safeIndex,
                                hideValues: hideValues,
                                onSpotSelected: (index) {
                                  setState(() => _selectedSpotIndex = index);
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
            _buildRangeFilter(),
            const SizedBox(height: 16),
            Text(
              'Assets',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
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
                                walletId: widget.walletId,
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
                                      hideValues
                                          ? '***'
                                          : asWholeNumber(asset.totalValue),
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
