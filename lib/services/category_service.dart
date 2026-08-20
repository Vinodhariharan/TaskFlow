import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';

/// Built-in categories + user-created custom ones, persisted separately.
class CategoryService extends ChangeNotifier {
  CategoryService._();
  static final CategoryService instance = CategoryService._();

  static const _customCategoriesKey = 'custom_categories_v1';
  static const _uuid = Uuid();

  List<Tag> _custom = [];
  bool _loaded = false;

  List<Tag> get all => [...kBuiltInCategories, ..._custom];
  List<Tag> get custom => List.unmodifiable(_custom);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_customCategoriesKey) ?? [];
    _custom = raw.map((s) => Tag.fromJsonString(s)).toList();
    _loaded = true;
    notifyListeners();
  }

  Tag getById(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return kFallbackCategory;
  }

  Future<Tag> addCustomCategory({
    required String label,
    required int iconIndex,
    required int colorIndex,
  }) async {
    final category = Tag(
      id: 'custom_${_uuid.v4()}',
      label: label,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
    );
    _custom.add(category);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _customCategoriesKey, _custom.map((c) => c.toJsonString()).toList());
    return category;
  }
}
