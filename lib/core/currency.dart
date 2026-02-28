const kSupportedCurrencies = <String>['IDR', 'USD', 'SGD'];

class CurrencySettings {
  const CurrencySettings({
    required this.mainCurrency,
    required this.usdToIdrRate,
    required this.sgdToIdrRate,
  });

  final String mainCurrency;
  final double usdToIdrRate;
  final double sgdToIdrRate;

  CurrencySettings copyWith({
    String? mainCurrency,
    double? usdToIdrRate,
    double? sgdToIdrRate,
  }) {
    return CurrencySettings(
      mainCurrency: mainCurrency ?? this.mainCurrency,
      usdToIdrRate: usdToIdrRate ?? this.usdToIdrRate,
      sgdToIdrRate: sgdToIdrRate ?? this.sgdToIdrRate,
    );
  }

  static const defaults = CurrencySettings(
    mainCurrency: 'IDR',
    usdToIdrRate: 16000,
    sgdToIdrRate: 12000,
  );
}

double convertCurrency(
  double amount, {
  required String from,
  required String to,
  required CurrencySettings settings,
}) {
  final source = from.toUpperCase();
  final target = to.toUpperCase();
  if (source == target) {
    return amount;
  }

  double toIdr(double value, String currency) {
    if (currency == 'IDR') {
      return value;
    }
    if (currency == 'USD') {
      return value * settings.usdToIdrRate;
    }
    if (currency == 'SGD') {
      return value * settings.sgdToIdrRate;
    }
    return value;
  }

  double fromIdr(double idrValue, String currency) {
    if (currency == 'IDR') {
      return idrValue;
    }
    if (currency == 'USD') {
      return idrValue / settings.usdToIdrRate;
    }
    if (currency == 'SGD') {
      return idrValue / settings.sgdToIdrRate;
    }
    return idrValue;
  }

  final inIdr = toIdr(amount, source);
  return fromIdr(inIdr, target);
}
