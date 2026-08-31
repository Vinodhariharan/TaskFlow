import 'package:home_widget/home_widget.dart';
import '../screens/expense_widgets.dart' show formatCurrency;
import 'currency_settings.dart';
import 'expense_service.dart';
import 'task_service.dart';

/// Pushes a small summary of tasks and spending into the two Android home
/// screen widgets.
///
/// The widgets are deliberately read-only snapshots: the native side just
/// renders whatever strings are stored here, so all the formatting and
/// currency handling stays in Dart where it already exists, and the Kotlin
/// stays simple enough to be obviously correct without a device to test on.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _taskProvider = 'TaskWidgetProvider';
  static const _expenseProvider = 'ExpenseWidgetProvider';

  /// How many task titles each widget lists. Matches the fixed number of
  /// TextViews in task_widget.xml — a list would need a RemoteViewsService,
  /// which is a lot of machinery for three lines.
  static const _taskLineCount = 3;

  final _taskService = TaskService();
  final _expenseService = ExpenseService();

  bool _refreshing = false;
  bool _again = false;

  /// Recomputes both widgets. Safe to call from anywhere, as often as you
  /// like — overlapping calls collapse into one trailing refresh rather than
  /// piling up reads of the same data.
  Future<void> refresh() async {
    if (_refreshing) {
      _again = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _again = false;
        await _refreshTasks();
        await _refreshExpenses();
      } while (_again);
    } catch (_) {
      // A widget that can't update is not worth breaking the app over.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshTasks() async {
    final today = await _taskService.getTodayTasks();
    final pending = today.where((t) => !t.isCompleted).toList();
    final done = today.length - pending.length;

    await HomeWidget.saveWidgetData<String>(
      'task_count',
      pending.isEmpty ? 'All clear' : '${pending.length} to do',
    );
    await HomeWidget.saveWidgetData<String>(
      'task_progress',
      today.isEmpty ? 'Nothing scheduled' : '$done of ${today.length} done',
    );

    for (var i = 0; i < _taskLineCount; i++) {
      // Empty string rather than null so the native side can hide the row by
      // testing for blank, without needing a separate "how many" key.
      await HomeWidget.saveWidgetData<String>(
        'task_$i',
        i < pending.length ? pending[i].title : '',
      );
    }

    await HomeWidget.updateWidget(name: _taskProvider, androidName: _taskProvider);
  }

  Future<void> _refreshExpenses() async {
    await CurrencySettings.instance.load();
    final kpis = await _expenseService.getKpis();

    await HomeWidget.saveWidgetData<String>(
      'expense_month',
      formatCurrency(kpis.thisMonth),
    );
    await HomeWidget.saveWidgetData<String>(
      'expense_30d',
      formatCurrency(kpis.last30Days),
    );

    await HomeWidget.updateWidget(
        name: _expenseProvider, androidName: _expenseProvider);
  }
}
