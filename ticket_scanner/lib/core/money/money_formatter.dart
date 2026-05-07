import 'package:intl/intl.dart';

class MoneyFormatter {
  const MoneyFormatter._();

  static String formatAmount(
    double amount,
    String currencyCode, {
    String locale = 'fr_FR',
  }) {
    final format = NumberFormat.simpleCurrency(
      name: currencyCode,
      locale: locale,
    );
    return format.format(amount);
  }
}

