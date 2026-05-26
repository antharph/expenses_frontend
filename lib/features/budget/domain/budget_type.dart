class BudgetType {
  const BudgetType({
    required this.id,
    required this.code,
    required this.name,
  });

  final int id;
  final String code;
  final String name;

  factory BudgetType.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int ? idRaw : (idRaw as num).toInt();

    return BudgetType(
      id: id,
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}
