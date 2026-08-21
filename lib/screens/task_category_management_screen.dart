import 'package:flutter/material.dart';
import '../main.dart';
import '../models/task_category.dart';
import '../services/task_category_service.dart';
import '../services/task_service.dart';
import 'task_category_widgets.dart';

class TaskCategoryManagementScreen extends StatefulWidget {
  const TaskCategoryManagementScreen({super.key});

  @override
  State<TaskCategoryManagementScreen> createState() =>
      _TaskCategoryManagementScreenState();
}

class _TaskCategoryManagementScreenState
    extends State<TaskCategoryManagementScreen> {
  final _taskService = TaskService();

  Future<void> _edit(TaskCategory category) async {
    await showEditTaskCategoryDialog(context, category);
  }

  Future<void> _delete(TaskCategory category) async {
    final count = await _taskService.countByCategory(category.id);
    if (!mounted) return;

    if (count == 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: context.sheetBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Delete "${category.label}"?',
              style: TextStyle(color: context.textColor)),
          content: Text(
            'This category has no tasks on it. This can\'t be undone.',
            style: TextStyle(color: context.secondaryTextColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: TextStyle(color: context.mutedColor)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await TaskCategoryService.instance.deleteCustomCategory(category.id);
      }
      return;
    }

    final target = await _pickReassignTarget(category, count);
    if (target == null || !mounted) return;
    await _taskService.reassignCategory(fromId: category.id, toId: target.id);
    await TaskCategoryService.instance.deleteCustomCategory(category.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
            'Moved $count task${count == 1 ? '' : 's'} to "${target.label}" and deleted "${category.label}"'),
        duration: const Duration(seconds: 4),
      ));
  }

  Future<TaskCategory?> _pickReassignTarget(TaskCategory category, int count) {
    final others =
        TaskCategoryService.instance.all.where((c) => c.id != category.id).toList();
    return showDialog<TaskCategory>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Move $count task${count == 1 ? '' : 's'} to…',
            style: TextStyle(color: context.textColor)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in others)
                  TaskCategoryChip(
                    category: c,
                    selected: false,
                    onTap: () => Navigator.of(dialogContext).pop(c),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: context.mutedColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: TaskCategoryService.instance,
          builder: (context, _) {
            final categories = TaskCategoryService.instance.all;
            return ListView(
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
                      'Manage Task Categories',
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 0, 16),
                  child: Text(
                    'Built-in categories can be renamed, re-icon\'d, or re-colored, but not '
                    'deleted. Custom categories can be deleted — if any tasks use one, '
                    'you\'ll pick where they move first.',
                    style: TextStyle(color: context.mutedColor, fontSize: 12, height: 1.4),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < categories.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Divider(height: 1, color: context.subtleColor),
                          ),
                        _CategoryRow(
                          category: categories[i],
                          onEdit: () => _edit(categories[i]),
                          onDelete: TaskCategoryService.instance.isBuiltIn(categories[i].id)
                              ? null
                              : () => _delete(categories[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final TaskCategory category;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _CategoryRow({required this.category, required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isBuiltIn = onDelete == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(category.icon, size: 17, color: category.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isBuiltIn ? 'Built-in' : 'Custom',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.inputBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.edit_rounded, size: 16, color: context.mutedColor),
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
