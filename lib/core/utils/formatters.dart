import 'package:intl/intl.dart';

/// Currency and date formatting utilities.
abstract class Formatters {
  /// Formats an integer amount in cents to a currency string.
  /// e.g. 150050 → "$1,500.50"
  static String currency(int cents, {String symbol = '\$'}) {
    final amount = cents / 100;
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Formats a double amount to a currency string.
  static String currencyFromDouble(double amount, {String symbol = '\$'}) {
    final formatter = NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Formats a compact number (e.g. 1500000 → "1.5M").
  static String compact(num value) {
    return NumberFormat.compact().format(value);
  }

  /// Formats a [DateTime] as "Mar 28, 2026".
  static String dateShort(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Formats a [DateTime] as "28 Mar".
  static String dateDayMonth(DateTime date) {
    return DateFormat('d MMM').format(date);
  }

  /// Formats a [DateTime] as "March 2026".
  static String dateMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Formats a percentage value.
  static String percent(double value, {int decimals = 2}) {
    return '${value >= 0 ? '+' : ''}${value.toStringAsFixed(decimals)}%';
  }
}
