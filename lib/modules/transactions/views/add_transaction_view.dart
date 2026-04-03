import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../controllers/transaction_controller.dart';

/// Add transaction screen.
class AddTransactionView extends StatefulWidget {
  const AddTransactionView({super.key});

  @override
  State<AddTransactionView> createState() => _AddTransactionViewState();
}

class _AddTransactionViewState extends State<AddTransactionView> {
  final _controller = Get.find<TransactionController>();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final type = Get.arguments as String?;
    if (type != null) _controller.setType(type);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Dark header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: AppColors.dark, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Transaction',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.surface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Record income or expense',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Obx(() => _TypeToggle(
                        selected: _controller.selectedType.value,
                        onChanged: _controller.setType,
                      )),
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
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1 — Date
                        const _SectionLabel('Date'),
                        const SizedBox(height: 10),
                        StatefulBuilder(
                          builder: (_, setDate) => _DatePicker(
                            date: _selectedDate,
                            onChanged: (d) =>
                                setDate(() => _selectedDate = d),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2 — Category
                        const _SectionLabel('Category'),
                        const SizedBox(height: 10),
                        Obx(() => _CategoryGrid(
                              type: _controller.selectedType.value,
                              selected: _controller.selectedCategory.value,
                              onChanged: (c) =>
                                  _controller.selectedCategory.value = c,
                            )),
                        const SizedBox(height: 24),

                        // 3 — Amount
                        const _SectionLabel('Amount'),
                        const SizedBox(height: 10),
                        AppTextField(
                          label: 'Amount',
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: Validators.amount,
                          prefixText: '\$ ',
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // 5 — Description (optional)
                        const _SectionLabel('Description (optional)'),
                        const SizedBox(height: 10),
                        AppTextField(
                          label: 'Add a note…',
                          controller: _descCtrl,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          prefixIcon: const Icon(
                              Icons.notes_rounded,
                              color: AppColors.textMuted,
                              size: 20),
                        ),
                        const SizedBox(height: 36),

                        Obx(() => AppButton(
                              label: 'Save Transaction',
                              isLoading: _controller.isSaving.value,
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _controller.addTransaction(
                                    amountText: _amountCtrl.text,
                                    description: _descCtrl.text.trim(),
                                    date: _selectedDate,
                                  );
                                }
                              },
                            )),
                      ],
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

// ── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
      ),
    );
  }
}

// ── Type toggle ────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Expense',
            isSelected: selected == AppConstants.txnExpense,
            onTap: () => onChanged(AppConstants.txnExpense),
          ),
          _Tab(
            label: 'Income',
            isSelected: selected == AppConstants.txnIncome,
            onTap: () => onChanged(AppConstants.txnIncome),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: isSelected ? AppColors.dark : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Category row ───────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final String type;
  final String selected;
  final void Function(String) onChanged;

  const _CategoryGrid({
    required this.type,
    required this.selected,
    required this.onChanged,
  });

  static const _expenseItems = [
    (label: 'Food', icon: Icons.restaurant_rounded),
    (label: 'Transport', icon: Icons.directions_car_rounded),
    (label: 'Misc', icon: Icons.grid_view_rounded),
    (label: 'Investment', icon: Icons.trending_up_rounded),
    (label: 'Business', icon: Icons.business_center_rounded),
    (label: 'Other', icon: Icons.more_horiz_rounded),
  ];

  static const _incomeItems = [
    (label: 'Salary', icon: Icons.account_balance_wallet_rounded),
    (label: 'Project', icon: Icons.work_outline_rounded),
    (label: 'Business', icon: Icons.business_center_rounded),
    (label: 'Other', icon: Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final items = type == AppConstants.txnIncome ? _incomeItems : _expenseItems;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: items.map((item) {
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

// ── Date picker ────────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  final DateTime date;
  final void Function(DateTime) onChanged;

  const _DatePicker({required this.date, required this.onChanged});

  String _format(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
                onPrimary: AppColors.dark,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text(_format(date), style: AppTextStyles.bodyLarge),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
