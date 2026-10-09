import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/utils/entity_id.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import 'speech_recognition_service.dart';

class CloudSpeechRecognitionService implements SpeechRecognitionService {
  CloudSpeechRecognitionService(this._api, this._session);
  final SharedApi _api;
  final SessionRepository _session;
  final _recorder = AudioRecorder();
  final _events = StreamController<SpeechRecognitionEvent>.broadcast();
  Timer? _timer;
  String? _path;
  DateTime? _started;
  int _generation = 0;
  bool _stopping = false;
  int _maxDurationMs = 60000;
  @override
  Stream<SpeechRecognitionEvent> get events => _events.stream;
  @override
  Future<bool> initialize() => _recorder.hasPermission();
  void _emit(
    SpeechRecognitionStatus status, {
    String text = '',
    String? error,
  }) {
    if (!_events.isClosed)
      _events.add(
        SpeechRecognitionEvent(
          status: status,
          transcript: text,
          isFinal: status == SpeechRecognitionStatus.stopped,
          onDevice: false,
          errorMessage: error,
        ),
      );
  }

  @override
  Future<void> start() async {
    await cancel();
    final generation = _generation;
    try {
      await _session.initialize();
      if (_session.user == null) throw StateError('云端识别需要先登录');
      final config = await _api.request('/asr/config');
      if (config['enabled'] != true) throw StateError('云端识别尚未启用');
      _maxDurationMs = (config['maxSeconds'] as num).toInt() * 1000;
      if (!await initialize()) throw StateError('请允许使用麦克风');
      if (generation != _generation) return;
      final path =
          '${(await getTemporaryDirectory()).path}/asr-${newEntityId()}.m4a';
      if (generation != _generation) return;
      _path = path;
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 32000,
        ),
        path: _path!,
      );
      if (generation != _generation) {
        await _recorder.cancel();
        return;
      }
      _started = DateTime.now();
      _timer = Timer(
        Duration(
          milliseconds: (_maxDurationMs - 250).clamp(100, _maxDurationMs),
        ),
        () => unawaited(stop()),
      );
      _emit(SpeechRecognitionStatus.listening);
    } catch (e) {
      if (generation == _generation)
        _emit(SpeechRecognitionStatus.error, error: e.toString());
    }
  }

  @override
  Future<void> stop() async {
    if (_stopping || _started == null) return;
    _stopping = true;
    _timer?.cancel();
    final generation = _generation,
        duration = DateTime.now()
            .difference(_started!)
            .inMilliseconds
            .clamp(100, _maxDurationMs);
    String? path;
    try {
      path = await _recorder.stop();
      _started = null;
      if (path == null || generation != _generation) return;
      _emit(SpeechRecognitionStatus.processing);
      final audio = base64Encode(await File(path).readAsBytes());
      if (audio.length > 3 * 1024 * 1024) throw StateError('录音文件过大，请缩短录音');
      if (generation != _generation) return;
      final result = await _api.request(
        '/asr/recognize',
        method: 'POST',
        body: {
          'requestId': newEntityId(),
          'audio': audio,
          'format': 'm4a',
          'durationMs': duration,
          'consent': true,
        },
      );
      if (generation == _generation)
        _emit(SpeechRecognitionStatus.stopped, text: result['text'] as String);
    } catch (e) {
      if (generation == _generation)
        _emit(SpeechRecognitionStatus.error, error: e.toString());
    } finally {
      if (path != null && await File(path).exists()) await File(path).delete();
      _stopping = false;
    }
  }

  @override
  Future<void> cancel() async {
    _generation++;
    _timer?.cancel();
    _started = null;
    await _recorder.cancel();
    final path = _path;
    _path = null;
    if (path != null && await File(path).exists()) await File(path).delete();
  }

  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
    await _events.close();
  }
}

final cloudAsrEnabledProvider = FutureProvider<bool>((ref) async {
  try {
    return (await ref
            .watch(sharedApiProvider)
            .request('/asr/config'))['enabled'] ==
        true;
  } catch (_) {
    return false;
  }
});
final cloudSpeechRecognitionServiceProvider =
    Provider<SpeechRecognitionService>((ref) {
      final service = CloudSpeechRecognitionService(
        ref.watch(sharedApiProvider),
        ref.watch(sessionRepositoryProvider),
      );
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });
