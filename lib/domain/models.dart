enum AssetType {
  cash('CASH'),
  gold('GOLD'),
  stock('STOCK'),
  mutualFund('MUTUAL_FUND'),
  custom('CUSTOM');

  const AssetType(this.dbValue);
  final String dbValue;

  static AssetType fromDb(String value) {
    return AssetType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => AssetType.custom,
    );
  }
}

enum AssetEventType {
  buy('BUY'),
  sell('SELL'),
  adjustment('ADJUSTMENT'),
  priceUpdate('PRICE_UPDATE');

  const AssetEventType(this.dbValue);
  final String dbValue;

  static AssetEventType fromDb(String value) {
    return AssetEventType.values.firstWhere(
      (type) => type.dbValue == value,
      orElse: () => AssetEventType.adjustment,
    );
  }
}

class AssetSnapshot {
  const AssetSnapshot({
    required this.assetId,
    required this.name,
    required this.type,
    required this.currency,
    required this.currentQuantity,
    required this.currentPrice,
  });

  final String assetId;
  final String name;
  final AssetType type;
  final String currency;
  final double currentQuantity;
  final double currentPrice;

  double get totalValue => currentQuantity * currentPrice;
}

class WalletSummary {
  const WalletSummary({
    required this.walletId,
    required this.name,
    required this.currency,
    required this.totalValue,
  });

  final String walletId;
  final String name;
  final String currency;
  final double totalValue;
}

class NetWorthPoint {
  const NetWorthPoint({
    required this.date,
    required this.value,
  });

  final DateTime date;
  final double value;
}

class AssetValuePoint {
  const AssetValuePoint({
    required this.date,
    required this.value,
  });

  final DateTime date;
  final double value;
}
