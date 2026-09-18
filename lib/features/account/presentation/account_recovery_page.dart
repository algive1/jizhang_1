import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sharing/data/session_repository.dart';
import 'account_auth_scaffold.dart';

class AccountRecoveryPage extends ConsumerStatefulWidget {
  const AccountRecoveryPage({super.key});

  @override
  ConsumerState<AccountRecoveryPage> createState() => _AccountRecoveryPageState();
}

class _AccountRecoveryPageState extends ConsumerState<AccountRecoveryPage> {
  final _username = TextEditingController();
  final _key = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _key.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _username.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,40}$').hasMatch(username)) {
      setState(() => _error = '请输入正确的登录账号');
      return;
    }
    if (_key.text.trim().length < 20) {
      setState(() => _error = '恢复密钥格式不正确');
      return;
    }
    if (_password.text.length < 10 || _password.text != _confirm.text) {
      setState(() => _error = '新密码至少 10 个字符，且两次输入必须一致');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final newKey = await ref.read(sessionRepositoryProvider).recoverAccount(
            username: username,
            recoveryKey: _key.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('账号已恢复'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('旧恢复密钥已经失效，请保存新的恢复密钥：'),
              const SizedBox(height: 12),
              SelectableText(newKey),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: newKey)),
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('我已保存'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/profile');
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountAuthScaffold(
        title: '恢复账号',
        subtitle: '使用你之前保存的恢复密钥设置新密码。恢复成功后，其他设备会退出登录。',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _username,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: '登录账号'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _key,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: '恢复密钥'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密码'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirm,
              enabled: !_busy,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: '确认新密码'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFB84C45)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(_busy ? '正在恢复…' : '恢复账号'),
              ),
            ),
          ],
        ),
      );
}
