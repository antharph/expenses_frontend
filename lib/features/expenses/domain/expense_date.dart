import 'expense.dart';

/// Parses an expense [dateIso] string into a local calendar date.
DateTime? expenseLocalDay(String raw, {DateTime? referenceNow}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final iso = DateTime.tryParse(trimmed);
  if (iso != null) {
    final local = iso.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  final reference = referenceNow ?? DateTime.now();
  final parts = trimmed.split('/');
  if (parts.length != 2) {
    return null;
  }
  final month = int.tryParse(parts[0].trim());
  final day = int.tryParse(parts[1].trim());
  if (month == null ||
      day == null ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31) {
    return null;
  }

  var year = reference.year;
  var candidate = DateTime(year, month, day);
  if (candidate.isAfter(reference)) {
    year -= 1;
    candidate = DateTime(year, month, day);
  }
  return DateTime(candidate.year, candidate.month, candidate.day);
}

bool expenseMatchesDateRange(
  String dateIso, {
  DateTime? rangeStart,
  DateTime? rangeEnd,
}) {
  if (rangeStart == null && rangeEnd == null) {
    return true;
  }
  final day = expenseLocalDay(dateIso);
  if (day == null) {
    return false;
  }
  if (rangeStart != null && day.isBefore(rangeStart)) {
    return false;
  }
  if (rangeEnd != null && day.isAfter(rangeEnd)) {
    return false;
  }
  return true;
}

double sumExpenseTotals(Iterable<Expense> expenses) {
  return expenses.fold<double>(
    0,
    (sum, e) => sum + (double.tryParse(e.total) ?? 0),
  );
}
