import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/services/header_scroll_notifier.dart';

/// The bar swaps the app name for the screen's title on scroll. A single
/// threshold would flicker whenever a list came to rest near it, so the
/// hysteresis band is the part worth pinning down.
void main() {
  final notifier = HeaderScrollNotifier.instance;

  void scroll(double offset, {int screen = 0}) => notifier.report(
        screenId: screen,
        title: 'My Tasks',
        offset: offset,
      );

  setUp(() {
    // Back to the top before each case.
    scroll(0);
    scroll(0, screen: 1);
  });

  test('stays expanded near the top', () {
    scroll(10);
    expect(notifier.isCollapsed(0), isFalse);
  });

  test('collapses once the title has scrolled away', () {
    scroll(60);
    expect(notifier.isCollapsed(0), isTrue);
    expect(notifier.titleFor(0), 'My Tasks');
  });

  test('does not flicker between the two thresholds', () {
    scroll(60);
    expect(notifier.isCollapsed(0), isTrue);
    // Inside the band: already collapsed, so it stays collapsed rather than
    // toggling on every pixel of overscroll wobble.
    scroll(35);
    expect(notifier.isCollapsed(0), isTrue);
    scroll(20);
    expect(notifier.isCollapsed(0), isFalse);
    // And going back up through the band does not re-collapse early.
    scroll(35);
    expect(notifier.isCollapsed(0), isFalse);
  });

  test('each screen is tracked separately', () {
    scroll(60);
    scroll(0, screen: 1);
    expect(notifier.isCollapsed(0), isTrue);
    expect(notifier.isCollapsed(1), isFalse);
  });

  test('a screen that never reported is expanded with no title', () {
    expect(notifier.isCollapsed(99), isFalse);
    expect(notifier.titleFor(99), isEmpty);
  });
}
