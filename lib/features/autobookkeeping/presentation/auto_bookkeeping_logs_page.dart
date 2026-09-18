import '../../../core/widgets/app_action_sheet.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/diagnostics/operation_log.dart';
import '../../sharing/data/session_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auto_bookkeeping_logs.dart';

class AutoBookkeepingLogsPage extends ConsumerStatefulWidget {
  const AutoBookkeepingLogsPage({super.key});

  @override
  ConsumerState<AutoBookkeepingLogsPage> createState() =>
      _AutoBookkeepingLogsPageState();
}

class _AutoBookkeepingLogsPageState
    extends ConsumerState<AutoBookkeepingLogsPage> {
  final _bridge = const AutoBookkeepingLogsBridge();
  late Future<List<AutoBookkeepingLogEntry>> _logs;
  late Future<List<Map<String, Object?>>> _diagnostics;

  @override
  void initState() {
    super.initState();
    _logs = _bridge.getLogs();
    _diagnostics = ref.read(operationLogServiceProvider).pendingEvents();
  }

  Future<void> _reload() async {
    setState(() {
      _logs = _bridge.getLogs();
      _diagnostics = ref.read(operationLogServiceProvider).pendingEvents();
    });
    await Future.wait([_logs, _diagnostics]);
  }

  Future<void> _upload() async {
    await ref.read(sessionRepositoryProvider).initialize();
    await ref.read(operationLogServiceProvider).flush();
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('诊断日志已尝试上传；未登录或网络不可用时会保留在本机。')),
      );
    }
  }

  Future<void> _clear() async {
    await _bridge.clear();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: context.pop,
                  icon: const Icon(Icons.arrow_back),
                ),
                const Expanded(
                  child: Text(
                    '自动记账运行日志',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
                IconButton(
                  onPressed: _upload,
                  tooltip: '上传诊断日志',
                  icon: const Icon(Icons.cloud_upload_outlined),
                ),
                AppActionMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'clear') _clear();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'clear', child: Text('清空日志')),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '仅保留最近 120 条脱敏运行记录，用于判断支付事件、页面识别、去重和悬浮窗状态。',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                FutureBuilder<List<AutoBookkeepingLogEntry>>(
                  future: _logs,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final logs =
                        snapshot.data ?? const <AutoBookkeepingLogEntry>[];
                    if (logs.isEmpty) return const Text('暂无 Android 自动记账运行日志');
                    return Column(
                      children: [
                        for (final item in logs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              child: Text(
                                '${_formatTime(item.timestamp)}  ${item.stage}\n${item.detail}',
                                style: const TextStyle(
                                  height: 1.45,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, Object?>>>(
                  future: _diagnostics,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox.shrink();
                    }
                    final events =
                        snapshot.data ?? const <Map<String, Object?>>[];
                    return AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '应用诊断日志',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '本机待上传 ${events.length} 条；包含操作时间、结果和错误类型，不包含通知原文及账户敏感信息。',
                          ),
                          if (events.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final event in events.take(20))
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${event['occurred_at']}  ${event['level']}  ${event['kind']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }
}
