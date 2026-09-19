import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'operation_log.dart';

class _BufferedCrash {
  const _BufferedCrash({
    required this.kind,
    required this.message,
    required this.fatal,
  });

  final String kind;
  final String message;
  final bool fatal;
}

/// Lightweight first-party crash/error bridge.
///
/// It intentionally excludes stack traces and aggressively redacts paths,
/// tokens, emails and long number sequences before the existing diagnostics
/// pipeline persists or uploads anything.
abstract final class GlobalCrashReporter {
  static final List<_BufferedCrash> _buffer = <_BufferedCrash>[];
  static bool _installed = false;
  static FlutterExceptionHandler? _previousFlutterHandler;
  static bool Function(Object, StackTrace)? _previousPlatformHandler;

  static void install() {
    if (_installed) return;
    _installed = true;
    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      capture(
        details.exception,
        kind: 'flutter_error',
        fatal: false,
        context: details.context?.toDescription(),
      );
      final previous = _previousFlutterHandler;
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      capture(error, kind: 'platform_error', fatal: true);
      final previous = _previousPlatformHandler;
      if (previous != null) return previous(error, stack);
      // Treat the exception as handled after recording it so a background
      // Future error cannot take down the whole bookkeeping session.
      return true;
    };
  }

  static void capture(
    Object error, {
    required String kind,
    required bool fatal,
    String? context,
  }) {
    final raw = [
      error.runtimeType.toString(),
      error.toString(),
      if (context != null && context.trim().isNotEmpty) context.trim(),
    ].join(': ');
    _buffer.add(
      _BufferedCrash(
        kind: kind,
        message: _sanitize(raw),
        fatal: fatal,
      ),
    );
    if (_buffer.length > 20) _buffer.removeAt(0);
  }

  static List<_BufferedCrash> takeBuffered() {
    if (_buffer.isEmpty) return const [];
    final copy = List<_BufferedCrash>.from(_buffer);
    _buffer.clear();
    return copy;
  }

  static String _sanitize(String value) {
    var result = value
        .replaceAll(
          RegExp(r'(?:file://)?/(?:Users|var|private|data|storage)/[^\s]+'),
          '[path]',
        )
        .replaceAll(
          RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
          '[email]',
        )
        .replaceAll(
          RegExp(r'(?i)(token|password|authorization|bearer)\s*[:=]?\s*[^\s,;]+'),
          r'$1=[redacted]',
        )
        .replaceAll(RegExp(r'\b\d{8,}\b'), '[number]');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result.length <= 500 ? result : result.substring(0, 500);
  }
}

/// Bridges errors buffered before Riverpod/database startup into the existing
/// operation log and retries diagnostic uploads on foreground resume.
class CrashReporterBootstrap extends ConsumerStatefulWidget {
  const CrashReporterBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CrashReporterBootstrap> createState() =>
      _CrashReporterBootstrapState();
}

class _CrashReporterBootstrapState
    extends ConsumerState<CrashReporterBootstrap>
    with WidgetsBindingObserver {
  bool _draining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    scheduleMicrotask(_drain);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    if (_draining || !mounted) return;
    _draining = true;
    try {
      final service = ref.read(operationLogServiceProvider);
      for (final event in GlobalCrashReporter.takeBuffered()) {
        await service.record(
          kind: event.kind,
          level: 'error',
          message: event.message,
          data: {'fatal': event.fatal},
        );
      }
      await service.flush();
    } on Object {
      // Diagnostics must never become a second app failure.
    } finally {
      _draining = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
