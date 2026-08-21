import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../services/category_service.dart';
import '../services/currency_settings.dart';
import '../services/expense_service.dart';
import 'expense_widgets.dart';

class AddEditExpenseSheet extends StatefulWidget {
  final ExpenseService expenseService;
  final Expense? editExpense;

  const AddEditExpenseSheet(
      {super.key, required this.expenseService, this.editExpense});

  @override
  State<AddEditExpenseSheet> createState() => _AddEditExpenseSheetState();
}

class _AddEditExpenseSheetState extends State<AddEditExpenseSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  // Hoisted rather than created inline in build: RawAutocomplete rebinds its
  // internal TextField whenever the FocusNode identity changes, and a fresh
  // `FocusNode()` on every keystroke's rebuild was resetting focus/selection
  // mid-edit, which showed up as backspace seeming to do nothing.
  final _titleFocusNode = FocusNode();
  late String _categoryId;
  late DateTime _date;
  bool _saving = false;
  List<String> _titleSuggestions = [];

  @override
  void initState() {
    super.initState();
    final e = widget.editExpense;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController =
        TextEditingController(text: e != null ? _stripTrailingZero(e.amount) : '');
    _noteController = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId ?? kBuiltInCategories.first.id;
    _date = e?.date ?? DateTime.now();
    CategoryService.instance.load();
    _titleController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
    widget.expenseService.getTitleSuggestions().then((titles) {
      if (mounted) setState(() => _titleSuggestions = titles);
    });
  }

  String _stripTrailingZero(double v) {
    final s = v.toStringAsFixed(2);
    return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  double? get _parsedAmount => double.tryParse(_amountController.text.trim());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: context.sheetBg,
                  onSurface: context.textColor,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = _parsedAmount;
    if (title.isEmpty || amount == null || amount <= 0) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();

    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    if (widget.editExpense != null) {
      final updated = widget.editExpense!.copyWith(
        title: title,
        amount: amount,
        categoryId: _categoryId,
        date: _date,
        note: note,
        clearNote: note == null,
      );
      await widget.expenseService.updateExpense(updated);
    } else {
      await widget.expenseService.addExpense(
        title: title,
        amount: amount,
        categoryId: _categoryId,
        date: _date,
        note: note,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editExpense != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final amount = _parsedAmount;
    final canSave = _titleController.text.trim().isNotEmpty &&
        amount != null &&
        amount > 0 &&
        !_saving;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: context.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: SingleChildScrollView(
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
            isEdit ? 'Edit expense' : 'New expense',
            style: TextStyle(
              color: context.textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Title (with suggestions from previously used titles)
          LayoutBuilder(
            builder: (context, constraints) {
              return RawAutocomplete<String>(
                textEditingController: _titleController,
                focusNode: _titleFocusNode,
                optionsBuilder: (value) {
                  final q = value.text.trim().toLowerCase();
                  if (q.isEmpty) return const Iterable<String>.empty();
                  return _titleSuggestions
                      .where((t) => t.toLowerCase().contains(q))
                      .take(6);
                },
                fieldViewBuilder: (context, controller, focusNode, _) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                        color: context.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'What did you spend on?',
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
                  );
                },
                optionsViewBuilder: (context, onSelected, options) =>
                    buildSuggestionsOptionsView(
                        context, onSelected, options, constraints.maxWidth),
              );
            },
          ),
          const SizedBox(height: 10),

          // Amount
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style: TextStyle(
                color: context.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: TextStyle(color: context.mutedColor, fontSize: 16),
              prefixText: '${CurrencySettings.instance.current.symbol}  ',
              prefixStyle: TextStyle(
                  color: context.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.danger, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
              ),
              errorStyle: const TextStyle(color: AppColors.danger, fontSize: 12),
              errorText: _amountController.text.isNotEmpty && amount == null
                  ? 'Enter a valid number'
                  : _amountController.text.isNotEmpty &&
                          amount != null &&
                          amount <= 0
                      ? 'Amount must be greater than 0'
                      : null,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 14),

          // Category
          Text('Category',
              style: TextStyle(
                color: context.mutedColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: 8),
          ListenableBuilder(
            listenable: CategoryService.instance,
            builder: (context, _) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final cat in CategoryService.instance.all)
                  CategoryChip(
                    category: cat,
                    selected: _categoryId == cat.id,
                    onTap: () => setState(() => _categoryId = cat.id),
                  ),
                AddCategoryChip(
                  onTap: () async {
                    final created = await showAddCategoryDialog(context);
                    if (created != null) {
                      setState(() => _categoryId = created.id);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Date
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: kExpenseAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kExpenseAccent, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 14, color: kExpenseAccent),
                  const SizedBox(width: 7),
                  Text(
                    DateFormat('EEE, MMM d, yyyy').format(_date),
                    style: const TextStyle(
                      color: kExpenseAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Note
          TextField(
            controller: _noteController,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: context.secondaryTextColor, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add a note (optional)',
              hintStyle: TextStyle(color: context.subtleColor, fontSize: 14),
              filled: true,
              fillColor: context.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Save
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: canSave ? _save : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: canSave ? kExpenseAccent : context.subtleColor,
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
                          isEdit ? 'Save changes' : 'Add expense',
                          style: TextStyle(
                            color: canSave ? Colors.white : context.mutedColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
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
