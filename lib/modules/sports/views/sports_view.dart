import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../controllers/sport_controller.dart';

/// Sports records screen — log and browse workout activity by day.
class SportsView extends StatefulWidget {
  const SportsView({super.key});

  @override
  State<SportsView> createState() => _SportsViewState();
}

class _SportsViewState extends State<SportsView> {
  late final SportController _ctrl;

  static const _routes = [
    AppRoutes.HOME,
    AppRoutes.TODOS,
    AppRoutes.SPORTS,
    AppRoutes.PORTFOLIO,
    AppRoutes.REPORTS,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<SportController>();
    // Auto-open the add sheet when navigated with the 'add' argument
    // (e.g. from the home screen "Add Sport" pill).
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
      bottomNavigationBar: AppNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i != 2) Get.offNamed(_routes[i]);
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
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + month nav
                  Row(
                    children: [
                      const Text(
                        'Sports',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      // Month navigation
                      GestureDetector(
                        onTap: ctrl.previousMonth,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_left_rounded,
                              color: AppColors.surface, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Obx(() => GestureDetector(
                            onTap: () => _pickMonthYear(context, ctrl),
                            child: Text(
                              Formatters.dateMonthYear(
                                  ctrl.selectedMonth.value),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.surface,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.textMuted,
                              ),
                            ),
                          )),
                      const SizedBox(width: 10),
                      Obx(() => GestureDetector(
                            onTap: ctrl.canGoToNextMonth
                                ? ctrl.nextMonth
                                : null,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: ctrl.canGoToNextMonth
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: ctrl.canGoToNextMonth
                                    ? AppColors.surface
                                    : AppColors.textMuted,
                                size: 20,
                              ),
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Category filter chips
                  Obx(() => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            'All',
                            ...AppConstants.sportCategories,
                          ].map((cat) {
                            final selected = ctrl.filterCategory.value == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    ctrl.filterCategory.value = cat,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : Colors.white
                                            .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    cat,
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
                  final groups = ctrl.filteredByDay;
                  if (groups.isEmpty) {
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
                              Icons.fitness_center_rounded,
                              color: AppColors.textMuted,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('No records this month',
                              style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: groups.length,
                    itemBuilder: (_, i) => _SportDayGroup(
                      date: groups[i].date,
                      records: groups[i].records,
                      onDelete: ctrl.deleteRecord,
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

  Future<void> _pickMonthYear(
      BuildContext context, SportController ctrl) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthYearPickerDialog(
        current: ctrl.selectedMonth.value,
      ),
    );
    if (picked != null) {
      ctrl.selectedMonth.value = picked;
      ctrl.filterCategory.value = 'All';
    }
  }

  void _showAddSheet(BuildContext context, SportController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRecordSheet(controller: ctrl),
    );
  }
}

// ── Month / year picker dialog ────────────────────────────────────────────

class _MonthYearPickerDialog extends StatefulWidget {
  final DateTime current;
  const _MonthYearPickerDialog({required this.current});

  @override
  State<_MonthYearPickerDialog> createState() =>
      _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  late int _year;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _year = widget.current.year;
    _selectedMonth = widget.current.month;
  }

  bool _isFuture(int month) {
    final now = DateTime.now();
    return _year > now.year ||
        (_year == now.year && month > now.month);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final canGoNextYear = _year < now.year;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Year navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => setState(() => _year--),
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                _NavBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: canGoNextYear
                      ? () => setState(() => _year++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Month grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              children: List.generate(12, (i) {
                final month = i + 1;
                final isSelected =
                    _year == widget.current.year &&
                        month == _selectedMonth &&
                        _year == widget.current.year;
                final future = _isFuture(month);
                return GestureDetector(
                  onTap: future
                      ? null
                      : () {
                          Navigator.pop(
                              context, DateTime(_year, month));
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _months[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: future
                              ? AppColors.border
                              : isSelected
                                  ? AppColors.dark
                                  : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppColors.background
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color:
              onTap != null ? AppColors.textPrimary : AppColors.border,
        ),
      ),
    );
  }
}

// ── Day group ──────────────────────────────────────────────────────────────

class _SportDayGroup extends StatelessWidget {
  final DateTime date;
  final List<SportRecordModel> records;
  final void Function(String) onDelete;

  const _SportDayGroup({
    required this.date,
    required this.records,
    required this.onDelete,
  });

  Future<bool?> _confirmDelete(BuildContext context) => Get.dialog<bool>(
        AlertDialog(
          title: const Text('Delete record?'),
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
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            Formatters.dateDayMonthFull(date),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < records.length; i++) ...[
                Dismissible(
                  key: Key(records[i].id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.only(
                        topLeft: i == 0
                            ? const Radius.circular(12)
                            : Radius.zero,
                        topRight: i == 0
                            ? const Radius.circular(12)
                            : Radius.zero,
                        bottomLeft: i == records.length - 1
                            ? const Radius.circular(12)
                            : Radius.zero,
                        bottomRight: i == records.length - 1
                            ? const Radius.circular(12)
                            : Radius.zero,
                      ),
                    ),
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.surface),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context),
                  onDismissed: (_) => onDelete(records[i].id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            records[i].category,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Description
                        Expanded(
                          child: Text(
                            records[i].description.isEmpty
                                ? '—'
                                : records[i].description,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (i < records.length - 1)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Category grid ──────────────────────────────────────────────────────────

class _SportCategoryGrid extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const _SportCategoryGrid({
    required this.selected,
    required this.onChanged,
  });

  static const _items = [
    (label: 'Push Ups', icon: Icons.fitness_center_rounded),
    (label: 'Pull Ups', icon: Icons.arrow_upward_rounded),
    (label: 'ABS', icon: Icons.accessibility_new_rounded),
    (label: 'Running', icon: Icons.directions_run_rounded),
    (label: 'Walking', icon: Icons.directions_walk_rounded),
    (label: 'Activity', icon: Icons.sports_basketball_rounded),
    (label: 'Gym', icon: Icons.sports_mma_rounded),
    (label: 'Other', icon: Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: _items.map((item) {
          final isSelected = selected == item.label;
          return GestureDetector(
            onTap: () => onChanged(item.label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 82,
              height: 82,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 26,
                    color: isSelected ? AppColors.dark : AppColors.textMuted,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.dark
                          : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Add sheet ──────────────────────────────────────────────────────────────

class _AddRecordSheet extends StatefulWidget {
  final SportController controller;

  const _AddRecordSheet({required this.controller});

  @override
  State<_AddRecordSheet> createState() => _AddRecordSheetState();
}

class _AddRecordSheetState extends State<_AddRecordSheet> {
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = AppConstants.sportCategories.first;
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
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
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.controller.addRecord(
      date: _date,
      category: _category,
      description: _descCtrl.text,
    );
    if (mounted) Navigator.pop(context);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dd = DateTime(d.year, d.month, d.day);
    if (dd == today) return 'Today';
    if (dd == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
                'Add Activity',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Date picker
              GestureDetector(
                onTap: _pickDate,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 15, color: AppColors.surface),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(_date),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Category label
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              _SportCategoryGrid(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),

              const SizedBox(height: 16),

              // Description field
              AppTextField(
                label: 'Description',
                hint: 'e.g. 50 PU, 100 ABS',
                controller: _descCtrl,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 1,
                prefixIcon: const Icon(
                  Icons.notes_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),

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
                          'Add Record',
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
