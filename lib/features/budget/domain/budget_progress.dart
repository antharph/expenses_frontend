import '../../expenses/domain/expense_category.dart';

class BudgetProgress {
  const BudgetProgress({
    required this.id,
    required this.budgetTypeId,
    required this.budgetTypeCode,
    required this.name,
    required this.resetType,
    required this.categories,
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
  final int budgetTypeId;
  final String budgetTypeCode;
  final String name;
  final String resetType;
  final List<ExpenseCategory> categories;
  final bool rolloverEnabled;
  final DateTime periodStart;
  final DateTime? periodEnd;
  final double? baseAmount;
  final double? rolloverAmount;
  final double? allocatedAmount;
  final double spentAmount;
  final double? remainingAmount;
  final bool isOverBudget;

  bool get isManual => resetType == 'manual';

  /// A tracking-only budget has no set limit (amount is null).
  bool get isTrackingOnly => baseAmount == null;

  double get progressFraction {
    final allocated = allocatedAmount;
    if (allocated == null || allocated <= 0) {
      return 0;
    }
    final remaining = remainingAmount ?? 0;
    return (remaining / allocated).clamp(0.0, 1.0);
  }

  factory BudgetProgress.fromJson(Map<String, dynamic> json) {
    final period = json['period'];
    final periodMap = period is Map<String, dynamic> ? period : const {};

    return BudgetProgress(
      id: json['id'] as int,
      budgetTypeId: json['budget_type_id'] as int? ?? 1,
      budgetTypeCode: json['budget_type_code']?.toString() ?? 'budget',
      name: json['name']?.toString() ?? '',
      resetType: json['reset_type']?.toString() ?? '',
      categories: _parseCategories(json['categories']),
      rolloverEnabled: json['rollover_enabled'] == true,
      periodStart: _parseDate(periodMap['start_date']) ?? DateTime.now(),
      periodEnd: _parseDate(periodMap['end_date']),
      baseAmount: _parseNullableAmount(json['base_amount']),
      rolloverAmount: _parseNullableAmount(json['rollover_amount']),
      allocatedAmount: _parseNullableAmount(json['allocated_amount']),
      spentAmount: _parseAmount(json['spent_amount']),
      remainingAmount: _parseNullableAmount(json['remaining_amount']),
      isOverBudget: json['is_over_budget'] == true,
    );
  }

  static double _parseAmount(Object? raw) =>
      double.tryParse(raw?.toString() ?? '') ?? 0;

  static double? _parseNullableAmount(Object? raw) {
    if (raw == null) {
      return null;
    }
    return double.tryParse(raw.toString());
  }

  static List<ExpenseCategory> _parseCategories(Object? raw) {
    if (raw is! List<dynamic>) {
      return const [];
    }
    return raw
        .map(
          (category) => ExpenseCategory.fromJson(
            Map<String, dynamic>.from(category as Map),
          ),
        )
        .where((category) => category.name.isNotEmpty)
        .toList();
  }

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
