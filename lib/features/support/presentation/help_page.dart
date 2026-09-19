import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('使用手册')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _HelpTile(
              title: '如何开始记账？',
              body: '首页底部“记一笔”可以手动录入；Android 还可以在支付后通过自动记账或支付通知生成待确认记录。',
            ),
            _HelpTile(
              title: '多账本和共享账本有什么区别？',
              body: '多账本用于把个人、家庭、企业等账务分开；共享账本允许成员共同记录。共享默认账户时，账户详情会汇总相关账本流水。',
            ),
            _HelpTile(
              title: '备份和云同步有什么区别？',
              body: '本地完整备份由你主动导出，使用备份密码加密并包含现有附件；云同步属于会员能力，用于账号间同步和恢复。',
            ),
            _HelpTile(
              title: '为什么恢复后需要重启？',
              body: '应用运行时可能同时有前台、定时任务和自动记账连接占用数据库。恢复采用安全暂存，完全重启后再切换数据库，避免运行中替换造成损坏。',
            ),
            _HelpTile(
              title: '如何保护金额隐私？',
              body: '金额隐私掩码只隐藏展示层数字；本地数据库同时使用设备密钥加密。你还可以在“数据与安全”中开启应用锁。',
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/profile/feedback'),
              icon: const Icon(Icons.feedback_outlined),
              label: const Text('仍有问题，提交反馈'),
            ),
          ],
        ),
      );
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        child: ExpansionTile(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(body)],
        ),
      );
}
