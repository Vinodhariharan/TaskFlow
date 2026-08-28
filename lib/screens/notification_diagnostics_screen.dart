import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../services/notification_service.dart';

/// Shows why reminders are or aren't able to fire, and lets the user send
/// both an immediate and a scheduled test through the same code path a real
/// reminder uses. The two tests separate the two failure modes: if the
/// immediate one arrives but the timed one doesn't, the problem is alarm
/// scheduling (permissions/battery optimisation), not notifications.
class NotificationDiagnosticsScreen extends StatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  State<NotificationDiagnosticsScreen> createState() =>
      _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState
    extends State<NotificationDiagnosticsScreen> {
  NotificationDiagnostics? _diag;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await NotificationService.instance.diagnostics();
      if (!mounted) return;
      setState(() {
        _diag = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message, style: TextStyle(color: context.textColor)),
        backgroundColor: context.cardColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _grantPermissions() async {
    await NotificationService.instance.requestPermissions();
    await _load();
  }

  Future<void> _testNow() async {
    try {
      await NotificationService.instance.showTestNotification();
      if (mounted) _toast('Sent. It should appear in your notification shade now.');
    } catch (e) {
      if (mounted) _toast('Failed: $e');
    }
  }

  Future<void> _testScheduled() async {
    try {
      final r = await NotificationService.instance.scheduleTestNotification();
      if (!mounted) return;
      final at = DateFormat('h:mm a').format(r.at);
      _toast(r.exact
          ? 'Scheduled for $at (exact alarm). Leave the app — it should still arrive.'
          : 'Scheduled for $at, but only as an INEXACT alarm — Android may delay it '
              'by many minutes. Grant exact alarms above.');
      await _load();
    } catch (e) {
      if (mounted) _toast('Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Reminder Diagnostics',
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _card([
                Text('Couldn\'t read notification status:\n$_error',
                    style: TextStyle(color: context.secondaryTextColor)),
              ])
            else ...[
              _card([
                _statusRow(
                  'Notifications allowed',
                  _diag!.notificationsEnabled,
                  whenFalse: 'Android is blocking all notifications from '
                      'TaskFlow. Nothing can appear until this is on.',
                ),
                _Divider(),
                _statusRow(
                  'Exact alarms allowed',
                  _diag!.canScheduleExact,
                  whenFalse: 'Reminders will still be scheduled, but Android '
                      'can delay them by many minutes while the phone is idle.',
                ),
                _Divider(),
                _infoRow('Time zone', _diag!.timeZone),
                _Divider(),
                _infoRow(
                  'Reminders currently scheduled',
                  _diag!.pendingError != null
                      ? 'error'
                      : '${_diag!.pending.length}',
                ),
              ]),
              if (_diag!.pendingError != null ||
                  _diag!.lastScheduleError != null) ...[
                const SizedBox(height: 12),
                _errorCard(
                  _diag!.pendingError ?? _diag!.lastScheduleError!,
                ),
              ],
              const SizedBox(height: 12),
              if (_diag!.notificationsEnabled == false ||
                  _diag!.canScheduleExact == false)
                _button(
                  label: 'Grant missing permissions',
                  icon: Icons.lock_open_rounded,
                  filled: true,
                  onTap: _grantPermissions,
                ),
              const SizedBox(height: 20),
              Text('TESTS',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  )),
              const SizedBox(height: 8),
              _button(
                label: 'Send a notification now',
                icon: Icons.notifications_active_rounded,
                onTap: _testNow,
              ),
              const SizedBox(height: 8),
              _button(
                label: 'Schedule one for 1 minute from now',
                icon: Icons.schedule_rounded,
                onTap: _testScheduled,
              ),
              const SizedBox(height: 12),
              Text(
                'If the immediate one arrives but the timed one doesn\'t, the '
                'problem is alarm scheduling — check that TaskFlow is exempt '
                'from battery optimisation in your phone\'s settings.',
                style: TextStyle(
                    color: context.mutedColor, fontSize: 12, height: 1.4),
              ),
              if (_diag!.pending.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('SCHEDULED',
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    )),
                const SizedBox(height: 8),
                _card([
                  for (var i = 0; i < _diag!.pending.length; i++) ...[
                    if (i > 0) _Divider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        _diag!.pending[i].title ?? '(untitled)',
                        style: TextStyle(
                            color: context.secondaryTextColor, fontSize: 14),
                      ),
                    ),
                  ],
                ]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  /// Shown when the plugin itself errored rather than merely reporting a
  /// denied permission — the text is the raw platform exception, so it stays
  /// scrollable rather than overflowing the card.
  Widget _errorCard(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.4), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bug_report_outlined,
                    size: 16, color: AppColors.danger),
                SizedBox(width: 8),
                Text('Plugin error',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                child: SelectableText(
                  message,
                  style: TextStyle(
                      color: context.secondaryTextColor,
                      fontSize: 11,
                      height: 1.4),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _statusRow(String label, bool? value, {required String whenFalse}) {
    final ok = value == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18,
                color: ok ? AppColors.primary : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: context.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              Text(
                value == null ? 'unknown' : (ok ? 'Yes' : 'No'),
                style: TextStyle(
                    color: ok ? AppColors.primary : AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(whenFalse,
                  style: TextStyle(
                      color: context.mutedColor, fontSize: 12, height: 1.4)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style:
                      TextStyle(color: context.textColor, fontSize: 14)),
            ),
            Text(value,
                style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _button({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: filled ? AppColors.primary : context.cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: filled ? Colors.white : context.mutedColor),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                    color: filled ? Colors.white : context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(height: 1, color: context.subtleColor.withValues(alpha: 0.3)),
      );
}
