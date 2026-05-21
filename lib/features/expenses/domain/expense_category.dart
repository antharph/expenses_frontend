class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
  });

  static const defaultName = 'Miscellaneous';

  final int id;
  final String name;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int ? idRaw : (idRaw as num).toInt();

    return ExpenseCategory(
      id: id,
      name: json['name'] as String? ?? '',
    );
  }
}

/// Resolves the default category id (Miscellaneous) from an API list.
int? defaultExpenseCategoryId(List<ExpenseCategory> categories) {
  for (final category in categories) {
    if (category.name.toLowerCase() == ExpenseCategory.defaultName.toLowerCase()) {
      return category.id;
    }
  }
  return null;
}
