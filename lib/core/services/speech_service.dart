import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps `speech_to_text` behind a small reactive surface.
///
/// The plugin's `initialize()` both sets up the engine and triggers the
/// microphone / speech-recognition permission prompt, so it is called lazily on
/// the first dictation rather than at app start — no permission dialog for a
/// user who never opens the diary.
class SpeechService extends GetxService {
  final _speech = SpeechToText();

  /// Whether a dictation session is running.
  final RxBool isListening = false.obs;

  /// Human-readable reason the last attempt failed, or empty.
  final RxString lastError = ''.obs;

  bool _initialized = false;

  /// Prepares the engine, prompting for permission the first time.
  /// Returns false when speech recognition is unavailable or denied.
  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onStatus: (status) {
          // 'done' and 'notListening' both mean the engine stopped — often on
          // its own after a pause, so the UI can't rely on stop() alone.
          if (status == 'done' || status == 'notListening') {
            isListening.value = false;
          }
        },
        onError: (error) {
          isListening.value = false;
          if (kDebugMode) debugPrint('SpeechService: ${error.errorMsg}');
          final message = _messageFor(error.errorMsg);
          // Null means benign (a cancel we asked for) — stay quiet.
          if (message != null) lastError.value = message;
        },
      );
    } catch (e) {
      if (kDebugMode) debugPrint('SpeechService: init failed — $e');
      _initialized = false;
    }
    if (!_initialized) {
      lastError.value = _isSimulator
          ? 'Voice input doesn\'t work on the iOS Simulator — try a real device.'
          : 'Voice input isn\'t available. Check microphone permission.';
    }
    return _initialized;
  }

  /// Starts dictating. [onResult] fires repeatedly with the text recognized so
  /// far; [isFinal] marks the end of an utterance.
  ///
  /// Returns false if the session could not start.
  Future<bool> start({
    required void Function(String words, bool isFinal) onResult,
  }) async {
    if (isListening.value) return true;
    lastError.value = '';
    if (!await _ensureInitialized()) return false;

    try {
      await _speech.listen(
        onResult: (result) =>
            onResult(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
          // Dictation mode expects sentences rather than short commands.
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
          // iOS only, but free where supported — saves manual punctuation.
          autoPunctuation: true,
          // Generous windows: a diary entry involves thinking mid-sentence.
          listenFor: const Duration(minutes: 5),
          pauseFor: const Duration(seconds: 6),
        ),
      );
      isListening.value = true;
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('SpeechService: listen failed — $e');
      lastError.value = 'Could not start voice input.';
      isListening.value = false;
      return false;
    }
  }

  /// Ends the session, keeping whatever was recognized.
  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _speech.stop();
    } catch (_) {
      // Already stopped — the flag below is what the UI reads.
    }
    isListening.value = false;
  }

  /// Ends the session and discards the in-flight result.
  Future<void> cancel() async {
    if (!_initialized) return;
    try {
      await _speech.cancel();
    } catch (_) {
      // Already stopped.
    }
    isListening.value = false;
  }

  /// Turns a plugin error code into a user-facing message, or null when the
  /// failure is benign and should pass silently.
  ///
  /// iOS appends the underlying NSError code to unmapped errors — literally
  /// `"error_unknown (300)"` — so codes are matched on their prefix. Comparing
  /// the whole string silently misses every one of them.
  String? _messageFor(String raw) {
    final code = raw.split(' ').first;

    switch (code) {
      // We asked for this one — stopping or leaving the screen cancels the
      // request, and reporting that back as an error is pure noise.
      case 'error_request_cancelled':
        return null;

      case 'error_permission':
      case 'error_speech_recognizer_request_not_authorized':
        return 'Microphone permission is needed for voice input.';

      case 'error_speech_timeout':
      case 'error_no_match':
        return 'Didn\'t catch that — try again.';

      case 'error_network':
      case 'error_network_timeout':
      case 'error_speech_recognizer_connection_invalidated':
      case 'error_speech_recognizer_connection_interrupted':
        return 'Voice input needs a connection right now.';

      case 'error_busy':
      case 'error_speech_recognizer_already_active':
        return 'The microphone is busy. Try again in a moment.';

      case 'error_retry':
        return 'Voice input hiccuped — try again.';

      case 'error_assets_not_installed':
        return 'This language isn\'t downloaded for dictation yet.';

      case 'error_speech_recognizer_disabled':
        return 'Speech recognition is turned off in system settings.';

      default:
        // Covers error_unknown (…) and error_listen_failed. The iOS Simulator
        // has no speech recognition service and fails here every time with
        // kAFAssistantErrorDomain 300 — nothing in the app can fix that, so say
        // so rather than implying a transient glitch worth retrying.
        return _isSimulator
            ? 'Voice input doesn\'t work on the iOS Simulator — try a real device.'
            : 'Voice input isn\'t available right now.';
    }
  }

  /// Best-effort simulator detection: these variables are present in the
  /// process environment only on the iOS Simulator.
  bool get _isSimulator =>
      !kIsWeb &&
      Platform.isIOS &&
      (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
          Platform.environment.containsKey('SIMULATOR_UDID'));

  @override
  void onClose() {
    // Leaving a live recognizer running would hold the microphone open.
    if (_initialized) _speech.cancel();
    super.onClose();
  }
}
