import 'dart:convert';
import 'category.dart';

class Expense {
  final String id;
  String title;
  double amount;
  String categoryId;
  DateTime date;
  String? note;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
  });

  Expense copyWith({
    String? title,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? note,
    bool clearNote = false,
  }) {
    return Expense(
      id: id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'categoryId': categoryId,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    String categoryId;
    final storedId = json['categoryId'] as String?;
    if (storedId != null) {
      categoryId = storedId;
    } else {
      // Legacy data stored the built-in category as an enum index (0-6).
      final oldIndex = json['category'] as int? ?? kBuiltInCategories.length - 1;
      categoryId =
          kBuiltInCategories[oldIndex.clamp(0, kBuiltInCategories.length - 1)]
              .id;
    }
    return Expense(
      id: json['id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      categoryId: categoryId,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());
  factory Expense.fromJsonString(String jsonStr) =>
      Expense.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
