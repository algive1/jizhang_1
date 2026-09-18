import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sharing/data/session_repository.dart';
import 'account_auth_scaffold.dart';

class AccountRegisterPage extends ConsumerStatefulWidget {
  const AccountRegisterPage({super.key});

  @override
  ConsumerState<AccountRegisterPage> createState() => _AccountRegisterPageState();
}

class _AccountRegisterPageState extends ConsumerState<AccountRegisterPage> {
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _accepted = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final displayName = _displayName.text.trim();
    final username = _username.text.trim().toLowerCase();
    final password = _password.text;
    if (displayName.isEmpty || displayName.length > 24) {
      setState(() => _error = '昵称需为 1–24 个字符');
      return;
    }
    if (!RegExp(r'^[a-z0-9_]{3,40}$').hasMatch(username)) {
      setState(() => _error = '账号需为 3–40 位小写字母、数字或下划线');
      return;
    }
    if (password.length < 10 || password.length > 128) {
      setState(() => _error = '密码需为 10–128 个字符');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _error = '两次输入的密码不一致');
      return;
    }
    if (!_accepted) {
      setState(() => _error = '请先阅读并同意用户协议与隐私政策');
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
            register: true,
            displayName: displayName,
          );
      if (!mounted) return;
      _password.clear();
      _confirm.clear();
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
        title: '创建好好记账账号',
        subtitle: '账号用于会员、共享和未来云同步。创建账号不会自动上传或认领你现有的本地账务数据。',
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('account-register-display-name'),
                controller: _displayName,
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: '昵称',
                  helperText: '1–24 个字符，用于应用内展示',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('account-register-username'),
                controller: _username,
                enabled: !_busy,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newUsername],
                decoration: const InputDecoration(
                  labelText: '登录账号',
                  hintText: '例如 lu_2026',
                  helperText: '3–40 位小写字母、数字或下划线',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('account-register-password'),
                controller: _password,
                enabled: !_busy,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: '密码',
                  helperText: '至少 10 个字符',
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
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('account-register-confirm'),
                controller: _confirm,
                enabled: !_busy,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: '确认密码'),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                key: const ValueKey('account-register-agreement'),
                value: _accepted,
                enabled: !_busy,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  '我已阅读并同意用户协议与隐私政策',
                  style: TextStyle(fontSize: 13),
                ),
                onChanged: (value) => setState(() => _accepted = value ?? false),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : () => context.push('/profile/legal'),
                  child: const Text('查看服务协议'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  key: const ValueKey('account-register-error'),
                  style: const TextStyle(color: Color(0xFFB84C45), fontSize: 13),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('account-register-submit'),
                onPressed: _busy ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Text(_busy ? '正在创建…' : '创建账号并登录'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => context.pushReplacement('/account/login'),
                child: const Text('已有账号？去登录'),
              ),
            ],
          ),
        ),
      );
}
