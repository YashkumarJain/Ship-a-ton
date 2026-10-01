import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

typedef VoiceCommandHandler = Future<bool> Function(String command);

class VoiceService extends ChangeNotifier {
  static const wakePhrase = 'hey wealth assistant';

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Map<String, VoiceCommandHandler> _handlers = {};

  bool _ready = false;
  bool _enabled = true;
  bool _awaitingCommand = false;
  bool _disposed = false;
  String _state = 'idle';
  String _partial = '';
  String _activeScope = 'home';
  Timer? _restartTimer;

  bool get ready => _ready;
  bool get enabled => _enabled;
  String get state => _state;
  String get partial => _partial;
  String get activeScope => _activeScope;

  VoiceCommandHandler? onGlobalCommand;
  VoiceCommandHandler? onUnhandledCommand;
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
    _ready = await _speech.initialize(
      onStatus: _handleStatus,
      onError: (_) => _scheduleRestart(),
    );
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (_disposed) return;
      _state = 'idle';
      notifyListeners();
      onSpeechComplete?.call();
      _scheduleRestart();
    });
    if (_ready && _enabled) await startWakeListening();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) {
      _restartTimer?.cancel();
      await _speech.stop();
      await _tts.stop();
      _state = 'idle';
      _partial = '';
    } else if (_ready) {
      await startWakeListening();
    }
    notifyListeners();
  }

  Future<void> startWakeListening() async {
    if (!_ready || !_enabled || _speech.isListening || _disposed || _state == 'speaking') return;
    _awaitingCommand = false;
    _state = 'listening';
    _partial = 'Say “Hey Wealth Assistant”';
    notifyListeners();
    await _speech.listen(
      listenMode: ListenMode.dictation,
      partialResults: true,
      onResult: _onWakeResult,
    );
  }

  void _onWakeResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    _partial = text;
    final lower = text.toLowerCase();
    final index = lower.indexOf(wakePhrase);
    if (index >= 0) {
      final command = text.substring(index + wakePhrase.length).trim();
      _speech.stop();
      if (command.isNotEmpty) {
        _dispatch(command);
      } else {
        _listenForCommand();
      }
    }
    notifyListeners();
  }

  Future<void> _listenForCommand() async {
    if (_disposed || !_enabled) return;
    _awaitingCommand = true;
    _state = 'listening';
    _partial = 'I’m listening…';
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 220));
    await _speech.listen(
      listenMode: ListenMode.confirmation,
      partialResults: true,
      onResult: (result) {
        _partial = result.recognizedWords;
        notifyListeners();
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _speech.stop();
          _dispatch(result.recognizedWords.trim());
        }
      },
    );
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

    if (!handled && !_disposed) {
      _state = 'idle';
      _partial = 'Command not recognized';
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
  if (_disposed || text.trim().isEmpty) return;

  await _speech.stop();

  _state = 'speaking';
  notifyListeners();

  await _tts.stop();

  _tts.setProgressHandler(
    (
      String text,
      int start,
      int end,
      String word,
    ) {
      onProgress?.call(text, start, end, word);
    },
  );

  final cleanText =
      text.replaceAll(RegExp(r'[#*_>]'), ' ');

  await _tts.awaitSpeakCompletion(true);
  await _tts.speak(cleanText);
  
}

  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (_disposed) return;
    _state = 'idle';
    notifyListeners();
    _scheduleRestart();
  }

  Future<void> stopForBackground() async {
    _restartTimer?.cancel();
    await _speech.stop();
    await _tts.stop();
    _state = 'idle';
    notifyListeners();
  }

  void _handleStatus(String status) {
    if (_disposed || !_enabled || _awaitingCommand || _state == 'speaking') return;
    if (status == 'done' || status == 'notListening') _scheduleRestart();
  }

  void _scheduleRestart() {
    if (_disposed || !_enabled || _state == 'speaking') return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 700), startWakeListening);
  }

  @override
  void dispose() {
    _disposed = true;
    _restartTimer?.cancel();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
