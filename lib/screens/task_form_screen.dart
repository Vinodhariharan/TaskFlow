import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/task.dart';
import '../models/task_recurrence.dart';
import '../services/notification_service.dart';
import '../services/task_category_service.dart';
import '../services/task_service.dart';
import 'task_category_widgets.dart';

/// Full-page create/edit form for a task. This replaces the old bottom sheet:
/// with a note, category, reminder time and a repeat rule (plus per-weekday
/// selection) there was far more here than a sheet could show without hiding
/// most of it behind a "More" toggle. On a full page everything fits in
/// labelled sections, so nothing is buried.
///
/// Pops `true` when it saved, so an opener (e.g. the detail screen) can tell
/// a save from a plain back-out and refresh accordingly.
class TaskFormScreen extends StatefulWidget {
  final TaskService taskService;
  final Task? editTask;

  const TaskFormScreen({
    super.key,
    required this.taskService,
    this.editTask,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late TaskPriority _priority;
  DateTime? _scheduledDate;
  String? _categoryId;
  int? _reminderHour;
  int? _reminderMinute;
  RecurrenceFrequency? _recurrenceFrequency;
  Set<int> _recurrenceWeekdays = {};
  bool _saving = false;

  bool get _isEdit => widget.editTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.editTask;
    _titleController = TextEditingController(text: t?.title ?? '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _priority = t?.priority ?? TaskPriority.normal;
    _scheduledDate = t?.scheduledDate;
    _categoryId = t?.categoryId;
    _reminderHour = t?.reminderHour;
    _reminderMinute = t?.reminderMinute;
    _recurrenceFrequency = t?.recurrence?.frequency;
    _recurrenceWeekdays = {...(t?.recurrence?.weekdays ?? const <int>{})};
    TaskCategoryService.instance.load();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: context.sheetBg,
                onSurface: context.textColor,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  void _clearDate() {
    setState(() {
      _scheduledDate = null;
      // Recurrence needs a scheduled date to advance from.
      _recurrenceFrequency = null;
      _recurrenceWeekdays = {};
    });
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderHour != null
          ? TimeOfDay(hour: _reminderHour!, minute: _reminderMinute!)
          : TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: Colors.white,
                surface: context.sheetBg,
                onSurface: context.textColor,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
    await NotificationService.instance.requestPermissions();

    // A reminder for a specific scheduled date, at a time already past on
    // that date, never fires — unlike an undated reminder there's no
    // sensible day to roll it to, so at least warn instead of silently
    // doing nothing.
    if (_scheduledDate != null) {
      final now = DateTime.now();
      final moment = DateTime(_scheduledDate!.year, _scheduledDate!.month,
          _scheduledDate!.day, picked.hour, picked.minute);
      if (!moment.isAfter(now) && mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(
                'That time has already passed on the scheduled date — this reminder won\'t fire.',
                style: TextStyle(color: context.textColor)),
            backgroundColor: context.cardColor,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
      }
    }
  }

  void _clearReminder() {
    setState(() {
      _reminderHour = null;
      _reminderMinute = null;
    });
  }

  void _setFrequency(RecurrenceFrequency? f) {
    setState(() {
      _recurrenceFrequency = f;
      if (f != RecurrenceFrequency.weekly) _recurrenceWeekdays = {};
    });
  }

  void _toggleWeekday(int d) {
    setState(() {
      if (_recurrenceWeekdays.contains(d)) {
        _recurrenceWeekdays.remove(d);
      } else {
        _recurrenceWeekdays.add(d);
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final recurrence = _recurrenceFrequency == null
        ? null
        : TaskRecurrence(
            frequency: _recurrenceFrequency!, weekdays: _recurrenceWeekdays);
    final note =
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    try {
      if (widget.editTask != null) {
        await widget.taskService.updateTask(widget.editTask!.copyWith(
          title: title,
          note: note,
          priority: _priority,
          scheduledDate: _scheduledDate,
          clearScheduledDate: _scheduledDate == null,
          categoryId: _categoryId,
          clearCategoryId: _categoryId == null,
          recurrence: recurrence,
          clearRecurrence: recurrence == null,
          reminderHour: _reminderHour,
          reminderMinute: _reminderMinute,
          clearReminder: _reminderHour == null,
        ));
      } else {
        await widget.taskService.addTask(
          title: title,
          note: note,
          priority: _priority,
          scheduledDate: _scheduledDate,
          categoryId: _categoryId,
          recurrence: recurrence,
          reminderHour: _reminderHour,
          reminderMinute: _reminderMinute,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      // Guarantees the Save button never spins forever even if something
      // above throws before reaching the pop — the task data is written
      // before any of that can happen, so this only ever affects the button
      // state, never data loss.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _titleController.text.trim().isNotEmpty && !_saving;
    final hasDate = _scheduledDate != null;
    final hasReminder = _reminderHour != null;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
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
                    _isEdit ? 'Edit Task' : 'New Task',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  TextField(
                    controller: _titleController,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'What needs to be done?',
                      hintStyle:
                          TextStyle(color: context.mutedColor, fontSize: 16),
                      filled: true,
                      fillColor: context.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Schedule ─────────────────────────────────────────────
                  const _Label('SCHEDULE'),
                  Row(
                    children: [
                      Expanded(
                        child: _PillButton(
                          icon: Icons.calendar_today_rounded,
                          label: hasDate
                              ? DateFormat('EEE, MMM d').format(_scheduledDate!)
                              : 'No date — shows in today\'s list',
                          active: hasDate,
                          onTap: _pickDate,
                        ),
                      ),
                      if (hasDate) ...[
                        const SizedBox(width: 8),
                        _ClearButton(onTap: _clearDate),
                      ],
                    ],
                  ),

                  // Repeat only makes sense with a date to advance from.
                  if (hasDate) ...[
                    const SizedBox(height: 16),
                    const _Label('REPEAT'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _RepeatChip(
                          label: 'Off',
                          selected: _recurrenceFrequency == null,
                          onTap: () => _setFrequency(null),
                        ),
                        _RepeatChip(
                          label: 'Daily',
                          selected: _recurrenceFrequency ==
                              RecurrenceFrequency.daily,
                          onTap: () =>
                              _setFrequency(RecurrenceFrequency.daily),
                        ),
                        _RepeatChip(
                          label: 'Weekly',
                          selected: _recurrenceFrequency ==
                              RecurrenceFrequency.weekly,
                          onTap: () =>
                              _setFrequency(RecurrenceFrequency.weekly),
                        ),
                        _RepeatChip(
                          label: 'Monthly',
                          selected: _recurrenceFrequency ==
                              RecurrenceFrequency.monthly,
                          onTap: () =>
                              _setFrequency(RecurrenceFrequency.monthly),
                        ),
                        _RepeatChip(
                          label: 'Yearly',
                          selected: _recurrenceFrequency ==
                              RecurrenceFrequency.yearly,
                          onTap: () =>
                              _setFrequency(RecurrenceFrequency.yearly),
                        ),
                      ],
                    ),
                    if (_recurrenceFrequency ==
                        RecurrenceFrequency.weekly) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var d = 1; d <= 7; d++)
                            _WeekdayToggle(
                              label: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                                  [d - 1],
                              selected: _recurrenceWeekdays.contains(d),
                              onTap: () => _toggleWeekday(d),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _recurrenceWeekdays.isEmpty
                            ? 'No days picked — repeats weekly on the same weekday.'
                            : 'Repeats on the selected days.',
                        style:
                            TextStyle(color: context.mutedColor, fontSize: 12),
                      ),
                    ],
                  ],
                  const SizedBox(height: 22),

                  // ── Reminder ─────────────────────────────────────────────
                  const _Label('REMINDER'),
                  Row(
                    children: [
                      Expanded(
                        child: _PillButton(
                          icon: hasReminder
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_outlined,
                          label: hasReminder
                              ? TimeOfDay(
                                      hour: _reminderHour!,
                                      minute: _reminderMinute!)
                                  .format(context)
                              : 'Remind me',
                          active: hasReminder,
                          onTap: _pickReminderTime,
                        ),
                      ),
                      if (hasReminder) ...[
                        const SizedBox(width: 8),
                        _ClearButton(onTap: _clearReminder),
                      ],
                    ],
                  ),
                  if (hasReminder && !hasDate) ...[
                    const SizedBox(height: 8),
                    Text(
                      'With no date set, this reminds you today — or tomorrow if that time has already passed.',
                      style: TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 22),

                  // ── Details ──────────────────────────────────────────────
                  const _Label('PRIORITY'),
                  Row(
                    children: [
                      _RepeatChip(
                        label: 'Normal',
                        selected: _priority == TaskPriority.normal,
                        onTap: () =>
                            setState(() => _priority = TaskPriority.normal),
                      ),
                      const SizedBox(width: 8),
                      _RepeatChip(
                        label: 'High',
                        selected: _priority == TaskPriority.high,
                        onTap: () =>
                            setState(() => _priority = TaskPriority.high),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  const _Label('CATEGORY'),
                  ListenableBuilder(
                    listenable: TaskCategoryService.instance,
                    builder: (context, _) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cat in TaskCategoryService.instance.all)
                          TaskCategoryChip(
                            category: cat,
                            selected: _categoryId == cat.id,
                            onTap: () => setState(() => _categoryId =
                                _categoryId == cat.id ? null : cat.id),
                          ),
                        AddTaskCategoryChip(
                          onTap: () async {
                            final created =
                                await showAddTaskCategoryDialog(context);
                            if (created != null) {
                              setState(() => _categoryId = created.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  const _Label('NOTE'),
                  TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 3,
                    style: TextStyle(
                        color: context.secondaryTextColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a note (optional)',
                      hintStyle:
                          TextStyle(color: context.subtleColor, fontSize: 14),
                      filled: true,
                      fillColor: context.inputBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Save pinned to the bottom, above the keyboard.
            // Scaffold's resizeToAvoidBottomInset already shrinks the body
            // by the keyboard height, so this sits above the keyboard on its
            // own. Adding viewInsets.bottom here too — as this once did —
            // reads the *unshrunk* inset from the context above the Scaffold
            // and lifts the form by twice the keyboard, hiding the fields.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: canSave ? _save : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color:
                          canSave ? AppColors.primary : context.subtleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isEdit ? 'Save changes' : 'Add task',
                              style: TextStyle(
                                color: canSave
                                    ? Colors.white
                                    : context.mutedColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            color: context.mutedColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      );
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _PillButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.inputBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColors.primary : context.subtleColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 15,
                color: active ? AppColors.primary : context.mutedColor),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppColors.primary : context.mutedColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClearButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: context.inputBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Icon(Icons.close_rounded, size: 16, color: context.mutedColor),
        ),
      );
}

class _RepeatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RepeatChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : context.subtleColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : context.mutedColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _WeekdayToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _WeekdayToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColors.primary : context.inputBg,
          border: Border.all(
            color: selected ? AppColors.primary : context.subtleColor,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : context.mutedColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
