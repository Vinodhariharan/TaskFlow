import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/task.dart';
import '../services/task_category_service.dart';
import '../services/task_change_notifier.dart';
import '../services/task_service.dart';
import 'task_form_screen.dart';

/// Everything about one task on a page of its own, with the three actions
/// that belong to a single task: mark complete, edit, delete. This is where
/// a tapped reminder notification lands, so it has to load by id and cope
/// with the task having been deleted since the reminder was scheduled.
class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _taskService = TaskService();
  Task? _task;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    TaskCategoryService.instance.load();
    _load();
    // Keeps this page honest if the task changes elsewhere (e.g. a category
    // is deleted and its tasks are reassigned) while it's open.
    TaskChangeNotifier.instance.addListener(_load);
  }

  @override
  void dispose() {
    TaskChangeNotifier.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final t = await _taskService.getTaskById(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = t;
      _loading = false;
    });
  }

  Future<void> _toggleComplete() async {
    final t = _task;
    if (t == null) return;
    HapticFeedback.lightImpact();
    final wasRecurring = t.recurrence != null && t.scheduledDate != null;
    await _taskService.toggleComplete(t.id);
    await _load();
    if (!mounted) return;
    if (wasRecurring && !t.isCompleted && _task != null) {
      // Completing a recurring task rolls it forward rather than checking it
      // off, which is invisible unless we say so.
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(
            'Moved to the next occurrence — ${DateFormat('EEE, MMM d').format(_task!.scheduledDate!)}',
            style: TextStyle(color: context.textColor),
          ),
          backgroundColor: context.cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
    }
  }

  Future<void> _edit() async {
    final t = _task;
    if (t == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            TaskFormScreen(taskService: _taskService, editTask: t),
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
    final t = _task;
    if (t == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete this task?',
            style: TextStyle(color: context.textColor)),
        content: Text(
          '"${t.title}" will be removed. This can\'t be undone.',
          style: TextStyle(color: context.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: context.mutedColor)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    HapticFeedback.mediumImpact();
    await _taskService.deleteTask(t.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    'Task',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final task = _task;
    if (task == null) {
      // Reachable by tapping a reminder for a task deleted in the meantime.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 44, color: context.subtleColor),
              const SizedBox(height: 14),
              Text(
                'This task no longer exists.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.mutedColor, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    final hasReminder = task.hasReminder;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        // Title + completion state
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: context.mutedColor,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _StatusPill(task: task),
                  if (task.priority == TaskPriority.high) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_rounded,
                              size: 12, color: AppColors.primary),
                          SizedBox(width: 5),
                          Text('High',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Details
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              if (task.categoryId != null)
                ListenableBuilder(
                  listenable: TaskCategoryService.instance,
                  builder: (context, _) {
                    final cat = TaskCategoryService.instance
                        .getById(task.categoryId!);
                    return _DetailRow(
                      icon: cat.icon,
                      iconColor: cat.color,
                      label: 'Category',
                      value: cat.label,
                    );
                  },
                ),
              _DetailRow(
                icon: Icons.calendar_today_rounded,
                label: 'Scheduled',
                value: task.scheduledDate != null
                    ? DateFormat('EEEE, MMM d, y').format(task.scheduledDate!)
                    : 'No date',
              ),
              _DetailRow(
                icon: hasReminder
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                label: 'Reminder',
                value: hasReminder
                    ? TimeOfDay(
                            hour: task.reminderHour!,
                            minute: task.reminderMinute!)
                        .format(context)
                    : 'None',
              ),
              _DetailRow(
                icon: Icons.repeat_rounded,
                label: 'Repeat',
                value: task.recurrence?.label ?? 'Does not repeat',
              ),
              if (task.note != null && task.note!.isNotEmpty)
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Note',
                  value: task.note!,
                ),
              _DetailRow(
                icon: Icons.add_circle_outline_rounded,
                label: 'Created',
                value: DateFormat('MMM d, y').format(task.createdDate),
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Actions
        _ActionButton(
          icon: task.isCompleted
              ? Icons.undo_rounded
              : Icons.check_circle_rounded,
          label: task.isCompleted ? 'Mark as not done' : 'Mark complete',
          filled: !task.isCompleted,
          onTap: _toggleComplete,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.edit_rounded,
          label: 'Edit task',
          onTap: _edit,
        ),
        const SizedBox(height: 10),
        _ActionButton(
          icon: Icons.delete_outline_rounded,
          label: 'Delete task',
          danger: true,
          onTap: _delete,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final Task task;
  const _StatusPill({required this.task});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    if (task.isCompleted) {
      label = 'Completed';
      color = AppColors.primary;
    } else if (task.isOverdue) {
      label = 'Overdue';
      color = AppColors.overdueColor;
    } else if (task.isScheduledToday) {
      label = 'Scheduled today';
      color = AppColors.dueTodayColor;
    } else if (task.isFuture) {
      label = 'Upcoming';
      color = AppColors.dueTodayColor;
    } else if (task.isCarriedOver) {
      label = 'Carried over';
      color = AppColors.primary;
    } else {
      label = 'To do';
      color = context.mutedColor;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;
  final bool last;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 17, color: iconColor ?? context.mutedColor),
              const SizedBox(width: 14),
              Text(label,
                  style: TextStyle(color: context.mutedColor, fontSize: 13)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last)
          Container(
              height: 1,
              color: context.subtleColor.withValues(alpha: 0.25)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool danger;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger
        ? AppColors.danger
        : (filled ? Colors.white : context.textColor);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: danger
              ? Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
