import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/todo_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../controllers/todo_controller.dart';

const _kRecurrenceOptions = [
  (Recurrence.none, 'None'),
  (Recurrence.daily, 'Daily'),
  (Recurrence.weekly, 'Weekly'),
  (Recurrence.monthly, 'Monthly'),
];

/// Tasks / to-do screen.
class TodosView extends StatelessWidget {
  const TodosView({super.key});

  static const _routes = [
    AppRoutes.HOME,
    AppRoutes.TODOS,
    AppRoutes.SPORTS,
    AppRoutes.PORTFOLIO,
    AppRoutes.REPORTS,
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<TodoController>();

    return Scaffold(
      backgroundColor: AppColors.dark,
      bottomNavigationBar: AppNavBar(
        currentIndex: 1,
        onTap: (i) {
          if (i != 1) Get.offNamed(_routes[i]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.dark,
        onPressed: () => _showAddSheet(context, ctrl),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dark header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Filter chips
                  Obx(() => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: TodoController.filters.map((f) {
                            final selected = ctrl.filter.value == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => ctrl.filter.value = f,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white
                                            .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? AppColors.dark
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      )),
                ],
              ),
            ),

            // ── White card ────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Obx(() {
                  if (ctrl.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    );
                  }
                  final items = ctrl.filteredTodos;
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.textMuted,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ctrl.filter.value == 'Done'
                                ? 'No completed tasks'
                                : 'No tasks here',
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: ctrl.refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _TodoTile(
                        todo: items[i],
                        onToggle: () => ctrl.toggleComplete(items[i].id),
                        onDelete: () => ctrl.deleteTodo(items[i].id),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, TodoController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddTodoSheet(controller: ctrl),
    );
  }
}

// ── Todo tile ──────────────────────────────────────────────────────────────

class _TodoTile extends StatelessWidget {
  final TodoModel todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  String? _dueDateLabel() {
    if (todo.dueDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(
        todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
    final diff = d.difference(today).inDays;

    final hasTime =
        todo.dueDate!.hour != 0 || todo.dueDate!.minute != 0;
    String timeSuffix = '';
    if (hasTime) {
      final h = todo.dueDate!.hour;
      final m = todo.dueDate!.minute.toString().padLeft(2, '0');
      final period = h < 12 ? 'AM' : 'PM';
      final h12 = h % 12 == 0 ? 12 : h % 12;
      timeSuffix = '  $h12:$m $period';
    }

    if (diff == 0) return 'Today$timeSuffix';
    if (diff == 1) return 'Tomorrow$timeSuffix';
    if (diff == -1) return 'Yesterday$timeSuffix';
    if (diff < 0) return '${diff.abs()}d overdue$timeSuffix';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[todo.dueDate!.month - 1]} ${todo.dueDate!.day}$timeSuffix';
  }

  String _recurrenceLabel(Recurrence r) {
    switch (r) {
      case Recurrence.daily:
        return 'Daily';
      case Recurrence.weekly:
        return 'Weekly';
      case Recurrence.monthly:
        return 'Monthly';
      case Recurrence.none:
        return '';
    }
  }

  bool get _isOverdue {
    if (todo.dueDate == null || todo.isCompleted) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(
        todo.dueDate!.year, todo.dueDate!.month, todo.dueDate!.day);
    return d.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final label = _dueDateLabel();
    final overdue = _isOverdue;

    return Dismissible(
      key: Key(todo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.surface),
      ),
      confirmDismiss: (_) => Get.dialog<bool>(
        AlertDialog(
          title: const Text('Delete task?'),
          content: const Text('This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: todo.isCompleted
                        ? AppColors.success
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: todo.isCompleted
                          ? AppColors.success
                          : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  child: todo.isCompleted
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: AppColors.surface)
                      : null,
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: todo.isCompleted
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: AppColors.textMuted,
                      ),
                    ),
                    if (todo.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        todo.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (label != null || todo.recurrence != Recurrence.none) ...[
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (label != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: overdue
                                    ? AppColors.danger.withValues(alpha: 0.1)
                                    : label == 'Today'
                                        ? AppColors.primary
                                            .withValues(alpha: 0.15)
                                        : AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 10,
                                    color: overdue
                                        ? AppColors.danger
                                        : label == 'Today'
                                            ? AppColors.dark
                                            : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: overdue
                                          ? AppColors.danger
                                          : label == 'Today'
                                              ? AppColors.dark
                                              : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (todo.recurrence != Recurrence.none) ...[
                            if (label != null) const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.repeat_rounded,
                                    size: 10,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _recurrenceLabel(todo.recurrence),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ── Recurrence picker ──────────────────────────────────────────────────────

class _RecurrencePicker extends StatelessWidget {
  final Recurrence value;
  final ValueChanged<Recurrence> onChanged;

  const _RecurrencePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _kRecurrenceOptions.map((opt) {
            final (recurrence, label) = opt;
            final selected = value == recurrence;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(recurrence),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.dark
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Add sheet ──────────────────────────────────────────────────────────────

class _AddTodoSheet extends StatefulWidget {
  final TodoController controller;

  const _AddTodoSheet({required this.controller});

  @override
  State<_AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<_AddTodoSheet> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  Recurrence _recurrence = Recurrence.none;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.dark,
            onPrimary: AppColors.surface,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.dark,
            onPrimary: AppColors.surface,
            surface: AppColors.surface,
            secondary: AppColors.dark,
            onSecondary: AppColors.surface,
            // AM/PM toggle selected state
            tertiaryContainer: AppColors.dark,
            onTertiaryContainer: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    DateTime? combined;
    if (_dueDate != null) {
      final t = _dueTime;
      combined = t != null
          ? DateTime(
              _dueDate!.year, _dueDate!.month, _dueDate!.day, t.hour, t.minute)
          : DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
    }
    await widget.controller.addTodo(
      title: _titleCtrl.text,
      note: _noteCtrl.text,
      dueDate: combined,
      recurrence: combined != null ? _recurrence : Recurrence.none,
    );
    if (mounted) Navigator.pop(context);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              const Text(
                'New Task',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Title field
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Task title',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w400),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 10),

              // Note field
              TextField(
                controller: _noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textPrimary),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Note (optional)',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),

              const SizedBox(height: 12),

              // Due date + time row
              Row(
                children: [
                  // Date button
                  GestureDetector(
                    onTap: _pickDate,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _dueDate != null
                            ? AppColors.dark
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: _dueDate != null
                                ? AppColors.surface
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _dueDate != null
                                ? _formatDate(_dueDate!)
                                : 'Date',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _dueDate != null
                                  ? AppColors.surface
                                  : AppColors.textMuted,
                            ),
                          ),
                          if (_dueDate != null) ...[
                            const SizedBox(width: 7),
                            GestureDetector(
                              onTap: () => setState(() {
                                _dueDate = null;
                                _dueTime = null;
                                _recurrence = Recurrence.none;
                              }),
                              child: Icon(
                                Icons.close_rounded,
                                size: 13,
                                color: AppColors.surface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Time button — only visible once a date is chosen
                  if (_dueDate != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _pickTime,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _dueTime != null
                              ? AppColors.primary
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 15,
                              color: _dueTime != null
                                  ? AppColors.dark
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _dueTime != null
                                  ? _formatTime(_dueTime!)
                                  : 'Time',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _dueTime != null
                                    ? AppColors.dark
                                    : AppColors.textMuted,
                              ),
                            ),
                            if (_dueTime != null) ...[
                              const SizedBox(width: 7),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _dueTime = null),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Recurrence picker — only when a date is chosen
              if (_dueDate != null) ...[
                const SizedBox(height: 12),
                _RecurrencePicker(
                  value: _recurrence,
                  onChanged: (r) => setState(() => _recurrence = r),
                ),
              ],

              const SizedBox(height: 20),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    foregroundColor: AppColors.surface,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Text(
                          'Add Task',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
