import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/startup_poster.dart';
import '../application/app_lock_service.dart';

enum _AppLockPhase {
  checking,
  unlocked,
  authenticating,
  locked,
  error,
}

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  _AppLockPhase _phase = _AppLockPhase.checking;
  String? _errorMessage;
  int _lifecycleGeneration = 0;
  Future<void>? _authenticationTask;

  bool get _isForeground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initialCheck());
    });
  }

  Future<void> _initialCheck() async {
    final generation = _lifecycleGeneration;
    try {
      final enabled = await ref.read(appLockServiceProvider).isEnabled();
      if (!mounted || generation != _lifecycleGeneration) return;

      if (!enabled) {
        _setPhase(_AppLockPhase.unlocked);
        return;
      }

      if (_isForeground) {
        await _authenticate();
      } else {
        _setPhase(_AppLockPhase.locked);
      }
    } on Object {
      if (!mounted || generation != _lifecycleGeneration) return;
      _setError(
        '无法读取应用锁设置。为避免暴露账务内容，已暂时阻止进入应用。',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      final generation = ++_lifecycleGeneration;
      if (_phase == _AppLockPhase.authenticating) return;
      unawaited(_lockForBackground(generation));
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final generation = ++_lifecycleGeneration;
      if (_phase == _AppLockPhase.authenticating) return;
      unawaited(_handleResume(generation));
    }
  }

  Future<void> _lockForBackground(int generation) async {
    try {
      final enabled = await ref.read(appLockServiceProvider).isEnabled();
      if (!mounted ||
          generation != _lifecycleGeneration ||
          _isForeground ||
          _phase == _AppLockPhase.authenticating) {
        return;
      }

      _setPhase(
        enabled ? _AppLockPhase.locked : _AppLockPhase.unlocked,
      );
    } on Object {
      if (!mounted ||
          generation != _lifecycleGeneration ||
          _isForeground) {
        return;
      }
      _setError(
        '无法读取应用锁设置。为避免暴露账务内容，已暂时阻止进入应用。',
      );
    }
  }

  Future<void> _handleResume(int generation) async {
    try {
      final enabled = await ref.read(appLockServiceProvider).isEnabled();
      if (!mounted ||
          generation != _lifecycleGeneration ||
          !_isForeground ||
          _phase == _AppLockPhase.authenticating) {
        return;
      }

      if (!enabled) {
        _setPhase(_AppLockPhase.unlocked);
        return;
      }

      await _authenticate();
    } on Object {
      if (!mounted ||
          generation != _lifecycleGeneration ||
          !_isForeground) {
        return;
      }
      _setError(
        '无法读取应用锁设置。为避免暴露账务内容，已暂时阻止进入应用。',
      );
    }
  }

  Future<void> _authenticate() {
    final existing = _authenticationTask;
    if (existing != null) return existing;

    final task = _runAuthentication();
    _authenticationTask = task;
    return task.whenComplete(() {
      if (identical(_authenticationTask, task)) {
        _authenticationTask = null;
      }
    });
  }

  Future<void> _runAuthentication() async {
    if (!mounted) return;
    if (!_isForeground) {
      _setPhase(_AppLockPhase.locked);
      return;
    }
    _setPhase(_AppLockPhase.authenticating);

    try {
      final unlocked = await ref.read(appLockServiceProvider).authenticate();
      if (!mounted) return;

      if (unlocked && _isForeground) {
        _setPhase(_AppLockPhase.unlocked);
      } else {
        _setPhase(_AppLockPhase.locked);
      }
    } on Object {
      if (!mounted) return;
      _setError(
        '设备身份验证暂时不可用。请稍后重试，账务内容仍保持锁定。',
      );
    }
  }

  void _retryInitialCheck() {
    ++_lifecycleGeneration;
    _setPhase(_AppLockPhase.checking);
    unawaited(_initialCheck());
  }

  void _retryUnlock() {
    final generation = ++_lifecycleGeneration;
    unawaited(_handleResume(generation));
  }

  void _setPhase(_AppLockPhase phase) {
    if (!mounted) return;
    setState(() {
      _phase = phase;
      _errorMessage = null;
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _phase = _AppLockPhase.error;
      _errorMessage = message;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _AppLockPhase.checking:
        // Reading secure storage is not the same thing as being locked.
        // Keep the existing startup artwork visible instead of flashing a
        // misleading lock screen while the preference is still unknown.
        return const StartupPoster();
      case _AppLockPhase.unlocked:
        return widget.child;
      case _AppLockPhase.authenticating:
      case _AppLockPhase.locked:
        return _LockScreen(
          authenticating: _phase == _AppLockPhase.authenticating,
          onUnlock: _retryUnlock,
        );
      case _AppLockPhase.error:
        return _LockErrorScreen(
          message: _errorMessage ??
              '无法读取应用锁设置。为避免暴露账务内容，已暂时阻止进入应用。',
          onRetry: _retryInitialCheck,
        );
    }
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.authenticating,
    required this.onUnlock,
  });

  final bool authenticating;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F6EC),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 56,
                  color: Color(0xFF536A45),
                ),
                const SizedBox(height: 18),
                const Text(
                  '好好记账已锁定',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  authenticating
                      ? '正在验证设备身份…'
                      : '使用指纹、面容或设备密码验证后继续。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                if (authenticating)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: onUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('解锁'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockErrorScreen extends StatelessWidget {
  const _LockErrorScreen({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F6EC),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 54,
                    color: Color(0xFF536A45),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '应用锁设置读取失败',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
