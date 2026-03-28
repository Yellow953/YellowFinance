import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../modules/auth/controllers/auth_controller.dart';
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
