import 'package:intl/intl.dart';

final _eur = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);
final _eur0 = NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 0);
final _dayMonth = DateFormat('d MMM', 'fr_FR');
final _fullDate = DateFormat('EEEE d MMMM', 'fr_FR');
final _monthYear = DateFormat('MMMM yyyy', 'fr_FR');
final _time = DateFormat('HH:mm', 'fr_FR');

class Fmt {
  static String euro(num v) => _eur.format(v);
  static String euro0(num v) => _eur0.format(v);
  static String dayMonth(DateTime d) => _dayMonth.format(d);
  static String fullDate(DateTime d) => _capitalize(_fullDate.format(d));
  static String monthYear(DateTime d) => _capitalize(_monthYear.format(d));
  static String time(DateTime d) => _time.format(d);

  static String duration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
