import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/safe_insets.dart';
import '../../../data/models/todo_model.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/sync_dot.dart';
import '../controllers/todo_controller.dart';

const _kRecurrenceOptions = [
  (Recurrence.none, 'None'),
  (Recurrence.daily, 'Daily'),
  (Recurrence.weekly, 'Weekly'),
  (Recurrence.monthly, 'Monthly'),
];

/// Tasks / to-do screen.
class TodosView extends StatefulWidget {
  const TodosView({super.key});

  @override
  State<TodosView> createState() => _TodosViewState();
}

class _TodosViewState extends State<TodosView> {
  late final TodoController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<TodoController>();
    if (Get.arguments == 'add') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddSheet(context, _ctrl);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;

    return Scaffold(
      backgroundColor: AppColors.dark,
      extendBody: true,
      bottomNavigationBar: AppNavBar(
        currentIndex: 1,
        onTap: (i) {
          if (i != 1) Get.offNamed(AppNavBar.routes[i]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.dark,
        onPressed: () => _showAddSheet(context, ctrl),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Dark header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      _ViewModeToggle(ctrl: ctrl),
                    ],
                  ),
                  // Filter chips — list mode only
                  Obx(() {
                    if (ctrl.viewMode.value != 'list') {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: SingleChildScrollView(
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
                      ),
                    );
                  }),
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
                  if (ctrl.viewMode.value == 'calendar') {
                    return _CalendarView(
                      ctrl: ctrl,
                      onEdit: (todo) => _showEditSheet(context, todo),
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
                      padding: EdgeInsets.fromLTRB(
                          20, 20, 20, 100 + AppNavBar.overlap(context)),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _TodoTile(
                        todo: items[i],
                        onToggle: () => ctrl.toggleComplete(items[i].id),
                        onDelete: () => ctrl.deleteTodo(items[i].id),
                        onEdit: () => _showEditSheet(context, items[i]),
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
    showAppSheet(
      context: context,
      builder: (_) => _AddTodoSheet(controller: ctrl),
    );
  }

  void _showEditSheet(BuildContext context, TodoModel todo) {
    showAppSheet(
      context: context,
      builder: (_) => _AddTodoSheet(controller: _ctrl, initialTodo: todo),
    );
  }
}

// ── Todo tile ──────────────────────────────────────────────────────────────

class _TodoTile extends StatelessWidget {
  final TodoModel todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _TodoTile({
    required this.todo,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
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

            // Content — tap to edit
            Expanded(
              child: GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            todo.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        ),
                        SyncDot(pending: todo.pendingSync),
                      ],
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
            ),

            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ── View-mode toggle ────────────────────────────────────────────────────────

/// Segmented List / Calendar switch shown in the dark header.
class _ViewModeToggle extends StatelessWidget {
  final TodoController ctrl;

  const _ViewModeToggle({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = ctrl.viewMode.value;
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            _segment(
              icon: Icons.format_list_bulleted_rounded,
              selected: mode == 'list',
              onTap: () => ctrl.viewMode.value = 'list',
            ),
            _segment(
              icon: Icons.calendar_month_rounded,
              selected: mode == 'calendar',
              onTap: () => ctrl.viewMode.value = 'calendar',
            ),
          ],
        ),
      );
    });
  }

  Widget _segment({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(
          icon,
          size: 18,
          color: selected ? AppColors.dark : AppColors.textMuted,
        ),
      ),
    );
  }
}

// ── Calendar view ───────────────────────────────────────────────────────────

const _kWeekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Month grid with per-day task markers, plus the selected day's task list.
class _CalendarView extends StatelessWidget {
  final TodoController ctrl;
  final void Function(TodoModel) onEdit;

  const _CalendarView({required this.ctrl, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final month = ctrl.focusedMonth.value;
      final selected = ctrl.selectedDay.value;
      final dayTasks = ctrl.todosForDay(selected);

      return ListView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 100 + AppNavBar.overlap(context)),
        children: [
          _buildMonthCard(month, selected),
          const SizedBox(height: 20),
          _buildSelectedHeader(selected, dayTasks.length),
          const SizedBox(height: 12),
          if (dayTasks.isEmpty)
            _buildEmptyDay()
          else
            ...dayTasks.map(
              (t) => _TodoTile(
                todo: t,
                onToggle: () => ctrl.toggleComplete(t.id),
                onDelete: () => ctrl.deleteTodo(t.id),
                onEdit: () => onEdit(t),
              ),
            ),
        ],
      );
    });
  }

  Widget _buildMonthCard(DateTime month, DateTime selected) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Month header with navigation arrows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_kMonthNames[month.month - 1]} ${month.year}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    _navButton(
                      Icons.chevron_left_rounded,
                      ctrl.goToPreviousMonth,
                    ),
                    const SizedBox(width: 4),
                    _navButton(
                      Icons.chevron_right_rounded,
                      ctrl.goToNextMonth,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Weekday labels
          Row(
            children: _kWeekdayLabels
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          _buildDayGrid(month, selected),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildDayGrid(DateTime month, DateTime selected) {
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Sunday-first grid: DateTime.weekday is Mon=1..Sun=7 → Sun maps to 0.
    final leadingBlanks = firstOfMonth.weekday % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNum = cellIndex - leadingBlanks + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const Expanded(child: SizedBox(height: 44));
            }
            final date = DateTime(month.year, month.month, dayNum);
            final isSelected = date == selected;
            final isToday = date == today;
            final hasTasks = ctrl.hasTasksOn(date);

            return Expanded(
              child: GestureDetector(
                onTap: () => ctrl.selectDay(date),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.dark
                            : isToday
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isToday || isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.surface
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasTasks
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildSelectedHeader(DateTime selected, int count) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = selected.difference(today).inDays;
    String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Tomorrow';
    } else if (diff == -1) {
      label = 'Yesterday';
    } else {
      label = '${_kMonthNames[selected.month - 1]} ${selected.day}';
    }

    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          count == 1 ? '1 task' : '$count tasks',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyDay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No tasks on this day',
        style: TextStyle(
          fontSize: 14,
          color: AppColors.textMuted,
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
                    color: selected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
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
  final TodoModel? initialTodo;

  const _AddTodoSheet({required this.controller, this.initialTodo});

  @override
  State<_AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<_AddTodoSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  Recurrence _recurrence = Recurrence.none;
  bool _saving = false;

  bool get _isEditing => widget.initialTodo != null;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTodo;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _noteCtrl = TextEditingController(text: t?.note ?? '');
    if (t?.dueDate != null) {
      _dueDate = DateTime(
          t!.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      if (t.dueDate!.hour != 0 || t.dueDate!.minute != 0) {
        _dueTime = TimeOfDay(
            hour: t.dueDate!.hour, minute: t.dueDate!.minute);
      }
      _recurrence = t.recurrence;
    }
  }

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
    if (_isEditing) {
      await widget.controller.updateTodo(
        id: widget.initialTodo!.id,
        title: _titleCtrl.text,
        note: _noteCtrl.text,
        dueDate: combined,
        recurrence: combined != null ? _recurrence : Recurrence.none,
      );
    } else {
      await widget.controller.addTodo(
        title: _titleCtrl.text,
        note: _noteCtrl.text,
        dueDate: combined,
        recurrence: combined != null ? _recurrence : Recurrence.none,
      );
    }
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
    return Padding(
      padding: EdgeInsets.only(bottom: context.sheetBottomInset),
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

            Text(
              _isEditing ? 'Edit Task' : 'New Task',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            // Title field
            AppTextField(
              label: 'Task title',
              controller: _titleCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),

            const SizedBox(height: 12),

            // Note field
            AppTextField(
              label: 'Note (optional)',
              controller: _noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
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
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _dueDate != null
                            ? AppColors.dark
                            : AppColors.border,
                      ),
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
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _dueTime != null
                              ? AppColors.primary
                              : AppColors.border,
                        ),
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
                    : Text(
                        _isEditing ? 'Save Changes' : 'Add Task',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
