import 'dart:convert';
import 'package:flutter/material.dart';

/// Curated, fixed icon choices for task categories — written as literal
/// `Icons.*` references so Flutter's icon tree-shaker keeps them in release
/// builds (an IconData rebuilt at runtime from a stored codePoint gets
/// shaken out and renders blank). Kept separate from the expense category
/// icon set since these are task-appropriate (work, errands, calls, …)
/// rather than spending-appropriate.
const List<IconData> kTaskCategoryIconChoices = [
  Icons.work_outline_rounded,
  Icons.person_outline_rounded,
  Icons.favorite_border_rounded,
  Icons.home_outlined,
  Icons.shopping_cart_outlined,
  Icons.more_horiz_rounded,
  Icons.school_outlined,
  Icons.fitness_center_rounded,
  Icons.groups_outlined,
  Icons.flight_outlined,
  Icons.call_outlined,
  Icons.build_outlined,
  Icons.pets_outlined,
  Icons.local_hospital_outlined,
  Icons.celebration_outlined,
  Icons.savings_outlined,
  Icons.directions_car_outlined,
  Icons.restaurant_outlined,
  Icons.book_outlined,
  Icons.spa_outlined,
];

/// Kept as its own list (rather than importing the expense one) so task
/// and expense categories stay fully independent domains.
const List<Color> kTaskCategoryColorChoices = [
  Color(0xFF6C63FF),
  Color(0xFFFF9F5A),
  Color(0xFF5AB4FF),
  Color(0xFFFF6584),
  Color(0xFFFFD166),
  Color(0xFFB388FF),
  Color(0xFF4CD9A0),
  Color(0xFF9090A8),
  Color(0xFF4CAF93),
  Color(0xFFFF7A7A),
];

class TaskCategory {
  final String id;
  final String label;
  final int iconIndex;
  final int colorIndex;
  final bool isBuiltIn;

  const TaskCategory({
    required this.id,
    required this.label,
    required this.iconIndex,
    required this.colorIndex,
    this.isBuiltIn = false,
  });

  IconData get icon => kTaskCategoryIconChoices[
      iconIndex.clamp(0, kTaskCategoryIconChoices.length - 1)];
  Color get color => kTaskCategoryColorChoices[
      colorIndex.clamp(0, kTaskCategoryColorChoices.length - 1)];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconIndex': iconIndex,
        'colorIndex': colorIndex,
      };

  factory TaskCategory.fromJson(Map<String, dynamic> json) => TaskCategory(
        id: json['id'] as String,
        label: json['label'] as String,
        iconIndex: json['iconIndex'] as int,
        colorIndex: json['colorIndex'] as int,
      );

  String toJsonString() => jsonEncode(toJson());
  factory TaskCategory.fromJsonString(String s) =>
      TaskCategory.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

const List<TaskCategory> kBuiltInTaskCategories = [
  TaskCategory(id: 'work', label: 'Work', iconIndex: 0, colorIndex: 0, isBuiltIn: true),
  TaskCategory(id: 'personal', label: 'Personal', iconIndex: 1, colorIndex: 1, isBuiltIn: true),
  TaskCategory(id: 'health', label: 'Health', iconIndex: 2, colorIndex: 3, isBuiltIn: true),
  TaskCategory(id: 'home', label: 'Home', iconIndex: 3, colorIndex: 2, isBuiltIn: true),
  TaskCategory(id: 'errands', label: 'Errands', iconIndex: 4, colorIndex: 4, isBuiltIn: true),
  TaskCategory(id: 'other', label: 'Other', iconIndex: 5, colorIndex: 7, isBuiltIn: true),
];

const TaskCategory kFallbackTaskCategory = TaskCategory(
    id: 'other', label: 'Other', iconIndex: 5, colorIndex: 7, isBuiltIn: true);
