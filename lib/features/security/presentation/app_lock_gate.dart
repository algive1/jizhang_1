import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_lock_service.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _checking = true;
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initialCheck());
    });
  }

  Future<void> _initialCheck() async {
    final enabled = await ref.read(appLockServiceProvider).isEnabled();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _locked = enabled;
    });
    if (enabled) await _unlock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(_lockIfEnabled());
    } else if (state == AppLifecycleState.resumed && _locked) {
      unawaited(_unlock());
    }
  }

  Future<void> _lockIfEnabled() async {
    final enabled = await ref.read(appLockServiceProvider).isEnabled();
    if (mounted && enabled) setState(() => _locked = true);
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    final service = ref.read(appLockServiceProvider);
    if (!await service.isEnabled()) {
      if (mounted) setState(() => _locked = false);
      return;
    }
    if (mounted) setState(() => _authenticating = true);
    final unlocked = await service.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = !unlocked;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checking && !_locked) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: ColoredBox(
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
                      const Text(
                        '使用指纹、面容或设备密码验证后继续。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      if (_checking || _authenticating)
                        const CircularProgressIndicator()
                      else
                        FilledButton.icon(
                          onPressed: _unlock,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('解锁'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
