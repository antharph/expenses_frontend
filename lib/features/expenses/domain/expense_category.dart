class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
  });

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
