class Expense {
  const Expense({
    required this.id,
    required this.item,
    required this.price,
    required this.dateIso,
    this.receiptUrl,
  });

  final int id;
  final String item;
  final String price;
  final String dateIso;
  final String? receiptUrl;

  factory Expense.fromJson(Map<String, dynamic> json) {
    final priceRaw = json['price'];
    final price = priceRaw is num ? priceRaw.toString() : priceRaw.toString();

    final idRaw = json['id'];
    final id = idRaw is int ? idRaw : (idRaw as num).toInt();

    return Expense(
      id: id,
      item: json['item'] as String,
      price: price,
      dateIso: json['date'] as String? ?? '',
      receiptUrl: json['receipt_url'] as String?,
    );
  }
}
