import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../services/notification_service.dart';

/// Full-page create/edit form for a habit, laid out like TaskFormScreen:
/// labelled sections, nothing hidden behind a "more" toggle, save pinned to
/// the bottom.
class HabitFormScreen extends StatefulWidget {
  final Habit? editHabit;
  const HabitFormScreen({super.key, this.editHabit});

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  final _service = HabitService();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;

  late int _iconIndex;
  late int _colorIndex;
  late int _targetCount;
  late Set<int> _activeWeekdays;
  int? _reminderHour;
  int? _reminderMinute;
  bool _saving = false;

  bool get _isEdit => widget.editHabit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.editHabit;
    _nameController = TextEditingController(text: h?.name ?? '');
    _unitController = TextEditingController(text: h?.unit ?? '');
    _iconIndex = h?.iconIndex ?? 0;
    _colorIndex = h?.colorIndex ?? 0;
    _targetCount = h?.targetCount ?? 1;
    _activeWeekdays = {...(h?.activeWeekdays ?? const <int>{})};
    _reminderHour = h?.reminderHour;
    _reminderMinute = h?.reminderMinute;
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _toggleWeekday(int d) {
    setState(() {
      if (_activeWeekdays.contains(d)) {
        _activeWeekdays.remove(d);
      } else {
        _activeWeekdays.add(d);
      }
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
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    // A unit only means anything alongside a count, so it's dropped when the
    // habit is a plain tick.
    final unit = _targetCount > 1 && _unitController.text.trim().isNotEmpty
        ? _unitController.text.trim()
        : null;

    try {
      if (_isEdit) {
        await _service.updateHabit(widget.editHabit!.copyWith(
          name: name,
          iconIndex: _iconIndex,
          colorIndex: _colorIndex,
          targetCount: _targetCount,
          unit: unit,
          clearUnit: unit == null,
          activeWeekdays: _activeWeekdays,
          reminderHour: _reminderHour,
          reminderMinute: _reminderMinute,
          clearReminder: _reminderHour == null,
        ));
      } else {
        await _service.addHabit(
          name: name,
          iconIndex: _iconIndex,
          colorIndex: _colorIndex,
          targetCount: _targetCount,
          unit: unit,
          activeWeekdays: _activeWeekdays,
          reminderHour: _reminderHour,
          reminderMinute: _reminderMinute,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty && !_saving;
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
                    _isEdit ? 'Edit Habit' : 'New Habit',
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
                    controller: _nameController,
                    autofocus: !_isEdit,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'What do you want to do regularly?',
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

                  const _Label('ICON'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < kHabitIconChoices.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => _iconIndex = i),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _iconIndex == i
                                  ? kHabitColorChoices[_colorIndex]
                                      .withValues(alpha: 0.18)
                                  : context.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _iconIndex == i
                                    ? kHabitColorChoices[_colorIndex]
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              kHabitIconChoices[i],
                              size: 20,
                              color: _iconIndex == i
                                  ? kHabitColorChoices[_colorIndex]
                                  : context.mutedColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  const _Label('COLOUR'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < kHabitColorChoices.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => _colorIndex = i),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: kHabitColorChoices[i],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _colorIndex == i
                                    ? context.textColor
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  const _Label('DAILY TARGET'),
                  Row(
                    children: [
                      _StepperButton(
                        icon: Icons.remove_rounded,
                        onTap: _targetCount > 1
                            ? () => setState(() => _targetCount--)
                            : null,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            _targetCount == 1
                                ? 'Once a day'
                                : '$_targetCount× a day',
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      _StepperButton(
                        icon: Icons.add_rounded,
                        onTap: () => setState(() => _targetCount++),
                      ),
                    ],
                  ),
                  // A unit is only meaningful when there's something to count.
                  if (_targetCount > 1) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _unitController,
                      style: TextStyle(
                          color: context.secondaryTextColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Unit (glasses, pages…) — optional',
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
                  const SizedBox(height: 22),

                  const _Label('DAYS'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        _WeekdayToggle(
                          label: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                              [d - 1],
                          selected: _activeWeekdays.isEmpty ||
                              _activeWeekdays.contains(d),
                          onTap: () => _toggleWeekday(d),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeWeekdays.isEmpty
                        ? 'Every day. Tap to pick specific days.'
                        : 'Days you skip never count against your streak.',
                    style: TextStyle(color: context.mutedColor, fontSize: 12),
                  ),
                  const SizedBox(height: 22),

                  const _Label('REMINDER'),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickReminderTime,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: hasReminder
                                  ? AppColors.primary.withValues(alpha: 0.12)
                                  : context.inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasReminder
                                    ? AppColors.primary
                                    : context.subtleColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  hasReminder
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_outlined,
                                  size: 15,
                                  color: hasReminder
                                      ? AppColors.primary
                                      : context.mutedColor,
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  hasReminder
                                      ? TimeOfDay(
                                              hour: _reminderHour!,
                                              minute: _reminderMinute!)
                                          .format(context)
                                      : 'Remind me',
                                  style: TextStyle(
                                    color: hasReminder
                                        ? AppColors.primary
                                        : context.mutedColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (hasReminder) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            _reminderHour = null;
                            _reminderMinute = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: context.inputBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: context.mutedColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 12 + MediaQuery.of(context).viewInsets.bottom),
              child: SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: canSave ? _save : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: canSave ? AppColors.primary : context.subtleColor,
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
                              _isEdit ? 'Save changes' : 'Add habit',
                              style: TextStyle(
                                color:
                                    canSave ? Colors.white : context.mutedColor,
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

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepperButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: context.inputBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            size: 20,
            color: enabled ? context.textColor : context.subtleColor),
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
