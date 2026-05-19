class BudgetLogEntry {
  const BudgetLogEntry({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.rolloverAmount,
  });

  final int id;
  final DateTime startDate;
  final DateTime? endDate;
  final double allocatedAmount;
  final double spentAmount;
  final double rolloverAmount;

  factory BudgetLogEntry.fromJson(Map<String, dynamic> json) {
    return BudgetLogEntry(
      id: json['id'] as int,
      startDate: _parseDate(json['start_date']) ?? DateTime.now(),
      endDate: _parseDate(json['end_date']),
      allocatedAmount: _parseAmount(json['allocated_amount']),
      spentAmount: _parseAmount(json['spent_amount']),
      rolloverAmount: _parseAmount(json['rollover_amount']),
    );
  }

  static double _parseAmount(Object? raw) =>
      double.tryParse(raw?.toString() ?? '') ?? 0;

  static DateTime? _parseDate(Object? raw) {
    if (raw == null) {
      return null;
    }
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
