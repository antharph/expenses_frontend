class Expense {
  const Expense({
    required this.id,
    required this.item,
    required this.quantity,
    required this.price,
    required this.total,
    required this.dateIso,
    this.receiptUrl,
    this.categoryId,
    this.categoryName,
  });

  final int id;
  final String item;
  final int quantity;
  final String price;
  final String total;
  final String dateIso;
  final String? receiptUrl;
  final int? categoryId;
  final String? categoryName;

  factory Expense.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'];
    final id = idRaw is int ? idRaw : (idRaw as num).toInt();

    final quantityRaw = json['quantity'];
    final quantity = quantityRaw is int
        ? quantityRaw
        : (quantityRaw is num ? quantityRaw.toInt() : int.tryParse('$quantityRaw') ?? 1);

    return Expense(
      id: id,
      item: json['item'] as String,
      quantity: quantity,
      price: _decimalString(json['price']),
      total: _decimalString(json['total'] ?? json['price']),
      dateIso: json['date'] as String? ?? '',
      receiptUrl: json['receipt_url'] as String?,
      categoryId: _optionalInt(json['category_id']),
      categoryName: _categoryNameFromJson(json['category']),
    );
  }

  static String _decimalString(Object? raw) {
    if (raw is num) {
      return raw.toString();
    }
    return raw?.toString() ?? '0';
  }

  static int? _optionalInt(Object? raw) {
    if (raw == null) {
      return null;
    }
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    return int.tryParse(raw.toString());
  }

  static String? _categoryNameFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final name = raw['name'];
    if (name == null) {
      return null;
    }
    final trimmed = name.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
