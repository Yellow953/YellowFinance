import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/diary_entry_model.dart';
import '../../../routes/app_routes.dart';
import '../controllers/diary_controller.dart';

/// Diary screen — searchable list of entries grouped by day.
class DiaryView extends StatefulWidget {
  const DiaryView({super.key});

  @override
  State<DiaryView> createState() => _DiaryViewState();
}

class _DiaryViewState extends State<DiaryView> {
  final _ctrl = Get.find<DiaryController>();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Home's "write today" shortcut opens the editor straight away.
    if (Get.arguments == 'add') {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openEditor());
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openEditor({DiaryEntryModel? entry}) =>
      Get.toNamed(AppRoutes.DIARY_ENTRY, arguments: entry);

  void _showFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(controller: _ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onAdd: _openEditor),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: _ctrl,
                      field: _search,
                      onOpenFilters: () => _showFilters(context),
                    ),
                    _ActiveFilterBar(controller: _ctrl, field: _search),
                    Expanded(
                      child: Obx(() {
                        if (_ctrl.isLoading.value && _ctrl.entries.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          );
                        }

                        final days = _ctrl.entriesByDay;
                        if (days.isEmpty) {
                          final filtered = _ctrl.hasActiveFilters;
                          return AppEmptyState(
                            icon: filtered
                                ? Icons.search_off_rounded
                                : Icons.menu_book_outlined,
                            title: filtered
                                ? 'Nothing matches'
                                : 'Your diary is empty',
                            message: filtered
                                ? 'No entries fit these filters. Try widening the date range or clearing them.'
                                : 'Write it down or just say it — tap the mic and talk.',
                            actionLabel: filtered
                                ? 'Clear filters'
                                : 'Write your first entry',
                            onAction: filtered
                                ? () {
                                    _search.clear();
                                    _ctrl.clearFilters();
                                  }
                                : _openEditor,
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                          itemCount: days.length,
                          itemBuilder: (_, i) {
                            final day = days[i];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: i == 0 ? 8 : 20, bottom: 10),
                                  child: Text(
                                    _dayLabel(day.date),
                                    style: AppTextStyles.labelSmall,
                                  ),
                                ),
                                for (final e in day.entries)
                                  _EntryCard(
                                    entry: e,
                                    onTap: () => _openEditor(entry: e),
                                    onDelete: () =>
                                        _ctrl.deleteEntry(e.id),
                                  ),
                              ],
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'TODAY';
    if (diff == 1) return 'YESTERDAY';
    return Formatters.dateDayMonthFull(date).toUpperCase();
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onAdd;

  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: Get.back,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.surface, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Diary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.dark, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Search & filters ────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final DiaryController controller;
  final TextEditingController field;
  final VoidCallback onOpenFilters;

  const _SearchBar({
    required this.controller,
    required this.field,
    required this.onOpenFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.search_rounded,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: field,
                      onChanged: (v) => controller.query.value = v,
                      style: AppTextStyles.bodyMedium,
                      // The surrounding Container already draws the box;
                      // without this the themed fill and outline would stack a
                      // second one inside.
                      decoration: AppTheme.bareInput.copyWith(
                        hintText: 'Search your entries',
                        hintStyle: const TextStyle(
                            fontSize: 14, color: AppColors.textMuted),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  Obx(() => controller.query.value.isEmpty
                      ? const SizedBox(width: 14)
                      : GestureDetector(
                          onTap: () {
                            field.clear();
                            controller.query.value = '';
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.close_rounded,
                                size: 16, color: AppColors.textMuted),
                          ),
                        )),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filters live behind this rather than on the page: they are set
          // occasionally, and a row of chips costs list space permanently.
          Obx(() {
            final count = controller.activeFilterCount;
            final on = count > 0;
            return GestureDetector(
              onTap: onOpenFilters,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: on ? AppColors.dark : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: on ? AppColors.dark : AppColors.border,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: on ? AppColors.surface : AppColors.textPrimary,
                    ),
                    if (on)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Active filter summary ───────────────────────────────────────────────────

/// One-line reminder of what is currently narrowing the list, with a way out.
///
/// Without this a filter set once and forgotten looks like missing data.
class _ActiveFilterBar extends StatelessWidget {
  final DiaryController controller;
  final TextEditingController field;

  const _ActiveFilterBar({required this.controller, required this.field});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.hasActiveFilters) return const SizedBox(height: 4);

      final parts = <String>[];
      if (controller.moodFilter.isNotEmpty) {
        parts.add(controller.moodFilter.map((m) => m.emoji).join());
      }
      final from = controller.fromDate.value;
      final to = controller.toDate.value;
      if (from != null && to != null) {
        parts.add(
            '${Formatters.dateDayMonth(from)} – ${Formatters.dateDayMonth(to)}');
      } else if (from != null) {
        parts.add('from ${Formatters.dateDayMonth(from)}');
      } else if (to != null) {
        parts.add('until ${Formatters.dateDayMonth(to)}');
      }
      if (controller.oldestFirst.value) parts.add('oldest first');

      final count = controller.filteredEntries.length;

      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                parts.isEmpty
                    ? '$count matching'
                    : '$count matching · ${parts.join(' · ')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                field.clear();
                controller.clearFilters();
              },
              child: const Text(
                'Clear',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Entry card ──────────────────────────────────────────────────────────────

class _EntryCard extends StatelessWidget {
  final DiaryEntryModel entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(entry.id),
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
          title: const Text('Delete entry?'),
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (entry.mood != Mood.none) ...[
                    Text(entry.mood.emoji,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      entry.title.isEmpty ? 'Untitled' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: entry.title.isEmpty
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (entry.hasVoice)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.mic_rounded,
                          size: 14, color: AppColors.textMuted),
                    ),
                  if (entry.pendingSync)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.cloud_upload_outlined,
                          size: 14, color: AppColors.textMuted),
                    ),
                ],
              ),
              if (entry.preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  entry.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${entry.wordCount} ${entry.wordCount == 1 ? 'word' : 'words'}',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter sheet ────────────────────────────────────────────────────────────

/// Advanced filters, kept off the page so the list keeps its space.
///
/// Edits apply immediately to the controller rather than on a "Done" tap — the
/// list behind the sheet updates live, which makes narrowing a range feel
/// direct instead of blind.
class _FilterSheet extends StatelessWidget {
  final DiaryController controller;

  const _FilterSheet({required this.controller});

  Future<void> _pickDate(
    BuildContext context, {
    required bool isFrom,
  }) async {
    final now = DateTime.now();
    final current = isFrom ? controller.fromDate.value : controller.toDate.value;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.dark,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    if (isFrom) {
      controller.fromDate.value = day;
      // Keep the range coherent rather than silently returning nothing.
      final to = controller.toDate.value;
      if (to != null && to.isBefore(day)) controller.toDate.value = day;
    } else {
      controller.toDate.value = day;
      final from = controller.fromDate.value;
      if (from != null && from.isAfter(day)) controller.fromDate.value = day;
    }
  }

  /// Sets the range to the last [days] days, ending today.
  void _applyPreset(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    controller.fromDate.value = today.subtract(Duration(days: days - 1));
    controller.toDate.value = today;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text('Filters', style: AppTextStyles.titleLarge),
                ),
                Obx(() => controller.hasActiveFilters
                    ? GestureDetector(
                        onTap: controller.clearFilters,
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
            const SizedBox(height: 20),

            const Text('Date range', style: AppTextStyles.labelMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Obx(() => _DateField(
                        label: 'From',
                        value: controller.fromDate.value,
                        onTap: () => _pickDate(context, isFrom: true),
                        onClear: () => controller.fromDate.value = null,
                      )),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Obx(() => _DateField(
                        label: 'To',
                        value: controller.toDate.value,
                        onTap: () => _pickDate(context, isFrom: false),
                        onClear: () => controller.toDate.value = null,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                _PresetChip(label: 'Last 7 days', onTap: () => _applyPreset(7)),
                _PresetChip(
                    label: 'Last 30 days', onTap: () => _applyPreset(30)),
                _PresetChip(
                    label: 'Last 90 days', onTap: () => _applyPreset(90)),
              ],
            ),
            const SizedBox(height: 22),

            const Text('Mood', style: AppTextStyles.labelMedium),
            const SizedBox(height: 4),
            const Text(
              'Pick several to combine them.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Obx(() => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in Mood.values)
                      _FilterChip(
                        label: m == Mood.none
                            ? 'No mood'
                            : '${m.emoji} ${m.label}',
                        selected: controller.moodFilter.contains(m),
                        onTap: () => controller.toggleMood(m),
                      ),
                  ],
                )),
            const SizedBox(height: 22),

            const Text('Sort', style: AppTextStyles.labelMedium),
            const SizedBox(height: 10),
            Obx(() => _SwitchRow(
                  icon: Icons.swap_vert_rounded,
                  label: 'Oldest first',
                  value: controller.oldestFirst.value,
                  onChanged: (v) => controller.oldestFirst.value = v,
                )),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Obx(() {
                    final count = controller.filteredEntries.length;
                    return Center(
                        child: Text(
                          'Show $count ${count == 1 ? 'entry' : 'entries'}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.surface,
                          ),
                        ));
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final set = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: set ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.labelSmall),
                  const SizedBox(height: 2),
                  Text(
                    set ? Formatters.dateShort(value!) : 'Any',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          set ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (set)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 15, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.dark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}
