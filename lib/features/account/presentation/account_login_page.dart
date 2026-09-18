import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sharing/data/session_repository.dart';
import 'account_auth_scaffold.dart';

class AccountLoginPage extends ConsumerStatefulWidget {
  const AccountLoginPage({super.key});

  @override
  ConsumerState<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends ConsumerState<AccountLoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final username = _username.text.trim().toLowerCase();
    final password = _password.text;
    if (!RegExp(r'^[a-z0-9_]{3,40}$').hasMatch(username)) {
      setState(() => _error = '账号需为 3–40 位小写字母、数字或下划线');
      return;
    }
    if (password.length < 10 || password.length > 128) {
      setState(() => _error = '密码需为 10–128 个字符');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionRepositoryProvider).authenticate(
            username: username,
            password: password,
          );
      if (!mounted) return;
      _password.clear();
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/profile');
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = accountAuthError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AccountAuthScaffold(
        title: '欢迎回来',
        subtitle: '登录后可继续使用会员、共享账本与后续云同步能力。本地记账无需登录。',
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('account-login-username'),
                controller: _username,
                enabled: !_busy,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '登录账号',
                  hintText: '例如 lu_2026',
                  helperText: '3–40 位小写字母、数字或下划线',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('account-login-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: '密码',
                  helperText: '10–128 个字符',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? '显示密码' : '隐藏密码',
                    onPressed: _busy
                        ? null
                        : () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('account-login-error'),
                  style: const TextStyle(color: Color(0xFFB84C45), fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('account-login-submit'),
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(_busy ? '正在登录…' : '登录'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => context.pushReplacement('/account/register'),
                child: const Text('还没有账号？创建账号'),
              ),
            ],
          ),
        ),
      );
}
