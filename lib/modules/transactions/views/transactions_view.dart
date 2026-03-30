import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/transaction_controller.dart';

/// Full transactions list screen.
class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  final _controller = Get.find<TransactionController>();
  final _authCtrl = Get.find<AuthController>();
  final _scrollCtrl = ScrollController();

  static const _routes = [
    AppRoutes.HOME,
    AppRoutes.TODOS,
    AppRoutes.PORTFOLIO,
    AppRoutes.REPORTS,
    AppRoutes.AI_CHAT,
  ];

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _controller.loadNextPage();
    }
  }

  bool get _isFiltered =>
      _controller.filterPeriod.value != 'This Month' ||
      _controller.filterCategory.value != 'All';

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(controller: _controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      bottomNavigationBar: AppNavBar(
        currentIndex: -1,
        onTap: (i) => Get.offNamed(_routes[i]),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.dark,
        onPressed: () => Get.toNamed(AppRoutes.ADD_TRANSACTION),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dark header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Obx(() => GestureDetector(
                            onTap: _openFilterSheet,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _isFiltered
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.tune_rounded,
                                    size: 18,
                                    color: _isFiltered
                                        ? AppColors.dark
                                        : AppColors.textMuted,
                                  ),
                                ),
                                if (_isFiltered)
                                  Positioned(
                                    top: -3,
                                    right: -3,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.danger,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )),
                      const SizedBox(width: 8),
                      Obx(() => GestureDetector(
                            onTap: _authCtrl.toggleHideBalances,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _authCtrl.hideBalances.value
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: AppColors.textMuted,
                              ),
                            ),
                          )),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Obx(() {
                    final periodLabel =
                        _controller.filterPeriod.value == 'Custom'
                            ? _customLabel()
                            : _controller.filterPeriod.value;
                    final catLabel = _controller.filterCategory.value == 'All'
                        ? ''
                        : ' · ${_controller.filterCategory.value}';
                    return Text(
                      '${_controller.filteredTransactions.length} records · $periodLabel$catLabel',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textMuted),
                    );
                  }),
                ],
              ),
            ),

            // White card
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Obx(() {
                  if (_controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    );
                  }
                  final groups = _controller.filteredTransactionsByDay;
                  if (groups.isEmpty) {
                    return Center(
                      child: Text(
                        _controller.transactions.isEmpty
                            ? 'No transactions yet'
                            : 'No matches',
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _controller.refresh,
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount:
                          groups.length + (_controller.hasMore.value ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == groups.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Obx(() => _controller.isLoadingMore.value
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const SizedBox.shrink()),
                          );
                        }
                        final group = groups[i];
                        return _TxnDayGroup(
                          date: group.date,
                          transactions: group.txns,
                          hideAmount: _authCtrl.hideBalances.value,
                          onDelete: _controller.deleteTransaction,
                        );
                      },
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

  String _customLabel() {
    final s = _controller.customStart.value;
    final e = _controller.customEnd.value;
    if (s == null || e == null) return 'Custom';
    String fmt(DateTime d) =>
        '${d.day}/${d.month}/${d.year.toString().substring(2)}';
    return '${fmt(s)} – ${fmt(e)}';
  }
}

// ── Day group ──────────────────────────────────────────────────────────────

class _TxnDayGroup extends StatelessWidget {
  final DateTime date;
  final List<TransactionModel> transactions;
  final bool hideAmount;
  final void Function(String) onDelete;

  const _TxnDayGroup({
    required this.date,
    required this.transactions,
    required this.hideAmount,
    required this.onDelete,
  });

  Future<bool?> _confirmDelete(BuildContext context) => Get.dialog<bool>(
        AlertDialog(
          title: const Text('Delete transaction?'),
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
              for (var i = 0; i < transactions.length; i++) ...[
                Dismissible(
                  key: Key(transactions[i].id),
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
                        bottomLeft: i == transactions.length - 1
                            ? const Radius.circular(12)
                            : Radius.zero,
                        bottomRight: i == transactions.length - 1
                            ? const Radius.circular(12)
                            : Radius.zero,
                      ),
                    ),
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.surface),
                  ),
                  confirmDismiss: (_) => _confirmDelete(context),
                  onDismissed: (_) => onDelete(transactions[i].id),
                  child: TransactionTile(
                    transaction: transactions[i],
                    hideAmount: hideAmount,
                  ),
                ),
                if (i < transactions.length - 1)
                  const Divider(height: 1, indent: 72, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Filter Bottom Sheet ────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final TransactionController controller;

  const _FilterSheet({required this.controller});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _period;
  late String _category;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _period = widget.controller.filterPeriod.value;
    _category = widget.controller.filterCategory.value;
    _rangeStart = widget.controller.customStart.value;
    _rangeEnd = widget.controller.customEnd.value;
  }

  void _apply() {
    if (_period == 'Custom') {
      if (_rangeStart != null && _rangeEnd != null) {
        widget.controller.setCustomRange(_rangeStart!, _rangeEnd!);
      }
    } else {
      widget.controller.setFilterPeriod(_period);
    }
    widget.controller.setFilterCategory(_category);
    Navigator.pop(context);
  }

  void _reset() {
    widget.controller.setFilterPeriod('This Month');
    widget.controller.setFilterCategory('All');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All', ...widget.controller.filterCategories];
    final showCalendar = _period == 'Custom';

    return SafeArea(
      top: false,
      child: Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
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

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ── Period ────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Date period',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...TransactionController.filterPeriods.map((p) =>
                      _OptionChip(
                        label: p,
                        selected: _period == p,
                        onTap: () => setState(() => _period = p),
                      )),
                  _OptionChip(
                    label: 'Custom range',
                    selected: _period == 'Custom',
                    icon: Icons.calendar_today_rounded,
                    onTap: () => setState(() => _period = 'Custom'),
                  ),
                ],
              ),
            ),

            // ── Inline calendar (custom range) ────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: showCalendar
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 20),
                      child: _InlineCalendar(
                        initialStart: _rangeStart,
                        initialEnd: _rangeEnd,
                        onRangeChanged: (s, e) {
                          setState(() {
                            _rangeStart = s;
                            _rangeEnd = e;
                          });
                        },
                      ),
                    )
                  : const SizedBox(height: 20),
            ),

            // ── Category ──────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map((c) => _OptionChip(
                          label: c,
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                          isSecondary: true,
                        ))
                    .toList(),
              ),
            ),

            const SizedBox(height: 24),

            // Apply button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_period == 'Custom' &&
                          (_rangeStart == null || _rangeEnd == null))
                      ? null
                      : _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    disabledBackgroundColor:
                        AppColors.border,
                    foregroundColor: AppColors.surface,
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Apply',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
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

// ── Inline calendar ────────────────────────────────────────────────────────

class _InlineCalendar extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final void Function(DateTime? start, DateTime? end) onRangeChanged;

  const _InlineCalendar({
    required this.initialStart,
    required this.initialEnd,
    required this.onRangeChanged,
  });

  @override
  State<_InlineCalendar> createState() => _InlineCalendarState();
}

class _InlineCalendarState extends State<_InlineCalendar> {
  late DateTime _month;
  DateTime? _start;
  DateTime? _end;

  static const _weekdays = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    final now = DateTime.now();
    _month = DateTime(_start?.year ?? now.year, _start?.month ?? now.month);
  }

  void _onDayTap(DateTime day) {
    if (day.isAfter(DateTime.now())) return;
    setState(() {
      if (_start == null || (_start != null && _end != null)) {
        // Start fresh
        _start = day;
        _end = null;
      } else {
        // Have start, picking end
        if (day.isBefore(_start!)) {
          _start = day;
        } else if (_isSameDay(day, _start!)) {
          _start = null;
        } else {
          _end = day;
        }
      }
    });
    widget.onRangeChanged(_start, _end);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isInRange(DateTime day) {
    if (_start == null || _end == null) return false;
    return day.isAfter(_start!) && day.isBefore(_end!);
  }

  List<DateTime?> _buildDays() {
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    // Monday = 1, so offset = weekday - 1
    final offset = firstOfMonth.weekday - 1;
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    final cells = <DateTime?>[];
    for (var i = 0; i < offset; i++) { cells.add(null); }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_month.year, _month.month, d));
    }
    // Pad to full rows
    while (cells.length % 7 != 0) { cells.add(null); }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildDays();
    final now = DateTime.now();
    final canGoNext = DateTime(_month.year, _month.month + 1)
        .isBefore(DateTime(now.year, now.month + 1));

    return Column(
      children: [
        // Selected range display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _DateBox(
                  label: 'From',
                  date: _start,
                  isActive: _start != null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: (_start != null && _end != null)
                      ? AppColors.dark
                      : AppColors.border,
                ),
              ),
              Expanded(
                child: _DateBox(
                  label: 'To',
                  date: _end,
                  isActive: _end != null,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Month navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => setState(() => _month =
                    DateTime(_month.year, _month.month - 1)),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: canGoNext
                    ? () => setState(() =>
                        _month = DateTime(_month.year, _month.month + 1))
                    : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Weekday headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _weekdays
                .map((d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),

        const SizedBox(height: 4),

        // Day grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: days.map((day) => _buildCell(day, now)).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Hint text
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            _start == null
                ? 'Tap a start date'
                : _end == null
                    ? 'Tap an end date'
                    : '',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell(DateTime? day, DateTime now) {
    if (day == null) return const SizedBox();

    final isStart = _start != null && _isSameDay(day, _start!);
    final isEnd = _end != null && _isSameDay(day, _end!);
    final inRange = _isInRange(day);
    final isToday = _isSameDay(day, now);
    final isFuture = day.isAfter(now);
    final isSingleDay =
        isStart && _end != null && _isSameDay(_start!, _end!);

    return GestureDetector(
      onTap: isFuture ? null : () => _onDayTap(day),
      child: SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Range strip (left half)
            if ((inRange || isEnd) && !isSingleDay)
              Positioned(
                left: 0,
                top: 4,
                bottom: 4,
                width: MediaQuery.of(context).size.width / 7 / 2,
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
            // Range strip (right half)
            if ((inRange || isStart) && _end != null && !isSingleDay)
              Positioned(
                right: 0,
                top: 4,
                bottom: 4,
                width: MediaQuery.of(context).size.width / 7 / 2,
                child: Container(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
            // Circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (isStart || isEnd)
                    ? AppColors.dark
                    : inRange
                        ? Colors.transparent
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isStart && !isEnd
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: (isStart || isEnd || isToday)
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: isFuture
                        ? AppColors.border
                        : (isStart || isEnd)
                            ? AppColors.surface
                            : inRange
                                ? AppColors.dark
                                : AppColors.textPrimary,
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

// ── Date box ───────────────────────────────────────────────────────────────

class _DateBox extends StatelessWidget {
  final String label;
  final DateTime? date;
  final bool isActive;

  const _DateBox({
    required this.label,
    required this.date,
    required this.isActive,
  });

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? AppColors.dark : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.dark : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? AppColors.surface.withValues(alpha: 0.6)
                  : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            date != null
                ? '${_months[date!.month - 1]} ${date!.day}, ${date!.year}'
                : '—',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color:
                  isActive ? AppColors.surface : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav button ─────────────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.background : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? AppColors.textPrimary : AppColors.border,
        ),
      ),
    );
  }
}

// ── Option chip ────────────────────────────────────────────────────────────

class _OptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isSecondary;
  final IconData? icon;

  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isSecondary = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: isSecondary ? 12 : 14,
          vertical: isSecondary ? 7 : 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? (isSecondary
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.dark)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isSecondary ? AppColors.primary : AppColors.dark)
                : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 12,
                  color: selected
                      ? (isSecondary ? AppColors.dark : AppColors.surface)
                      : AppColors.textMuted),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: isSecondary ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? (isSecondary ? AppColors.dark : AppColors.surface)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
