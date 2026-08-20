import 'package:flutter/material.dart';
import '../main.dart';
import '../services/currency_settings.dart';
import '../services/settings_service.dart';
import 'expense_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeNotifier notifier;
  const SettingsScreen({super.key, required this.notifier});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _appVersion = '1.0.0';

  final _settingsService = SettingsService();
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

            _SectionLabel('STARTUP'),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.check_box_outlined,
                  title: 'Tasks',
                  subtitle: 'Open on the Tasks tab at launch',
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
                  subtitle: 'Open on the Expenses tab at launch',
                  trailing: _defaultTab == 1
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 20)
                      : null,
                  onTap: () => _setDefaultTab(1),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('CURRENCY'),
            _SettingsCard(
              children: [
                for (int i = 0; i < kCurrencyOptions.length; i++) ...[
                  if (i > 0) _Divider(),
                  ListenableBuilder(
                    listenable: CurrencySettings.instance,
                    builder: (context, _) {
                      final option = kCurrencyOptions[i];
                      final selected =
                          CurrencySettings.instance.current.code ==
                              option.code;
                      return _SettingsRow(
                        icon: Icons.currency_exchange_rounded,
                        title: option.label,
                        trailing: selected
                            ? const Icon(Icons.check_rounded,
                                color: kExpenseAccent, size: 20)
                            : null,
                        onTap: () =>
                            CurrencySettings.instance.setCurrency(option),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            _SectionLabel('ABOUT'),
            _SettingsCard(
              children: [
                const _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  title: 'TaskFlow',
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
