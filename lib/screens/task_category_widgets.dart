import 'package:flutter/material.dart';
import '../main.dart';
import '../models/task_category.dart';
import '../services/task_category_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Task category chip (select / unselect)
// ─────────────────────────────────────────────────────────────────────────────

class TaskCategoryChip extends StatelessWidget {
  final TaskCategory category;
  final bool selected;
  final VoidCallback onTap;

  const TaskCategoryChip(
      {super.key,
      required this.category,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? category.color.withValues(alpha: 0.15)
              : context.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? category.color : context.subtleColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(category.icon,
                size: 14, color: selected ? category.color : context.mutedColor),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: TextStyle(
                color: selected ? category.color : context.mutedColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed "add new" chip, styled to sit alongside TaskCategoryChip in a Wrap.
class AddTaskCategoryChip extends StatelessWidget {
  final VoidCallback onTap;
  const AddTaskCategoryChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: context.inputBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.subtleColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 14, color: context.mutedColor),
            const SizedBox(width: 4),
            Text(
              'New category',
              style: TextStyle(
                color: context.mutedColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a dialog to create a custom task category (name + icon + color),
/// and returns the created TaskCategory, or null if cancelled.
Future<TaskCategory?> showAddTaskCategoryDialog(BuildContext context) {
  return _showTaskCategoryFormDialog(context, existing: null);
}

/// Opens a dialog to edit an existing task category's name/icon/color
/// (built-in or custom) and returns the updated TaskCategory, or null if
/// cancelled.
Future<TaskCategory?> showEditTaskCategoryDialog(
    BuildContext context, TaskCategory existing) {
  return _showTaskCategoryFormDialog(context, existing: existing);
}

Future<TaskCategory?> _showTaskCategoryFormDialog(BuildContext context,
    {TaskCategory? existing}) {
  final isEdit = existing != null;
  final controller = TextEditingController(text: existing?.label ?? '');
  int iconIndex = existing?.iconIndex ?? 0;
  int colorIndex = existing?.colorIndex ?? 0;

  return showDialog<TaskCategory>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        backgroundColor: context.sheetBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isEdit ? 'Edit category' : 'New category',
            style: TextStyle(color: context.textColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: context.textColor),
                decoration: InputDecoration(
                  hintText: 'Category name',
                  hintStyle: TextStyle(color: context.mutedColor),
                  filled: true,
                  fillColor: context.inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Icon',
                  style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < kTaskCategoryIconChoices.length; i++)
                    GestureDetector(
                      onTap: () => setDialogState(() => iconIndex = i),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: iconIndex == i
                              ? kTaskCategoryColorChoices[colorIndex]
                                  .withValues(alpha: 0.2)
                              : context.inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: iconIndex == i
                              ? Border.all(
                                  color: kTaskCategoryColorChoices[colorIndex],
                                  width: 1.5)
                              : null,
                        ),
                        child: Icon(kTaskCategoryIconChoices[i],
                            size: 17,
                            color: iconIndex == i
                                ? kTaskCategoryColorChoices[colorIndex]
                                : context.mutedColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Color',
                  style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (int i = 0; i < kTaskCategoryColorChoices.length; i++)
                    GestureDetector(
                      onTap: () => setDialogState(() => colorIndex = i),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: kTaskCategoryColorChoices[i],
                          shape: BoxShape.circle,
                          border: colorIndex == i
                              ? Border.all(color: context.textColor, width: 2)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: context.mutedColor)),
          ),
          TextButton(
            onPressed: () async {
              final label = controller.text.trim();
              if (label.isEmpty) return;
              final TaskCategory category;
              if (isEdit) {
                category = TaskCategory(
                  id: existing.id,
                  label: label,
                  iconIndex: iconIndex,
                  colorIndex: colorIndex,
                  isBuiltIn: existing.isBuiltIn,
                );
                await TaskCategoryService.instance.updateCategory(category);
              } else {
                category = await TaskCategoryService.instance.addCustomCategory(
                    label: label, iconIndex: iconIndex, colorIndex: colorIndex);
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(category);
              }
            },
            child: Text(isEdit ? 'Save' : 'Create',
                style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    ),
  );
}
