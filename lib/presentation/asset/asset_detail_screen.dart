import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/database/app_database.dart';
import '../../domain/models.dart';
import '../../providers/app_providers.dart';
import 'add_edit_asset_screen.dart';

class AssetDetailScreen extends ConsumerWidget {
  const AssetDetailScreen({
    super.key,
    required this.assetId,
    required this.walletId,
  });

  final String assetId;
  final String walletId;

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
    String currency,
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
        return (
          metric: 'Price',
          value: asMoney(currentPrice, currency: currency),
          direction: 0,
        );
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
        color: const Color(0xFF15803D),
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

  LineChartData _buildHistoryChartData(
    List<AssetValuePoint> points,
    String currency,
  ) {
    final fixedPoints = points.length == 1
        ? [
            points.first,
            AssetValuePoint(
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
  Widget build(BuildContext context, WidgetRef ref) {
    final assetAsync = ref.watch(assetProvider(assetId));
    final snapshotAsync = ref.watch(
      assetSnapshotProvider((walletId: walletId, assetId: assetId)),
    );
    final eventsAsync = ref.watch(assetEventsProvider(assetId));
    final historyAsync = ref.watch(assetValueHistoryProvider(assetId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AddEditAssetScreen(walletId: walletId, assetId: assetId),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
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
                  Text(
                    'Total Value: ${asMoney(total, currency: asset.currency)}',
                    style: Theme.of(context).textTheme.titleMedium,
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
                                  Text(asWholeNumber(qty)),
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
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(asMoney(price, currency: asset.currency)),
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
          const Text('Value Over Time'),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: historyAsync.when(
              data: (points) {
                final currency = assetAsync.asData?.value?.currency ?? 'IDR';
                if (points.isEmpty) {
                  return const Center(child: Text('No history yet'));
                }
                return LineChart(_buildHistoryChartData(points, currency));
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Events'),
          const SizedBox(height: 8),
          eventsAsync.when(
            data: (events) {
              final currency = assetAsync.asData?.value?.currency ?? 'IDR';
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
                      final metric = _eventMetric(
                        events,
                        index,
                        showQty,
                        currency,
                      );
                      final directionUi = _directionUi(metric.direction);

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    metric.value,
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
    );
  }
}
