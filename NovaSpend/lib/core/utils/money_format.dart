import 'package:intl/intl.dart';

import '../constants/currencies.dart';

String formatMoney(
  num amount, {
  String currency = kDefaultCurrency,
  bool showDecimals = true,
}) {
  return NumberFormat.currency(
    symbol: '$currency ',
    decimalDigits: showDecimals ? 2 : 0,
  ).format(amount);
}

String formatAmount(num amount) => amount.toStringAsFixed(2);
