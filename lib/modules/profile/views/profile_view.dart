import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/app_lock_service.dart';
import '../../../core/services/home_category_filter_service.dart';
import '../../../core/services/nofap_notification_service.dart';
import '../../../core/services/sport_reminder_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/validators.dart';
import '../../../modules/auth/controllers/auth_controller.dart';
import '../../../modules/home/controllers/home_controller.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Profile screen — view and edit user info.
class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final _controller = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Dark header
            Container(
              color: AppColors.dark,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              child: Column(
                children: [
                  // Back button row
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
                      const Spacer(),
                      GestureDetector(
                        onTap: _controller.signOut,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.logout_rounded,
                                  size: 14, color: AppColors.textMuted),
                              SizedBox(width: 6),
                              Text(
                                'Sign out',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Avatar + name
                  Obx(() {
                    final user = _controller.user.value;
                    final name = user?.displayName ?? '';
                    final email = user?.email ?? '';
                    final photoUrl = user?.photoUrl ?? '';
                    final initials = _initials(name);

                    return Column(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            image: photoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: photoUrl.isEmpty
                              ? Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.dark,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.surface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Profile',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 20),
                      _EditNameSection(controller: _controller),
                      const SizedBox(height: 32),
                      Obx(() => _controller.user.value?.createdAt != null
                          ? _InfoRow(
                              label: 'Member since',
                              value: _formatDate(
                                  _controller.user.value!.createdAt),
                            )
                          : const SizedBox.shrink()),
                      const SizedBox(height: 8),
                      Obx(() => _InfoRow(
                            label: 'Email',
                            value: _controller.user.value?.email ?? '—',
                          )),
                      const SizedBox(height: 32),
                      const _SecuritySection(),
                      const SizedBox(height: 32),
                      const _HomeCategoriesSection(),
                      const SizedBox(height: 32),
                      const _SportReminderSection(),
                      const SizedBox(height: 32),
                      const _NofapSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatDate(DateTime dt) =>
      '${_monthName(dt.month)} ${dt.year}';

  String _monthName(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];
}

// ── Security section ──────────────────────────────────────────────────────

/// Biometric app lock toggle.
class _SecuritySection extends StatefulWidget {
  const _SecuritySection();

  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  final _lock = Get.find<AppLockService>();

  /// Null until the platform check resolves — the toggle stays disabled until
  /// then so it can't be flipped on a device that can't honour it.
  bool? _supported;
  String _label = 'Biometrics';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final supported = await _lock.isDeviceSupported();
    final label = await _lock.biometricLabel();
    if (!mounted) return;
    setState(() {
      _supported = supported;
      _label = label;
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _busy = true);
    final changed = await _lock.setEnabled(value);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!changed) {
      // Enabling requires a successful prompt; a cancel leaves it off. A plain
      // cancel needs no message — the user just dismissed their own prompt.
      final reason = _lock.lastFailureMessage;
      if (reason != null) AppSnackbar.error(reason);
      return;
    }
    AppSnackbar.success(
      value ? 'App lock is on.' : 'App lock is off.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final supported = _supported;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Security', style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.dark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fingerprint_rounded,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'App Lock',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supported == false
                            ? 'No biometrics or passcode set on this device'
                            : 'Require $_label to open ${AppConstants.appName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Obx(() => Switch.adaptive(
                      value: _lock.isEnabled.value,
                      onChanged:
                          (supported ?? false) && !_busy ? _toggle : null,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor:
                          AppColors.primary.withValues(alpha: 0.4),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Edit name section ─────────────────────────────────────────────────────

class _EditNameSection extends StatefulWidget {
  final AuthController controller;
  const _EditNameSection({required this.controller});

  @override
  State<_EditNameSection> createState() => _EditNameSectionState();
}

class _EditNameSectionState extends State<_EditNameSection> {
  late final TextEditingController _nameCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.controller.user.value?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Display Name',
            controller: _nameCtrl,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            validator: Validators.displayName,
            prefixIcon: const Icon(Icons.person_outline_rounded,
                color: AppColors.textMuted, size: 20),
          ),
          const SizedBox(height: 14),
          Obx(() => AppButton(
                label: 'Save Name',
                isLoading: widget.controller.isLoading.value,
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.controller.updateProfile(
                        displayName: _nameCtrl.text.trim());
                  }
                },
              )),
        ],
      ),
    );
  }
}

// ── Home categories section ───────────────────────────────────────────────

/// Lets the user choose which income / expense categories feed the Home
/// screen. Deselected categories are skipped in the Home totals and hidden
/// from its recent transactions list — they stay untouched everywhere else.
class _HomeCategoriesSection extends StatelessWidget {
  const _HomeCategoriesSection();

  @override
  Widget build(BuildContext context) {
    final filter = Get.find<HomeCategoryFilterService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Home Screen', style: AppTextStyles.titleMedium),
        const SizedBox(height: 6),
        const Text(
          'Categories counted in your Home totals.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _CategoryGroup(
                title: 'INCOME',
                icon: Icons.arrow_upward_rounded,
                accent: AppColors.success,
                categories: AppConstants.incomeCategories,
                income: true,
                filter: filter,
              ),
              const Divider(height: 1, color: AppColors.border),
              _CategoryGroup(
                title: 'EXPENSES',
                icon: Icons.arrow_downward_rounded,
                accent: AppColors.danger,
                categories: AppConstants.expenseCategories,
                income: false,
                filter: filter,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<String> categories;
  final bool income;
  final HomeCategoryFilterService filter;

  const _CategoryGroup({
    required this.title,
    required this.icon,
    required this.accent,
    required this.categories,
    required this.income,
    required this.filter,
  });

  bool _isOn(String category) =>
      filter.isCategoryIncluded(income: income, category: category);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 13, color: accent),
              ),
              const SizedBox(width: 10),
              Text(title, style: AppTextStyles.labelSmall),
              const Spacer(),
              // Tap the counter to flip the whole group on/off — 7 taps to
              // isolate one category is a chore otherwise.
              Obx(() {
                final on = categories.where(_isOn).length;
                final allOn = on == categories.length;
                return GestureDetector(
                  onTap: () => filter.setSelection(
                    income: income,
                    categories: categories,
                    // Clearing leaves the first category on, so Home never
                    // shows a total with nothing behind it.
                    included: allOn
                        ? {categories.first}
                        : categories.toSet(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Text(
                      allOn ? 'All' : '$on of ${categories.length}',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: allOn
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 14),
          Obx(() => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((category) {
                  return _CategoryToggleChip(
                    label: category,
                    selected: _isOn(category),
                    onTap: () => filter.setCategoryIncluded(
                      income: income,
                      category: category,
                      included: !_isOn(category),
                    ),
                  );
                }).toList(),
              )),
        ],
      ),
    );
  }
}

/// Toggle chip. "On" is the resting state — a soft yellow tint rather than a
/// solid fill, so a full card doesn't turn into a wall of accent colour. "Off"
/// recedes into the page background.
class _CategoryToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(10, 7, 13, 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed-width slot so chips don't resize when toggled.
            SizedBox(
              width: 16,
              height: 16,
              child: selected
                  ? Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 11, color: AppColors.dark),
                    )
                  : const Center(
                      child: Icon(Icons.circle_outlined,
                          size: 13, color: AppColors.textMuted),
                    ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color:
                    selected ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sport streak reminder section ─────────────────────────────────────────

class _SportReminderSection extends StatefulWidget {
  const _SportReminderSection();

  @override
  State<_SportReminderSection> createState() => _SportReminderSectionState();
}

class _SportReminderSectionState extends State<_SportReminderSection> {
  bool _enabled = false;
  int _hour = 23;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await SportReminderService.isEnabled();
    final hour = await SportReminderService.savedHour();
    final minute = await SportReminderService.savedMinute();
    if (mounted) {
      setState(() {
        _enabled = enabled;
        _hour = hour;
        _minute = minute;
      });
    }
  }

  /// Reads the current streak state from HomeController (kept alive underneath
  /// the profile route) so the reminder schedules immediately and correctly.
  Future<void> _resync() async {
    final home =
        Get.isRegistered<HomeController>() ? Get.find<HomeController>() : null;
    await SportReminderService.sync(
      hasStreak: (home?.sportStreakDays.value ?? 0) > 0,
      loggedToday: home?.sportLoggedToday ?? false,
    );
  }

  Future<void> _toggle(bool value) async {
    await SportReminderService.setEnabled(value);
    await _resync();
    if (mounted) setState(() => _enabled = value);
    Get.snackbar(
      value ? 'Reminders On' : 'Reminders Off',
      value
          ? 'You\'ll be nudged at ${_timeLabel()} if your streak is at risk.'
          : 'Sport streak reminders disabled.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.dark,
      colorText: AppColors.surface,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.dark,
                secondary: AppColors.primary,
                onSecondary: AppColors.dark,
                tertiary: AppColors.primary,
                onTertiary: AppColors.dark,
                tertiaryContainer: AppColors.primary,
                onTertiaryContainer: AppColors.dark,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        child: MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    await SportReminderService.setTime(hour: _hour, minute: _minute);
    if (_enabled) {
      await _resync();
      Get.snackbar(
        'Time Updated',
        'Reminder rescheduled for ${_timeLabel()}',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.dark,
        colorText: AppColors.surface,
        duration: const Duration(seconds: 2),
      );
    }
  }

  String _timeLabel() {
    final h = _hour % 12 == 0 ? 12 : _hour % 12;
    final m = _minute.toString().padLeft(2, '0');
    final period = _hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Streak', style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('🏃', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sport Streak Reminder',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Nudge to log your entry when your streak is at risk',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enabled,
                      onChanged: _toggle,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor:
                          AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
              if (_enabled) ...[
                Divider(height: 1, color: AppColors.border),
                InkWell(
                  onTap: _pickTime,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        const Text(
                          'Reminder time',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeLabel(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── No-Fap reminder section ───────────────────────────────────────────────

class _NofapSection extends StatefulWidget {
  const _NofapSection();

  @override
  State<_NofapSection> createState() => _NofapSectionState();
}

class _NofapSectionState extends State<_NofapSection> {
  bool _enabled = false;
  int _hour = 23;
  int _minute = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await NofapNotificationService.isEnabled();
    final hour = await NofapNotificationService.savedHour();
    final minute = await NofapNotificationService.savedMinute();
    if (mounted) setState(() { _enabled = enabled; _hour = hour; _minute = minute; });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      await NofapNotificationService.enable(hour: _hour, minute: _minute);
    } else {
      await NofapNotificationService.disable();
    }
    if (mounted) setState(() => _enabled = value);
    Get.snackbar(
      value ? 'Reminders On' : 'Reminders Off',
      value ? 'Daily reminder set for ${_timeLabel()}' : 'No-Fap reminders disabled.',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: AppColors.dark,
      colorText: AppColors.surface,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.dark,
                secondary: AppColors.primary,
                onSecondary: AppColors.dark,
                // M3 AM/PM selector uses tertiaryContainer for selected bg
                tertiary: AppColors.primary,
                onTertiary: AppColors.dark,
                tertiaryContainer: AppColors.primary,
                onTertiaryContainer: AppColors.dark,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        child: MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (picked == null) return;
    setState(() { _hour = picked.hour; _minute = picked.minute; });
    if (_enabled) {
      await NofapNotificationService.enable(hour: _hour, minute: _minute);
      Get.snackbar(
        'Time Updated',
        'Reminder rescheduled for ${_timeLabel()}',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        backgroundColor: AppColors.dark,
        colorText: AppColors.surface,
        duration: const Duration(seconds: 2),
      );
    }
  }

  String _timeLabel() {
    final h = _hour % 12 == 0 ? 12 : _hour % 12;
    final m = _minute.toString().padLeft(2, '0');
    final period = _hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Discipline', style: AppTextStyles.titleMedium),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('🔒', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No-Fap Reminder',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Daily motivational nudge at night',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enabled,
                      onChanged: _toggle,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
              if (_enabled) ...[
                Divider(height: 1, color: AppColors.border),
                InkWell(
                  onTap: _pickTime,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 18, color: AppColors.textMuted),
                        const SizedBox(width: 10),
                        const Text(
                          'Reminder time',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeLabel(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Info row (read-only) ──────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(label,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted)),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
