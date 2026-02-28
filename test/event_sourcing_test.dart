import 'package:flutter_test/flutter_test.dart';

import 'package:fiapp/core/event_sourcing.dart';

void main() {
  test('quantity calculation sums deltas and treats null as zero', () {
    final quantity = EventMath.currentQuantity([10, null, -3, 5]);
    expect(quantity, 12);
  });

  test('price retrieval picks latest non-null price from descending series', () {
    final price = EventMath.currentPrice([null, 120, 110, null]);
    expect(price, 120);
  });

  test('total value computation is quantity multiplied by price', () {
    final total = EventMath.totalValue(quantity: 15, price: 110);
    expect(total, 1650);
  });

  test('edit diff emits adjustment and price update only for changed fields', () {
    final diff = EventMath.editDiff(
      oldQuantity: 10,
      oldPrice: 100,
      newQuantity: 15,
      newPrice: 120,
    );

    expect(diff.quantityDelta, 5);
    expect(diff.newPrice, 120);

    final unchanged = EventMath.editDiff(
      oldQuantity: 5,
      oldPrice: 80,
      newQuantity: 5,
      newPrice: 80,
    );

    expect(unchanged.quantityDelta, isNull);
    expect(unchanged.newPrice, isNull);
  });
}
