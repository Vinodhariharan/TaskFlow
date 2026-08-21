import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';

/// Built-in categories + user-created custom ones, persisted separately.
/// Built-in categories can be renamed/re-iconed/re-colored (as an override
/// keyed by their fixed id) but never deleted — they stay a stable
/// foundation, and 'other' in particular is always available as a
/// reassignment target when a custom category is deleted.
class CategoryService extends ChangeNotifier {
  CategoryService._();
  static final CategoryService instance = CategoryService._();

  static const _customCategoriesKey = 'custom_categories_v1';
  static const _builtinOverridesKey = 'builtin_category_overrides_v1';
  static const _uuid = Uuid();

  List<Tag> _custom = [];
  Map<String, Tag> _builtinOverrides = {};
  bool _loaded = false;

  List<Tag> get all => [
        for (final b in kBuiltInCategories) _builtinOverrides[b.id] ?? b,
        ..._custom,
      ];
  List<Tag> get custom => List.unmodifiable(_custom);

  bool isBuiltIn(String id) => kBuiltInCategories.any((b) => b.id == id);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_customCategoriesKey) ?? [];
    _custom = raw.map((s) => Tag.fromJsonString(s)).toList();
    final overridesRaw = prefs.getString(_builtinOverridesKey);
    if (overridesRaw != null) {
      final map = jsonDecode(overridesRaw) as Map<String, dynamic>;
      _builtinOverrides = map.map(
          (k, v) => MapEntry(k, Tag.fromJson(v as Map<String, dynamic>)));
    }
    _loaded = true;
    notifyListeners();
  }

  Tag getById(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return kFallbackCategory;
  }

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _customCategoriesKey, _custom.map((c) => c.toJsonString()).toList());
  }

  Future<void> _persistOverrides() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _builtinOverridesKey,
      jsonEncode({for (final e in _builtinOverrides.entries) e.key: e.value.toJson()}),
    );
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
    await _persistCustom();
    return category;
  }

  /// Renames/re-icons/re-colors a category. Built-in categories are stored
  /// as an override (the fixed 7 always exist as a base); custom categories
  /// are updated in place.
  Future<void> updateCategory(Tag updated) async {
    if (isBuiltIn(updated.id)) {
      _builtinOverrides[updated.id] = Tag(
        id: updated.id,
        label: updated.label,
        iconIndex: updated.iconIndex,
        colorIndex: updated.colorIndex,
        isBuiltIn: true,
      );
      notifyListeners();
      await _persistOverrides();
    } else {
      final idx = _custom.indexWhere((c) => c.id == updated.id);
      if (idx == -1) return;
      _custom[idx] = updated;
      notifyListeners();
      await _persistCustom();
    }
  }

  /// Removes a custom category. Built-in categories can't be deleted —
  /// callers should check [isBuiltIn] first. Any expenses still referencing
  /// this id should be reassigned by the caller before calling this.
  Future<void> deleteCustomCategory(String id) async {
    final removed = _custom.any((c) => c.id == id);
    if (!removed) return;
    _custom.removeWhere((c) => c.id == id);
    notifyListeners();
    await _persistCustom();
  }
}
