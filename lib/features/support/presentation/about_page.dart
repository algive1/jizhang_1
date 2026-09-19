import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  static const _channel = MethodChannel('jizhang/app_update');
  String _version = '正在读取版本…';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await _channel.invokeMapMethod<String, dynamic>('appInfo');
      final version = info?['version']?.toString() ?? '未知';
      final build = info?['build']?.toString() ?? '—';
      if (mounted) setState(() => _version = '$version ($build)');
    } on Object {
      if (mounted) setState(() => _version = '版本信息暂不可用');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('关于好好记账')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const Icon(Icons.savings_outlined, size: 64),
            const SizedBox(height: 12),
            const Text(
              '好好记账',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(_version, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '记录、看懂并管理自己的钱。应用可以不登录使用；涉及会员、共享和云同步时才需要账号。',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('服务协议与隐私政策'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/legal'),
            ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('反馈建议'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/feedback'),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('我的工单'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile/support-tickets'),
            ),
          ],
        ),
      );
}
