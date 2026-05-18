/// Sunday–Saturday weeks aligned with the API (`ExpenseWeek` on the backend).
///
/// Week 1 is the week that contains January 1 (its Sunday may fall in December).
class ExpenseWeekKey {
  const ExpenseWeekKey({required this.year, required this.week});

  final int year;
  final int week;

  @override
  bool operator ==(Object other) =>
      other is ExpenseWeekKey && other.year == year && other.week == week;

  @override
  int get hashCode => Object.hash(year, week);
}

abstract final class ExpenseWeek {
  ExpenseWeek._();

  static DateTime weekStart(int year, int week) {
    final jan1 = DateTime(year, 1, 1);
    final firstSunday = _sundayOnOrBefore(jan1);
    final start = firstSunday.add(Duration(days: 7 * (week - 1)));
    return DateTime(start.year, start.month, start.day);
  }

  static DateTime weekEnd(int year, int week) {
    final start = weekStart(year, week);
    return DateTime(start.year, start.month, start.day + 6);
  }

  static List<DateTime> daysInWeek(int year, int week) {
    final start = weekStart(year, week);
    return List.generate(
      7,
      (i) => DateTime(start.year, start.month, start.day + i),
    );
  }

  static int weeksInYear(int year) {
    final yearEnd = DateTime(year, 12, 31);
    for (var week = 52; week >= 1; week--) {
      if (!weekStart(year, week).isAfter(yearEnd)) {
        return week;
      }
    }
    return 1;
  }

  static ExpenseWeekKey previous(int year, int week) {
    if (week > 1) {
      return ExpenseWeekKey(year: year, week: week - 1);
    }
    final prevYear = year - 1;
    return ExpenseWeekKey(year: prevYear, week: weeksInYear(prevYear));
  }

  static ExpenseWeekKey next(int year, int week) {
    if (week < weeksInYear(year)) {
      return ExpenseWeekKey(year: year, week: week + 1);
    }
    return ExpenseWeekKey(year: year + 1, week: 1);
  }

  static ExpenseWeekKey weekContaining(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final weekSunday = _sundayOnOrBefore(day);

    for (final year in [weekSunday.year - 1, weekSunday.year, weekSunday.year + 1]) {
      if (year < 1) {
        continue;
      }
      final maxWeek = weeksInYear(year);
      for (var week = 1; week <= maxWeek; week++) {
        final start = weekStart(year, week);
        if (_sameCalendarDay(start, weekSunday)) {
          return ExpenseWeekKey(year: year, week: week);
        }
      }
    }

    return ExpenseWeekKey(year: day.year, week: 1);
  }

  static bool isCurrentCalendarWeek(int year, int week) {
    final current = weekContaining(DateTime.now());
    return current.year == year && current.week == week;
  }

  static DateTime _sundayOnOrBefore(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final daysFromSunday = day.weekday % 7;
    return day.subtract(Duration(days: daysFromSunday));
  }

  static bool _sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
