import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/models/membership.dart';
import '../../membership/data/membership_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../domain/transaction_parser.dart';
import 'remote_ai_parsing_gateway.dart';

enum SpeechRecognitionStatus { idle, listening, stopped, unavailable, error }

class SpeechRecognitionEvent {
  const SpeechRecognitionEvent({
    required this.status,
    this.transcript = '',
    this.isFinal = false,
    this.onDevice = true,
    this.errorMessage,
  });

  final SpeechRecognitionStatus status;
  final String transcript;
  final bool isFinal;
  final bool onDevice;
  final String? errorMessage;
}

abstract interface class SpeechRecognitionService {
  Stream<SpeechRecognitionEvent> get events;
  Future<bool> initialize();
  Future<void> start();
  Future<void> stop();
  Future<void> cancel();
}

class DeviceSpeechRecognitionService implements SpeechRecognitionService {
  DeviceSpeechRecognitionService({stt.SpeechToText? speech})
    : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  final StreamController<SpeechRecognitionEvent> _events =
      StreamController.broadcast();
  bool _initialized = false;
  bool _usingOnDevice = true;
  bool _fallbackAttempted = false;
  String _transcript = '';

  @override
  Stream<SpeechRecognitionEvent> get events => _events.stream;

  @override
  Future<bool> initialize() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: _onStatus,
      onError: (error) {
        if (_usingOnDevice && !_fallbackAttempted) {
          _fallbackAttempted = true;
          unawaited(_restartWithSystemFallback());
          return;
        }
        _add(
          SpeechRecognitionEvent(
            status: SpeechRecognitionStatus.error,
            transcript: _transcript,
            onDevice: _usingOnDevice,
            errorMessage: error.errorMsg,
          ),
        );
      },
    );
    if (!_initialized) {
      _add(
        const SpeechRecognitionEvent(
          status: SpeechRecognitionStatus.unavailable,
          errorMessage: '设备未授权或不支持语音识别',
        ),
      );
    }
    return _initialized;
  }

  @override
  Future<void> start() async {
    if (!await initialize()) return;
    _fallbackAttempted = false;
    _transcript = '';
    try {
      await _listen(onDevice: true);
    } on Exception {
      _fallbackAttempted = true;
      await _listen(onDevice: false);
    }
  }

  Future<void> _listen({required bool onDevice}) async {
    _usingOnDevice = onDevice;
    final localeId = await _chineseLocaleId();
    await _speech.listen(
      onResult: (result) {
        _transcript = result.recognizedWords;
        _add(
          SpeechRecognitionEvent(
            status: result.finalResult
                ? SpeechRecognitionStatus.stopped
                : SpeechRecognitionStatus.listening,
            transcript: _transcript,
            isFinal: result.finalResult,
            onDevice: _usingOnDevice,
          ),
        );
      },
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        onDevice: onDevice,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 4),
        listenFor: const Duration(seconds: 45),
        localeId: localeId,
      ),
    );
    _add(
      SpeechRecognitionEvent(
        status: SpeechRecognitionStatus.listening,
        onDevice: _usingOnDevice,
      ),
    );
  }

  Future<String?> _chineseLocaleId() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('zh')) {
        return locale.localeId;
      }
    }
    return null;
  }

  Future<void> _restartWithSystemFallback() async {
    await _speech.cancel();
    try {
      await _listen(onDevice: false);
    } on Exception catch (error) {
      _add(
        SpeechRecognitionEvent(
          status: SpeechRecognitionStatus.error,
          transcript: _transcript,
          onDevice: false,
          errorMessage: '系统语音识别启动失败：$error',
        ),
      );
    }
  }

  void _onStatus(String status) {
    if (status == stt.SpeechToText.listeningStatus) return;
    if (status == stt.SpeechToText.doneStatus ||
        status == stt.SpeechToText.notListeningStatus) {
      _add(
        SpeechRecognitionEvent(
          status: SpeechRecognitionStatus.stopped,
          transcript: _transcript,
          isFinal: true,
          onDevice: _usingOnDevice,
        ),
      );
    }
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  Future<void> dispose() async {
    await cancel();
    await _events.close();
  }

  void _add(SpeechRecognitionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }
}

final speechRecognitionServiceProvider = Provider<SpeechRecognitionService>((
  ref,
) {
  final service = DeviceSpeechRecognitionService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final voiceTransactionParserProvider = Provider<TransactionParser>((ref) {
  final membership = ref.watch(membershipProvider).value;
  return HybridTransactionParser(
    rules: const RuleBasedTransactionParser(),
    ai: CachedRetryingAiTransactionParser(
      gateway: RemoteAiParsingGateway(
        ref.watch(sharedApiProvider),
        ref.watch(sessionRepositoryProvider),
      ),
    ),
    canUseAi: () {
      final quota = membership?.quotaFor(EntitlementKey.voiceAi);
      return (membership?.has(EntitlementKey.voiceAi) ?? false) &&
          (quota == null || quota.remaining > 0);
    },
  );
});
