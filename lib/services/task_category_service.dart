import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task_category.dart';

/// Built-in task categories + user-created custom ones, persisted
/// separately. Mirrors CategoryService (the expense-side equivalent) but is
/// intentionally its own independent class/storage — task and expense
/// categories are different domains and shouldn't share ids or state.
class TaskCategoryService extends ChangeNotifier {
  TaskCategoryService._();
  static final TaskCategoryService instance = TaskCategoryService._();

  static const _customCategoriesKey = 'task_custom_categories_v1';
  static const _builtinOverridesKey = 'task_builtin_category_overrides_v1';
  static const _uuid = Uuid();

  List<TaskCategory> _custom = [];
  Map<String, TaskCategory> _builtinOverrides = {};
  bool _loaded = false;

  List<TaskCategory> get all => [
        for (final b in kBuiltInTaskCategories) _builtinOverrides[b.id] ?? b,
        ..._custom,
      ];
  List<TaskCategory> get custom => List.unmodifiable(_custom);

  bool isBuiltIn(String id) => kBuiltInTaskCategories.any((b) => b.id == id);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_customCategoriesKey) ?? [];
    _custom = raw.map((s) => TaskCategory.fromJsonString(s)).toList();
    final overridesRaw = prefs.getString(_builtinOverridesKey);
    if (overridesRaw != null) {
      final map = jsonDecode(overridesRaw) as Map<String, dynamic>;
      _builtinOverrides = map.map(
          (k, v) => MapEntry(k, TaskCategory.fromJson(v as Map<String, dynamic>)));
    }
    _loaded = true;
    notifyListeners();
  }

  TaskCategory getById(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return kFallbackTaskCategory;
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

  Future<TaskCategory> addCustomCategory({
    required String label,
    required int iconIndex,
    required int colorIndex,
  }) async {
    final category = TaskCategory(
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
  /// as an override; custom categories are updated in place.
  Future<void> updateCategory(TaskCategory updated) async {
    if (isBuiltIn(updated.id)) {
      _builtinOverrides[updated.id] = TaskCategory(
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
  /// callers should check [isBuiltIn] first. Any tasks still referencing
  /// this id should be reassigned by the caller before calling this.
  Future<void> deleteCustomCategory(String id) async {
    final removed = _custom.any((c) => c.id == id);
    if (!removed) return;
    _custom.removeWhere((c) => c.id == id);
    notifyListeners();
    await _persistCustom();
  }
}
