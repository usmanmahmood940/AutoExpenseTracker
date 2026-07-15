import 'package:intl/intl.dart';

String formatMoney(num amount, {String currency = 'PKR'}) {
  return NumberFormat.currency(
    symbol: '$currency ',
    decimalDigits: 2,
  ).format(amount);
}

String formatAmount(num amount) => amount.toStringAsFixed(2);
