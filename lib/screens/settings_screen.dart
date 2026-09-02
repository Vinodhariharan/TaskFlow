import 'package:flutter/material.dart';
import '../main.dart';
import '../services/currency_settings.dart';
import '../services/expense_service.dart';
import '../services/settings_service.dart';
import 'category_management_screen.dart';
import 'notification_diagnostics_screen.dart';
import 'expense_widgets.dart';
import 'export_expenses_screen.dart';
import 'import_expenses_screen.dart';
import 'task_category_management_screen.dart';
import '../app_info.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeNotifier notifier;
  const SettingsScreen({super.key, required this.notifier});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _appVersion = '1.0.0';

  final _settingsService = SettingsService();
  final _expenseService = ExpenseService();
  int _defaultTab = 0;

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onThemeChanged);
    _settingsService.getDefaultTab().then((v) {
      if (mounted) setState(() => _defaultTab = v);
    });
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  Future<void> _setDefaultTab(int index) async {
    setState(() => _defaultTab = index);
    await _settingsService.setDefaultTab(index);
  }

  Future<void> _showCurrencyPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CurrencyPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.arrow_back_rounded,
                        size: 18, color: context.textColor),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _SectionLabel('APPEARANCE'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Dark mode',
                  trailing: Switch(
                    value: isDark,
                    activeThumbColor: AppColors.primary,
                    onChanged: (_) => widget.notifier.toggle(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('PRIMARY SECTION'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.check_box_outlined,
                  title: 'Tasks',
                  subtitle: 'Opens at launch and sits on the left of the toggle',
                  trailing: _defaultTab == 0
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () => _setDefaultTab(0),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.receipt_long_rounded,
                  title: 'Expenses',
                  subtitle: 'Opens at launch and sits on the left of the toggle',
                  trailing: _defaultTab == 1
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () => _setDefaultTab(1),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.self_improvement_rounded,
                  title: 'Habits',
                  subtitle: 'Opens at launch and sits on the left of the toggle',
                  trailing: _defaultTab == 2
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () => _setDefaultTab(2),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('CURRENCY'),
            _SettingsCard(
              children: [
                ListenableBuilder(
                  listenable: CurrencySettings.instance,
                  builder: (context, _) => _SettingsRow(
                    icon: Icons.currency_exchange_rounded,
                    title: 'Currency',
                    subtitle: CurrencySettings.instance.current.label,
                    trailing: Icon(Icons.chevron_right_rounded,
                        color: context.mutedColor, size: 20),
                    onTap: () => _showCurrencyPicker(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('CATEGORIES'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.sell_rounded,
                  title: 'Manage expense categories',
                  subtitle: 'Edit built-in tags, add or delete custom ones',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: context.mutedColor, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
                    ),
                  ),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.label_outline_rounded,
                  title: 'Manage task categories',
                  subtitle: 'Edit built-in categories, add or delete custom ones',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: context.mutedColor, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TaskCategoryManagementScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('NOTIFICATIONS'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Reminder diagnostics',
                  subtitle: 'Check permissions and send a test reminder',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: context.mutedColor, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationDiagnosticsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('DATA'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.upload_file_rounded,
                  title: 'Import expenses from CSV',
                  subtitle: 'Bring in expenses from a spreadsheet, with a template',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: context.mutedColor, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ImportExpensesScreen(expenseService: _expenseService),
                    ),
                  ),
                ),
                _Divider(),
                _SettingsRow(
                  icon: Icons.download_rounded,
                  title: 'Export expenses to CSV',
                  subtitle: 'All expenses, or a date range you choose',
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: context.mutedColor, size: 20),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ExportExpensesScreen(expenseService: _expenseService),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('ABOUT'),
            _SettingsCard(
              children: [
                const _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: kAppName,
                  subtitle: 'Version $_appVersion',
                ),
                _Divider(),
                const _SettingsRow(
                  icon: Icons.favorite_border_rounded,
                  title: 'Tasks and expenses, together',
                  subtitle:
                      'A lightweight task manager with a built-in, fully local expense tracker.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        label,
        style: TextStyle(
          color: context.mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(height: 1, color: context.subtleColor),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.mutedColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                            color: context.mutedColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Search-to-filter currency picker, opened as a bottom sheet from the
/// Currency settings row instead of a flat scrollable list of every option.
class _CurrencyPickerSheet extends StatefulWidget {
  const _CurrencyPickerSheet();

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final results = q.isEmpty
        ? kCurrencyOptions
        : kCurrencyOptions
            .where((c) =>
                c.label.toLowerCase().contains(q) || c.code.toLowerCase().contains(q))
            .toList();

    // Shrink the sheet to fit above the keyboard (instead of a fixed 70% of
    // the full screen height, which could still put the search field or
    // list under the keyboard once it opens), and pad the bottom to match.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = ((screenHeight - bottomInset) * 0.82)
        .clamp(260.0, screenHeight * 0.7);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.handleColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Currency',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(color: context.textColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search currencies',
              hintStyle: TextStyle(color: context.mutedColor, fontSize: 15),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.mutedColor),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No matching currency',
                          style: TextStyle(color: context.mutedColor, fontSize: 13)),
                    ),
                  )
                : ListenableBuilder(
                    listenable: CurrencySettings.instance,
                    builder: (context, _) => ListView.builder(
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final option = results[i];
                        final selected =
                            CurrencySettings.instance.current.code == option.code;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              CurrencySettings.instance.setCurrency(option);
                              Navigator.of(context).pop();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        color: context.textColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    const Icon(Icons.check_rounded,
                                        color: kExpenseAccent, size: 20),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
