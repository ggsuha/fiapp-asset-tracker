import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import 'add_edit_asset_screen.dart';

enum _ChartRange {
  oneDay,
  oneMonth,
  threeMonths,
  ytd,
  oneYear,
  threeYears,
  fiveYears,
  all,
}

class AssetDetailScreen extends ConsumerStatefulWidget {
  const AssetDetailScreen({
    super.key,
    required this.assetId,
    required this.walletId,
  });

  final String assetId;
  final String walletId;

  @override
  ConsumerState<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends ConsumerState<AssetDetailScreen> {
  static const _brandGreen = Color(0xFF00A86B);
  static const _brandGreenDark = Color(0xFF0A8F5B);
  static const _bgTop = Color(0xFFF2F7F3);
  static const _bgBottom = Color(0xFFEFF6F1);

  _ChartRange _selectedRange = _ChartRange.oneMonth;
  int? _selectedSpotIndex;

  bool _showQuantity(AssetType type) {
    return type != AssetType.cash;
  }

  String _signedWhole(double value) {
    final abs = asWholeNumber(value.abs());
    if (value > 0) {
      return '+$abs';
    }
    if (value < 0) {
      return '-$abs';
    }
    return abs;
  }

  ({String metric, String value, int direction}) _eventMetric(
    List<AssetEvent> events,
    int index,
    bool showQty,
  ) {
    final event = events[index];
    if (event.quantityDelta != null) {
      final delta = event.quantityDelta!;
      return (
        metric: showQty ? 'Quantity' : 'Amount',
        value: _signedWhole(delta),
        direction: delta > 0 ? 1 : (delta < 0 ? -1 : 0),
      );
    }

    if (event.pricePerUnit != null) {
      final currentPrice = event.pricePerUnit!;
      double? previousPrice;
      for (var i = index + 1; i < events.length; i++) {
        if (events[i].pricePerUnit != null) {
          previousPrice = events[i].pricePerUnit!;
          break;
        }
      }

      if (previousPrice == null) {
        return (metric: 'Price', value: asMoney(currentPrice), direction: 0);
      }

      final delta = currentPrice - previousPrice;
      return (
        metric: 'Price',
        value: _signedWhole(delta),
        direction: delta > 0 ? 1 : (delta < 0 ? -1 : 0),
      );
    }

    return (metric: 'Change', value: '-', direction: 0);
  }

  ({IconData icon, Color color, String label}) _directionUi(int direction) {
    if (direction > 0) {
      return (
        icon: Icons.trending_up,
        color: _brandGreenDark,
        label: 'Increase',
      );
    }
    if (direction < 0) {
      return (
        icon: Icons.trending_down,
        color: const Color(0xFFB91C1C),
        label: 'Decrease',
      );
    }
    return (icon: Icons.drag_handle, color: Colors.grey, label: 'No change');
  }

  String _maskedMoney(double value, bool hidden) {
    if (hidden) {
      return '***';
    }
    return asMoney(value);
  }

  String _maskedNumber(double value, bool hidden) {
    if (hidden) {
      return '***';
    }
    return asWholeNumber(value);
  }

  LineChartData _buildHistoryChartData(
    List<AssetValuePoint> points, {
    required int selectedSpotIndex,
    required void Function(int? index) onSpotSelected,
    required bool hideValues,
  }) {
    final fixedPoints = points.length == 1
        ? [
            points.first,
            AssetValuePoint(
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
          barWidth: 3,
          showingIndicators: [safeSelectedIndex],
          spots: [
            for (var i = 0; i < fixedPoints.length; i++)
              FlSpot(i.toDouble(), fixedPoints[i].value),
          ],
        ),
      ],
    );
  }

  DateTime? _rangeStart(_ChartRange range, DateTime now) {
    switch (range) {
      case _ChartRange.oneDay:
        return now.subtract(const Duration(days: 1));
      case _ChartRange.oneMonth:
        return now.subtract(const Duration(days: 30));
      case _ChartRange.threeMonths:
        return now.subtract(const Duration(days: 90));
      case _ChartRange.ytd:
        return DateTime(now.year);
      case _ChartRange.oneYear:
        return DateTime(now.year - 1, now.month, now.day);
      case _ChartRange.threeYears:
        return DateTime(now.year - 3, now.month, now.day);
      case _ChartRange.fiveYears:
        return DateTime(now.year - 5, now.month, now.day);
      case _ChartRange.all:
        return null;
    }
  }

  List<AssetValuePoint> _filterHistoryByRange(List<AssetValuePoint> points) {
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

  String _rangeLabel(_ChartRange range) {
    switch (range) {
      case _ChartRange.oneDay:
        return '1D';
      case _ChartRange.oneMonth:
        return '1M';
      case _ChartRange.threeMonths:
        return '3M';
      case _ChartRange.ytd:
        return 'YTD';
      case _ChartRange.oneYear:
        return '1Y';
      case _ChartRange.threeYears:
        return '3Y';
      case _ChartRange.fiveYears:
        return '5 Y';
      case _ChartRange.all:
        return 'All';
    }
  }

  String _rangePeriodLabel(_ChartRange range) {
    switch (range) {
      case _ChartRange.oneDay:
        return '1 Hari';
      case _ChartRange.oneMonth:
        return '1 Bulan';
      case _ChartRange.threeMonths:
        return '3 Bulan';
      case _ChartRange.ytd:
        return 'YTD';
      case _ChartRange.oneYear:
        return '1 Tahun';
      case _ChartRange.threeYears:
        return '3 Tahun';
      case _ChartRange.fiveYears:
        return '5 Tahun';
      case _ChartRange.all:
        return 'All Time';
    }
  }

  Widget _buildRangeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _ChartRange.values
            .map((range) {
              final selected = range == _selectedRange;
              return Padding(
                padding: const EdgeInsets.only(right: 18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _selectedRange = range;
                      _selectedSpotIndex = null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
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
                                : Colors.grey.shade700,
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

  @override
  Widget build(BuildContext context) {
    final assetAsync = ref.watch(assetProvider(widget.assetId));
    final snapshotAsync = ref.watch(
      assetSnapshotProvider((
        walletId: widget.walletId,
        assetId: widget.assetId,
      )),
    );
    final hideValues = ref.watch(hideValuesProvider);
    final eventsAsync = ref.watch(assetEventsProvider(widget.assetId));
    final historyAsync = ref.watch(assetValueHistoryProvider(widget.assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Detail'),
        actions: [
          IconButton(
            onPressed: () => ref.read(hideValuesProvider.notifier).toggle(),
            tooltip: hideValues ? 'Show Values' : 'Hide Values',
            icon: Icon(
              hideValues
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditAssetScreen(
                    walletId: widget.walletId,
                    assetId: widget.assetId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            assetAsync.when(
              data: (asset) {
                if (asset == null) {
                  return const Text('Unknown Asset');
                }
                final type = AssetType.fromDb(asset.type);
                final showQty = _showQuantity(type);
                final snapshot = snapshotAsync.asData?.value;
                final qty = snapshot?.currentQuantity ?? 0;
                final price = snapshot?.currentPrice ?? 0;
                final total = snapshot?.totalValue ?? 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [_brandGreen, _brandGreenDark],
                        ),
                      ),
                      child: Text(
                        'Total Value: ${_maskedMoney(total, hideValues)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showQty) ...[
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quantity',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_maskedNumber(qty, hideValues)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Price',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_maskedMoney(price, hideValues)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 20),
            Text(
              'Value',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            historyAsync.when(
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
                        '$trendPrefix${asMoney(netDiff.abs())} ($trendPrefix${netDiffPct.abs().toStringAsFixed(2)}%)',
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
                  height: 248,
                  child: historyAsync.when(
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
                              _buildHistoryChartData(
                                filteredPoints,
                                selectedSpotIndex: safeIndex,
                                hideValues: hideValues,
                                onSpotSelected: (index) {
                                  setState(() {
                                    _selectedSpotIndex = index;
                                  });
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Text(
                              asMoney(maxPoint.value),
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
                              asMoney(minPoint.value),
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
            const SizedBox(height: 20),
            Text(
              'Events',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            eventsAsync.when(
              data: (events) {
                final showQty = _showQuantity(
                  AssetType.fromDb(
                    assetAsync.asData?.value?.type ?? AssetType.custom.dbValue,
                  ),
                );

                if (events.isEmpty) {
                  return const Text('No events yet');
                }
                return Column(
                  children: events
                      .asMap()
                      .entries
                      .map((entry) {
                        final index = entry.key;
                        final event = entry.value;
                        final metric = _eventMetric(events, index, showQty);
                        final directionUi = _directionUi(metric.direction);

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        asCompactDate(event.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey.shade700,
                                            ),
                                      ),
                                      if (event.note != null &&
                                          event.note!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          event.note!,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      metric.metric,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      hideValues ? '***' : metric.value,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          directionUi.icon,
                                          size: 14,
                                          color: directionUi.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          directionUi.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: directionUi.color,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      })
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
