import 'package:flutter/foundation.dart';

/// Tracks whether each screen has scrolled its own title out of view, so the
/// shell's top bar can take it over.
///
/// The bar lives in RootShell while the titles live inside each tab's own
/// scroll view, so a SliverAppBar can't span both. Rather than lift the bar
/// into every screen — it also holds the settings button and has to stay put
/// across all three tabs — each screen reports its offset here and the bar
/// reads it back.
class HeaderScrollNotifier extends ChangeNotifier {
  HeaderScrollNotifier._();
  static final HeaderScrollNotifier instance = HeaderScrollNotifier._();

  /// Two thresholds rather than one: a list resting near a single boundary
  /// would flicker between the app name and the screen title on every
  /// pixel of overscroll wobble.
  static const double _collapseAbove = 46;
  static const double _restoreBelow = 26;

  final Map<int, bool> _collapsed = {};
  final Map<int, String> _titles = {};

  void report({
    required int screenId,
    required String title,
    required double offset,
  }) {
    final was = _collapsed[screenId] ?? false;
    final now = was ? offset > _restoreBelow : offset > _collapseAbove;
    if (was == now && _titles[screenId] == title) return;
    _collapsed[screenId] = now;
    _titles[screenId] = title;
    notifyListeners();
  }

  bool isCollapsed(int screenId) => _collapsed[screenId] ?? false;

  String titleFor(int screenId) => _titles[screenId] ?? '';
}
