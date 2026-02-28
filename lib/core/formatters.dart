String asMoney(double value, {String currency = 'IDR'}) {
  return '${currency.toUpperCase()} ${value.toStringAsFixed(0)}';
}

String asCompactDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String asWholeNumber(double value) {
  return value.toStringAsFixed(0);
}
