String _asDottedThousands(double value) {
  final whole = value.round().abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < whole.length; i++) {
    final reversedIndex = whole.length - i;
    buffer.write(whole[i]);
    if (reversedIndex > 1 && reversedIndex % 3 == 1) {
      buffer.write('.');
    }
  }

  return '${value < 0 ? '-' : ''}$buffer';
}

String asMoney(double value, {String currency = 'IDR'}) {
  return 'IDR ${_asDottedThousands(value)}';
}

String asCompactDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String asWholeNumber(double value) {
  return _asDottedThousands(value);
}
