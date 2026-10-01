import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef VoiceCommandHandler = Future<bool> Function(String command);

class VoiceService extends ChangeNotifier {
  static const wakePhrase = 'hey assistant';

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Map<String, VoiceCommandHandler> _handlers = {};

  bool _ready = false;
  bool _enabled = true;
  bool _speakerEnabled = true;

  bool _awaitingCommand = false;
  bool _switchingToCommand = false;
  bool _commandDispatching = false;
  bool _wakeDetected = false;

  bool _disposed = false;

  String _state = 'idle';
  String _partial = '';
  String? _lastError;
  String _activeScope = 'home';

  String _pendingCommandText = '';

  Timer? _restartTimer;
  Timer? _commandFinalizeTimer;

  bool get ready => _ready;
  bool get enabled => _enabled;
  bool get speakerEnabled => _speakerEnabled;
  bool get isListening => _speech.isListening;
  String get state => _state;
  String get partial => _partial;
  String? get lastError => _lastError;
  String get activeScope => _activeScope;

  VoiceCommandHandler? onGlobalCommand;
  VoiceCommandHandler? onUnhandledCommand;
  Future<void> Function()? onWakeDetected;
  VoidCallback? onSpeechComplete;

  void registerHandler(String scope, VoiceCommandHandler handler) {
    _handlers[scope] = handler;
  }

  void unregisterHandler(String scope) {
    _handlers.remove(scope);
  }

  void setActiveScope(String scope) {
    _activeScope = scope;
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('wakePhraseEnabled') ?? true;
    _speakerEnabled = prefs.getBool('assistantSpeakerEnabled') ?? true;

    _ready = await _speech.initialize(
      onStatus: _handleStatus,
      onError: _handleError,
    );
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() {
      if (_disposed) return;
      onSpeechComplete?.call();
    });

    if (!_ready) {
      _state = 'unavailable';
      _lastError =
          'Speech recognition is unavailable or microphone permission was not granted.';
    } else if (_enabled) {
      await startWakeListening();
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wakePhraseEnabled', value);

    if (!value) {
      _restartTimer?.cancel();
      await _speech.stop();
      if (_state == 'listening') _state = 'idle';
      _partial = '';
    } else if (_ready) {
      await startWakeListening();
    }
    notifyListeners();
  }

  Future<void> setSpeakerEnabled(bool value) async {
    _speakerEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('assistantSpeakerEnabled', value);
    if (!value) await _tts.stop();
    if (_state == 'speaking') _state = 'idle';
    notifyListeners();
    _scheduleRestart();
  }

  Future<void> startWakeListening() async {
    if (!_ready ||
        !_enabled ||
        _speech.isListening ||
        _disposed ||
        _switchingToCommand ||
        _commandDispatching ||
        _state == 'speaking' ||
        _state == 'thinking') {
      return;
    }

    _restartTimer?.cancel();
    _commandFinalizeTimer?.cancel();

    _awaitingCommand = false;
    _wakeDetected = false;
    _pendingCommandText = '';
    _lastError = null;

    _state = 'listening';
    _partial = 'Say “Hey Assistant”';
    notifyListeners();

    await _speech.listen(
      listenMode: ListenMode.dictation,
      partialResults: true,
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 8),
      onResult: _onWakeResult,
    );
  }

RegExpMatch? _findWakePhrase(String text) {
  final normalized = text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final wakePattern = RegExp(
    r'\b(?:'
    r'hey\s+assistant|'
    r'hey\s+assistance|'

    // Keep the old wake phrase working as a fallback.
    r'hey\s+wealth\s+assistant|'
    r'hey\s+wealth\s+assistance|'
    r'hey\s+well\s+assistant|'
    r'he\s+went\s+assistant|'
    r'haven\s+assistant'
    r')\b',
    caseSensitive: false,
  );

  return wakePattern.firstMatch(normalized);
}

  void _onWakeResult(SpeechRecognitionResult result) {
    if (_disposed ||
        _switchingToCommand ||
        _commandDispatching ||
        _state == 'speaking' ||
        _state == 'thinking') {
      return;
    }

    final text = result.recognizedWords.trim();
    debugPrint('WAKE HEARD: "$text" final=${result.finalResult}');

    if (text.isEmpty) {
      return;
    }

    _partial = text;

    final lower = text.toLowerCase().trim();

    // ---------------------------------------------------------
    // NEWS SCREEN:
    // When the user is already on News, allow direct commands
    // such as:
    //   "open news 4"
    //   "read news 2"
    //   "show news 3"
    // without requiring "Hey Assistant".
    // ---------------------------------------------------------

    final directNewsNumberCommand = _activeScope == 'news' &&
        RegExp(
          r'^(?:open|read|show)\s+(?:news\s+)?\d{1,2}\b',
        ).hasMatch(lower);

    final directNewsNavigationCommand = _activeScope == 'news' &&
        (lower == 'next' ||
            lower == 'next news' ||
            lower == 'previous' ||
            lower == 'previous news' ||
            lower == 'back' ||
            lower == 'close news' ||
            lower == 'read this' ||
            lower.contains('read this news') ||
            lower.contains('read overview') ||
            lower.contains('open source') ||
            lower.contains('open article'));

    if (directNewsNumberCommand || directNewsNavigationCommand) {
      _awaitingCommand = true;
      _pendingCommandText = text;

      notifyListeners();

      // If Android gives a final result, submit immediately.
      if (result.finalResult) {
        unawaited(
          _finishCommand(text),
        );
      }

      // If Android does NOT send finalResult,
      // _handleStatus() will submit _pendingCommandText.
      return;
    }

    // ---------------------------------------------------------
    // NORMAL WAKE-PHRASE MODE
    // ---------------------------------------------------------

    final wakeMatch = _findWakePhrase(lower);

if (wakeMatch == null) {
  notifyListeners();
  return;
}

    if (!_wakeDetected) {
      _wakeDetected = true;
debugPrint('WAKE PHRASE DETECTED');
      final callback = onWakeDetected;
      

      if (callback != null) {
        unawaited(callback());
      }
    }

    final command = text
    .substring(
      wakeMatch.end.clamp(0, text.length),
    )
    .replaceFirst(
      RegExp(r'^[,\s]+'),
      '',
    )
    .trim();

    // Example:
    // "Hey Assistant, show my spending"
    if (command.isNotEmpty) {
      _awaitingCommand = true;
      _pendingCommandText = command;
      _partial = command;

      notifyListeners();

      if (result.finalResult) {
        unawaited(
          _finishCommand(command),
        );
      }

      return;
    }

    // User only said:
    // "Hey Assistant"
    _partial = 'Listening…';
    notifyListeners();

    if (result.finalResult) {
      unawaited(
        _listenForCommand(),
      );
    }
  }

  Future<void> listenForCommand() async {
    if (!_ready) {
      _lastError =
          'Microphone is not ready. Check microphone and speech permissions.';
      _state = 'unavailable';
      notifyListeners();
      return;
    }

    if (_disposed ||
        _switchingToCommand ||
        _commandDispatching ||
        _state == 'speaking' ||
        _state == 'thinking') {
      return;
    }

    _restartTimer?.cancel();
    _commandFinalizeTimer?.cancel();

    await _listenForCommand();
  }

  Future<void> _listenForCommand() async {
    if (_disposed ||
        !_ready ||
        _switchingToCommand ||
        _commandDispatching ||
        _state == 'speaking' ||
        _state == 'thinking') {
      return;
    }

    _switchingToCommand = true;

    _restartTimer?.cancel();
    _commandFinalizeTimer?.cancel();

    try {
      // Finish the wake-word recognition session first.
      if (_speech.isListening) {
        await _speech.stop();
      }

      // Android needs a short delay before starting another
      // recognition session.
      await Future<void>.delayed(
        const Duration(milliseconds: 450),
      );

      if (_disposed) return;

      _awaitingCommand = true;
      _pendingCommandText = '';
      _lastError = null;

      _state = 'listening';
      _partial = 'Listening…';

      notifyListeners();

      await _speech.listen(
        listenMode: ListenMode.dictation,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        onResult: _onCommandResult,
      );
    } catch (error) {
      debugPrint('Command listening error: $error');

      if (_disposed) return;

      _awaitingCommand = false;
      _pendingCommandText = '';
      _state = 'idle';
      _lastError = 'Could not start voice recognition.';

      notifyListeners();
      _scheduleRestart();
    } finally {
      _switchingToCommand = false;
    }
  }

  void _onCommandResult(SpeechRecognitionResult result) {
    if (_disposed ||
        _commandDispatching ||
        _state == 'thinking' ||
        _state == 'speaking') {
      return;
    }

    final command = result.recognizedWords.trim();

    if (command.isEmpty) {
      return;
    }

    // Save EVERY partial recognition result.
    //
    // This fixes the problem where Android visibly recognizes:
    // "show my spending"
    // but never sends a reliable finalResult callback.
    _pendingCommandText = command;
    _partial = command;
    _awaitingCommand = true;

    notifyListeners();

    // Best case: Android sends a proper final result.
    if (result.finalResult) {
      unawaited(_finishCommand(command));
    }
  }

  Future<void> _finishCommand(String command) async {
    final finalCommand = command.trim();

    if (_disposed || finalCommand.isEmpty || _commandDispatching) {
      return;
    }

    _commandDispatching = true;

    _commandFinalizeTimer?.cancel();
    _restartTimer?.cancel();

    _awaitingCommand = false;
    _pendingCommandText = '';

    // IMPORTANT:
    // Move to "thinking" BEFORE stopping speech recognition.
    // That prevents Android's stop/done callback from restarting
    // wake listening while we're submitting the command.
    _state = 'thinking';
    _partial = finalCommand;
    _lastError = null;

    notifyListeners();

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }

      debugPrint(
        'VOICE COMMAND SUBMIT: "$finalCommand"',
      );

      await _dispatch(finalCommand);
    } catch (error) {
      debugPrint(
        'Voice command dispatch error: $error',
      );

      if (!_disposed) {
        _state = 'idle';
        _lastError = 'Could not process voice command.';

        notifyListeners();
        _scheduleRestart();
      }
    } finally {
      _commandDispatching = false;

      if (_disposed) {
        return;
      }

      // The command handler may have spoken a response.
      // While it was speaking, restart requests were intentionally
      // blocked because _commandDispatching was true.
      //
      // Now that the command is completely finished, restart
      // wake/direct-command listening.
      if (_state == 'idle') {
        _scheduleRestart();
      }
    }
  }

  Future<void> _dispatch(String command) async {
    _awaitingCommand = false;
    _state = 'thinking';
    _partial = command;
    notifyListeners();

    var handled = false;
    final global = onGlobalCommand;
    if (global != null) handled = await global(command);

    if (!handled) {
      final handler = _handlers[_activeScope];
      if (handler != null) handled = await handler(command);
    }

    if (!handled && onUnhandledCommand != null) {
      handled = await onUnhandledCommand!(command);
    }

    if (_disposed) return;
    if (!handled) {
      _state = 'idle';
      _partial = 'Command not recognized';
      notifyListeners();
      _scheduleRestart();
      return;
    }

    // A handled command may not speak (for example navigation or when the
    // speaker toggle is off). Do not leave the voice UI stuck on “thinking”.
    if (_state == 'thinking') {
      _state = 'idle';
      notifyListeners();
      _scheduleRestart();
    }
  }

  Future<void> speak(
    String text, {
    void Function(
      String text,
      int start,
      int end,
      String word,
    )? onProgress,
  }) async {
    if (_disposed || text.trim().isEmpty || !_speakerEnabled) {
      return;
    }

    _restartTimer?.cancel();
    _commandFinalizeTimer?.cancel();

    // Enter speaking state before stopping recognition.
    // This prevents recognition callbacks from restarting
    // the microphone while TTS is playing.
    _state = 'speaking';
    _awaitingCommand = false;
    _lastError = null;

    notifyListeners();

    try {
      // Recognition and TTS must not compete for audio.
      if (_speech.isListening) {
        await _speech.cancel();

        await Future<void>.delayed(
          const Duration(milliseconds: 350),
        );
      }

      await _tts.stop();

      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.48);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      await _tts.awaitSpeakCompletion(true);

      _tts.setProgressHandler((
        String spokenText,
        int start,
        int end,
        String word,
      ) {
        onProgress?.call(
          spokenText,
          start,
          end,
          word,
        );
      });

      final cleanText = text
          .replaceAll(RegExp(r'\\\*\\\*'), '')
          .replaceAll(RegExp(r'[#\*\_>\`]'), ' ')
          .replaceAll(
            RegExp(
              r'^\s\*[-•]\s\*',
              multiLine: true,
            ),
            '',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (cleanText.isEmpty) {
        return;
      }

      await _tts.speak(cleanText);
    } catch (error) {
      debugPrint(
        'TTS ERROR: $error',
      );
    } finally {
      if (_disposed) return;

      _state = 'idle';
      notifyListeners();

      await Future<void>.delayed(
        const Duration(milliseconds: 700),
      );

      // Do not restart while a voice command itself
      // is still being dispatched.
      if (!_disposed && !_commandDispatching) {
        _scheduleRestart();
      }
    }
  }

  Future<void> stopSpeaking() async {
    if (_disposed) {
      return;
    }

    await _tts.stop();

    if (_disposed) {
      return;
    }

    if (_state == 'speaking') {
      _state = 'idle';
    }

    notifyListeners();

    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    if (!_disposed && !_commandDispatching && _state == 'idle') {
      _scheduleRestart();
    }
  }

  Future<void> stopForBackground() async {
    _restartTimer?.cancel();
    await _speech.stop();
    await _tts.stop();
    _state = 'idle';
    notifyListeners();
  }

  void _handleError(
    SpeechRecognitionError error,
  ) {
    if (_disposed) return;

    // Ignore errors created because we intentionally stopped
    // recognition while changing modes or speaking.
    if (_switchingToCommand ||
        _commandDispatching ||
        _state == 'speaking' ||
        _state == 'thinking') {
      return;
    }

    final message = error.errorMsg;
    final pending = _pendingCommandText.trim();

    debugPrint(
      'VOICE ERROR: $message '
      'pending="$pending"',
    );

    // Android sometimes reports a timeout/no-match even after
    // successfully recognizing some words.
    //
    // If we already have text, use it instead of throwing it away.
    if ((message == 'error_speech_timeout' || message == 'error_no_match') &&
        _awaitingCommand &&
        pending.isNotEmpty) {
      unawaited(
        _finishCommand(pending),
      );

      return;
    }

    // These are normal recoverable events when there is no command.
    if (message == 'error_speech_timeout' || message == 'error_no_match') {
      _lastError = null;
      _awaitingCommand = false;
      _pendingCommandText = '';

      _state = 'idle';

      if (_enabled) {
        _partial = 'Say “Hey Assistant”';
      } else {
        _partial = '';
      }

      notifyListeners();
      _scheduleRestart();

      return;
    }

    // Genuine recognition error.
    _awaitingCommand = false;
    _pendingCommandText = '';

    _lastError = message;
    _state = 'idle';

    notifyListeners();
    _scheduleRestart();
  }

  void _handleStatus(String status) {
    if (_disposed) return;

    // Ignore status callbacks caused by intentional transitions.
    if (_switchingToCommand ||
        _commandDispatching ||
        _state == 'speaking' ||
        _state == 'thinking') {
      return;
    }

    if (status != 'done' && status != 'notListening') {
      return;
    }

    // Android can send "done" before giving us finalResult.
    //
    // If we already recognized useful words, wait briefly.
    // If finalResult never arrives, submit the best text we have.
    if (_awaitingCommand) {
      final pending = _pendingCommandText.trim();

      if (pending.isNotEmpty) {
        _commandFinalizeTimer?.cancel();

        _commandFinalizeTimer = Timer(
          const Duration(milliseconds: 350),
          () {
            if (_disposed || !_awaitingCommand || _commandDispatching) {
              return;
            }

            final command = _pendingCommandText.trim();

            if (command.isNotEmpty) {
              debugPrint(
                'VOICE FALLBACK SUBMIT: "$command"',
              );

              unawaited(
                _finishCommand(command),
              );
            }
          },
        );

        return;
      }

      _awaitingCommand = false;
    }

    if (_state == 'listening') {
      _state = 'idle';
      notifyListeners();
    }

    _scheduleRestart();
  }

  void _scheduleRestart() {
    if (_disposed ||
        !_enabled ||
        !_ready ||
        _switchingToCommand ||
        _commandDispatching ||
        _awaitingCommand ||
        _state != 'idle') {
      return;
    }

    _restartTimer?.cancel();

    _restartTimer = Timer(
      const Duration(milliseconds: 700),
      () {
        if (_disposed ||
            !_enabled ||
            !_ready ||
            _speech.isListening ||
            _switchingToCommand ||
            _commandDispatching ||
            _awaitingCommand ||
            _state != 'idle') {
          return;
        }

        startWakeListening();
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _restartTimer?.cancel();
    _commandFinalizeTimer?.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
