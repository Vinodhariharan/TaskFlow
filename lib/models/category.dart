import 'dart:convert';
import 'package:flutter/material.dart';

/// Curated, fixed icon choices for categories — written as literal `Icons.*`
/// references so Flutter's icon tree-shaker keeps them in release builds.
/// An IconData rebuilt at runtime from a stored codePoint would get shaken
/// out of the font and render blank, so custom categories pick from this
/// fixed list (stored as an index) rather than an arbitrary icon.
const List<IconData> kCategoryIconChoices = [
  Icons.restaurant_rounded,
  Icons.directions_car_filled_rounded,
  Icons.shopping_bag_rounded,
  Icons.receipt_long_rounded,
  Icons.movie_rounded,
  Icons.favorite_rounded,
  Icons.more_horiz_rounded,
  Icons.home_rounded,
  Icons.flight_takeoff_rounded,
  Icons.school_rounded,
  Icons.pets_rounded,
  Icons.fitness_center_rounded,
  Icons.coffee_rounded,
  Icons.local_bar_rounded,
  Icons.spa_rounded,
  Icons.build_rounded,
  Icons.celebration_rounded,
  Icons.card_giftcard_rounded,
  Icons.local_gas_station_rounded,
  Icons.phone_iphone_rounded,
  Icons.subscriptions_rounded,
  Icons.child_care_rounded,
  Icons.medical_services_rounded,
  Icons.savings_rounded,
];

const List<Color> kCategoryColorChoices = [
  Color(0xFFFF9F5A),
  Color(0xFF5AB4FF),
  Color(0xFFFF6584),
  Color(0xFFFFD166),
  Color(0xFFB388FF),
  Color(0xFF4CD9A0),
  Color(0xFF9090A8),
  Color(0xFF4CAF93),
  Color(0xFFFF7A7A),
  Color(0xFF6C63FF),
];

class Tag {
  final String id;
  final String label;
  final int iconIndex;
  final int colorIndex;
  final bool isBuiltIn;

  const Tag({
    required this.id,
    required this.label,
    required this.iconIndex,
    required this.colorIndex,
    this.isBuiltIn = false,
  });

  IconData get icon => kCategoryIconChoices[
      iconIndex.clamp(0, kCategoryIconChoices.length - 1)];
  Color get color => kCategoryColorChoices[
      colorIndex.clamp(0, kCategoryColorChoices.length - 1)];

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'iconIndex': iconIndex,
        'colorIndex': colorIndex,
      };

  factory Tag.fromJson(Map<String, dynamic> json) => Tag(
        id: json['id'] as String,
        label: json['label'] as String,
        iconIndex: json['iconIndex'] as int,
        colorIndex: json['colorIndex'] as int,
      );

  String toJsonString() => jsonEncode(toJson());
  factory Tag.fromJsonString(String s) =>
      Tag.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Fixed ids so old data (which stored a category as an enum index 0-6 in
/// this exact order) can be migrated deterministically — see
/// Expense.fromJson.
const List<Tag> kBuiltInCategories = [
  Tag(id: 'food', label: 'Food', iconIndex: 0, colorIndex: 0, isBuiltIn: true),
  Tag(id: 'transport', label: 'Transport', iconIndex: 1, colorIndex: 1, isBuiltIn: true),
  Tag(id: 'shopping', label: 'Shopping', iconIndex: 2, colorIndex: 2, isBuiltIn: true),
  Tag(id: 'bills', label: 'Bills', iconIndex: 3, colorIndex: 3, isBuiltIn: true),
  Tag(id: 'entertainment', label: 'Entertainment', iconIndex: 4, colorIndex: 4, isBuiltIn: true),
  Tag(id: 'health', label: 'Health', iconIndex: 5, colorIndex: 5, isBuiltIn: true),
  Tag(id: 'other', label: 'Other', iconIndex: 6, colorIndex: 6, isBuiltIn: true),
];

const Tag kFallbackCategory = Tag(
    id: 'other', label: 'Other', iconIndex: 6, colorIndex: 6, isBuiltIn: true);
