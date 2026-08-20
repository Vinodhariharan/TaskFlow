import 'dart:convert';

enum ExpenseCategory { food, transport, shopping, bills, entertainment, health, other }

class Expense {
  final String id;
  String title;
  double amount;
  ExpenseCategory category;
  DateTime date;
  String? note;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  Expense copyWith({
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) {
    return Expense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category.index,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      category: ExpenseCategory
          .values[json['category'] as int? ?? ExpenseCategory.other.index],
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory Expense.fromJsonString(String jsonStr) =>
      Expense.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
