class BudgetProgress {
  const BudgetProgress({
    required this.id,
    required this.name,
    required this.rolloverEnabled,
    required this.periodStart,
    required this.periodEnd,
    required this.baseAmount,
    required this.rolloverAmount,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.remainingAmount,
    required this.isOverBudget,
  });

  final int id;
  final String name;
  final bool rolloverEnabled;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final double baseAmount;
  final double rolloverAmount;
  final double allocatedAmount;
  final double spentAmount;
  final double remainingAmount;
  final bool isOverBudget;

  double get progressFraction {
    if (allocatedAmount <= 0) {
      return spentAmount > 0 ? 1 : 0;
    }
    return (spentAmount / allocatedAmount).clamp(0.0, 1.0);
  }

  factory BudgetProgress.fromJson(Map<String, dynamic> json) {
    final period = json['period'];
    final periodMap = period is Map<String, dynamic> ? period : const {};

    return BudgetProgress(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      rolloverEnabled: json['rollover_enabled'] == true,
      periodStart: _parseDate(periodMap['start_date']) ?? DateTime.now(),
      periodEnd: _parseDate(periodMap['end_date']),
      baseAmount: _parseAmount(json['base_amount']),
      rolloverAmount: _parseAmount(json['rollover_amount']),
      allocatedAmount: _parseAmount(json['allocated_amount']),
      spentAmount: _parseAmount(json['spent_amount']),
      remainingAmount: _parseAmount(json['remaining_amount']),
      isOverBudget: json['is_over_budget'] == true,
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
