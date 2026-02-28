class EventMath {
  static const _eps = 1e-9;
  static double currentQuantity(Iterable<double?> quantityDeltas) {
    return quantityDeltas.fold<double>(0, (sum, value) => sum + (value ?? 0));
  }

  static double currentPrice(Iterable<double?> priceSeries) {
    for (final price in priceSeries) {
      if (price != null) {
        return price;
      }
    }
    return 0;
  }

  static double totalValue({required double quantity, required double price}) {
    return quantity * price;
  }

  static ({double? quantityDelta, double? newPrice}) editDiff({
    required double oldQuantity,
    required double oldPrice,
    required double newQuantity,
    required double newPrice,
  }) {
    final quantityDelta = newQuantity - oldQuantity;
    return (
      quantityDelta: quantityDelta.abs() < _eps ? null : quantityDelta,
      newPrice: (newPrice - oldPrice).abs() < _eps ? null : newPrice,
    );
  }
}
