import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/diary_entry_model.dart';
import '../controllers/diary_controller.dart';

/// Diary editor — write or dictate a single entry.
///
/// Receives the entry to edit through `Get.arguments`; a null argument means a
/// new entry.
class DiaryEntryView extends StatefulWidget {
  const DiaryEntryView({super.key});

  @override
  State<DiaryEntryView> createState() => _DiaryEntryViewState();
}

class _DiaryEntryViewState extends State<DiaryEntryView> {
  final _ctrl = Get.find<DiaryController>();
  final _speech = Get.find<SpeechService>();

  late final DiaryEntryModel? _existing;
  late final TextEditingController _title;
  late final TextEditingController _body;
  late Mood _mood;
  late DateTime _date;

  /// Body text as it stood when the current dictation started. Partial results
  /// replace everything after it, so a re-recognized phrase overwrites rather
  /// than piles up; each final result advances this marker.
  String _dictationBase = '';

  bool _hasVoice = false;
  bool _dirty = false;
  bool _saving = false;

  Worker? _speechError;

  bool get _isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    final arg = Get.arguments;
    _existing = arg is DiaryEntryModel ? arg : null;
    _title = TextEditingController(text: _existing?.title ?? '');
    _body = TextEditingController(text: _existing?.body ?? '');
    _mood = _existing?.mood ?? Mood.none;
    _date = _existing?.date ?? DateTime.now();
    _hasVoice = _existing?.hasVoice ?? false;

    _title.addListener(_markDirty);
    _body.addListener(_markDirty);

    // Single path for reporting speech trouble. The engine can fail *after*
    // listen() succeeds — a mid-session error would otherwise just stop the mic
    // with no explanation.
    _speechError = ever<String>(_speech.lastError, (message) {
      if (message.isEmpty || !mounted) return;
      AppSnackbar.error(message);
    });
  }

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  @override
  void dispose() {
    // Never leave the recognizer holding the microphone after the screen goes.
    _speech.cancel();
    _speechError?.dispose();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  // ── Dictation ─────────────────────────────────────────────────────────────

  Future<void> _toggleDictation() async {
    if (_speech.isListening.value) {
      await _speech.stop();
      return;
    }

    _dictationBase = _body.text;
    // The result is not checked here: a failure always populates
    // SpeechService.lastError, which the worker in initState reports. Handling
    // it in both places would double the snackbar.
    await _speech.start(
      onResult: (words, isFinal) {
        if (!mounted || words.isEmpty) return;
        // Keep a space between what was already written and the new speech,
        // but don't introduce leading or doubled spaces.
        final needsSpace = _dictationBase.isNotEmpty &&
            !_dictationBase.endsWith(' ') &&
            !_dictationBase.endsWith('\n');
        final next = '$_dictationBase${needsSpace ? ' ' : ''}$words';
        _body.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        _hasVoice = true;
        _dirty = true;
        // Commit the utterance so the next one appends after it.
        if (isFinal) _dictationBase = next;
      },
    );
  }

  // ── Save / discard ────────────────────────────────────────────────────────

  bool get _isEmpty =>
      _title.text.trim().isEmpty && _body.text.trim().isEmpty;

  Future<void> _save() async {
    if (_saving) return;
    await _speech.stop();
    if (_isEmpty) {
      AppSnackbar.error('Write something first.');
      return;
    }
    if (mounted) setState(() => _saving = true);
    if (_isEdit) {
      await _ctrl.updateEntry(
        id: _existing!.id,
        title: _title.text,
        body: _body.text,
        mood: _mood,
        date: _date,
        hasVoice: _hasVoice,
      );
    } else {
      await _ctrl.addEntry(
        title: _title.text,
        body: _body.text,
        mood: _mood,
        date: _date,
        hasVoice: _hasVoice,
      );
    }
    // Navigator.pop, not Get.back: the controller shows a snackbar on success,
    // and Get.back() would pop that instead of this route — leaving the editor
    // open and every further tap writing another entry.
    if (mounted) Navigator.pop(context);
  }

  /// Intercepts back with unsaved work rather than silently dropping it.
  Future<bool> _confirmLeave() async {
    if (!_dirty || _isEmpty) return true;
    final result = await Get.dialog<String>(
      AlertDialog(
        title: const Text('Save this entry?'),
        content: const Text('You have unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: 'discard'),
            child: const Text('Discard',
                style: TextStyle(color: AppColors.danger)),
          ),
          TextButton(
            onPressed: () => Get.back(result: 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'save') {
      await _save();
      return false; // _save already popped this route.
    }
    return result == 'discard';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 10),
      // An entry can be back-dated but not written for a day yet to come.
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
    if (picked != null) {
      setState(() {
        _date = picked;
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.dark,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _EditorHeader(
                isEdit: _isEdit,
                saving: _saving,
                onBack: () async {
                  final leave = await _confirmLeave();
                  if (leave && context.mounted) Navigator.pop(context);
                },
                onSave: _saving ? null : _save,
              ),
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
                      Expanded(
                        child: SingleChildScrollView(
                          padding:
                              const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _DateRow(date: _date, onTap: _pickDate),
                              const SizedBox(height: 14),
                              _MoodPicker(
                                selected: _mood,
                                onSelect: (m) => setState(() {
                                  _mood = m;
                                  _dirty = true;
                                }),
                              ),
                              const SizedBox(height: 18),

                              // Title and body share one white card so the pair
                              // reads as a single page you write on, rather than
                              // two inputs floating on the background. The card
                              // supplies the chrome, so the fields inside it are
                              // bare.
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                      Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 18, 18, 14),
                                      child: TextField(
                                        controller: _title,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.4,
                                          color: AppColors.textPrimary,
                                        ),
                                        decoration:
                                            AppTheme.bareInput.copyWith(
                                          hintText: 'Title',
                                          hintStyle: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.4,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 16, 18, 18),
                                      child: TextField(
                                        controller: _body,
                                        maxLines: null,
                                        minLines: 10,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        keyboardType:
                                            TextInputType.multiline,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.6,
                                          color: AppColors.textPrimary,
                                        ),
                                        decoration:
                                            AppTheme.bareInput.copyWith(
                                          hintText:
                                              'What happened today? Tap the mic to talk instead.',
                                          hintStyle: const TextStyle(
                                            fontSize: 15,
                                            height: 1.6,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _MicBar(
                        speech: _speech,
                        onToggle: _toggleDictation,
                      ),
                    ],
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

// ── Header ──────────────────────────────────────────────────────────────────

class _EditorHeader extends StatelessWidget {
  final bool isEdit;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback? onSave;

  const _EditorHeader({
    required this.isEdit,
    required this.saving,
    required this.onBack,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
          Expanded(
            child: Text(
              isEdit ? 'Edit' : 'Write',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
                letterSpacing: -0.3,
              ),
            ),
          ),
          GestureDetector(
            onTap: onSave,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: saving
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                saving ? 'Saving…' : 'Save',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateRow({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_rounded,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              Formatters.dateShort(date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodPicker extends StatelessWidget {
  final Mood selected;
  final ValueChanged<Mood> onSelect;

  const _MoodPicker({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in Mood.values.where((m) => m != Mood.none))
          GestureDetector(
            // Tapping the active mood clears it.
            onTap: () => onSelect(selected == m ? Mood.none : m),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected == m ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      selected == m ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    m.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected == m
                          ? AppColors.dark
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom bar holding the dictation control.
class _MicBar extends StatelessWidget {
  final SpeechService speech;
  final VoidCallback onToggle;

  const _MicBar({required this.speech, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final listening = speech.isListening.value;
      return Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          14 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: listening ? AppColors.danger : AppColors.dark,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  listening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: AppColors.surface,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    listening ? 'Listening…' : 'Tap to dictate',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: listening
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listening
                        ? 'Speak naturally — tap stop when you\'re done.'
                        : 'Your words are added to the entry as you speak.',
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}
