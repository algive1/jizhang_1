import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../auto_bookkeeping_custom_apps.dart';

/// Lets the user hand extra apps to auto bookkeeping.
///
/// The packaged rule set cannot cover every payment surface, and the apps that
/// matter differ per user. Adding a package here widens both the rule set (the
/// package falls back to the generic template) and the accessibility service's
/// runtime whitelist, so an app arrives without waiting for an app release.
///
/// It is deliberately opt-in and explicit: the generic template demands a
/// recognisable "payment succeeded" marker, an amount and a merchant before it
/// will produce a candidate, and nothing is ever written without confirmation.
class CustomAppsPage extends StatefulWidget {
  const CustomAppsPage({super.key});

  @override
  State<CustomAppsPage> createState() => _CustomAppsPageState();
}

class _CustomAppsPageState extends State<CustomAppsPage> {
  final _manualController = TextEditingController();
  final _searchController = TextEditingController();

  List<LearnableApp> _apps = const [];
  Set<String> _custom = const {};
  bool _loading = true;
  bool _busy = false;
  String _query = '';
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _manualController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final custom = (await AutoBookkeepingCustomApps.list()).toSet();
    final apps = await AutoBookkeepingCustomApps.searchInstalled();
    if (!mounted) return;
    setState(() {
      _custom = custom;
      _apps = apps;
      _loading = false;
    });
  }

  Future<void> _toggle(LearnableApp app) async {
    if (_busy) return;
    setState(() => _busy = true);
    if (app.added) {
      await AutoBookkeepingCustomApps.remove(app.packageName);
    } else {
      final ok = await AutoBookkeepingCustomApps.add(app.packageName);
      if (!ok && mounted) {
        setState(() => _message = '无法添加 ${app.packageName}：包名格式不正确');
      }
    }
    final custom = (await AutoBookkeepingCustomApps.list()).toSet();
    if (!mounted) return;
    setState(() {
      _custom = custom;
      _apps = _apps
          .map(
            (existing) => existing.packageName == app.packageName
                ? LearnableApp(
                    packageName: existing.packageName,
                    label: existing.label,
                    added: custom.contains(existing.packageName),
                  )
                : existing,
          )
          .toList(growable: false);
      _busy = false;
    });
  }

  Future<void> _addByPackageName() async {
    final value = _manualController.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await AutoBookkeepingCustomApps.add(value);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _message = '「$value」不是有效的应用包名，或不能添加本应用';
      });
      return;
    }
    _manualController.clear();
    setState(() => _busy = false);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final customApps =
        _apps.where((app) => _custom.contains(app.packageName)).toList();
    final otherApps = _apps
        .where((app) => !_custom.contains(app.packageName))
        .where(
          (app) =>
              query.isEmpty ||
              app.label.toLowerCase().contains(query.toLowerCase()) ||
              app.packageName.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

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
                    '自定义应用',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '内置规则覆盖了主流支付与电商应用。若你在其他应用里也会看到支付结果页，'
              '可以把它加进来：识别结果仍会先进入待确认列表，不会自动入账。',
              style: TextStyle(height: 1.5, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    children: [
                      if (_message != null) ...[
                        AppCard(
                          child: Text(
                            _message!,
                            style: TextStyle(color: context.appPrimary),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                          hintText: '按应用名称或包名搜索',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionHeader(
                        title: '已添加（${customApps.length}）',
                        subtitle: customApps.isEmpty
                            ? '还没有添加自定义应用'
                            : '这些应用会使用通用识别规则',
                      ),
                      const SizedBox(height: 6),
                      if (customApps.isEmpty)
                        const AppCard(
                          child: Text(
                            '下拉或点击右上角刷新可重新读取已安装应用。',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      else
                        ...customApps.map(
                          (app) => _AppTile(
                            app: app,
                            busy: _busy,
                            onChanged: () => _toggle(app),
                          ),
                        ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: '可添加的应用（${otherApps.length}）',
                        subtitle: '只列出带桌面图标的应用；共读取到 ${_apps.length} 个',
                      ),
                      const SizedBox(height: 6),
                      ...otherApps.take(120).map(
                            (app) => _AppTile(
                              app: app,
                              busy: _busy,
                              onChanged: () => _toggle(app),
                            ),
                          ),
                      const SizedBox(height: 18),
                      _SectionHeader(
                        title: '手动输入包名',
                        subtitle: '用于没有桌面图标、或未出现在上面的应用',
                      ),
                      const SizedBox(height: 6),
                      AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualController,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: '例如 com.example.pay',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _addByPackageName(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _busy ? null : _addByPackageName,
                              child: const Text('添加'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppCard(
                        child: Text(
                          '说明：自定义应用走通用规则——页面里需要同时出现「支付成功」'
                          '一类的状态词、可识别的金额和商户名才会生成待确认记录；'
                          '解析与截图都只在本机完成。取消勾选后该应用会立即停止被监听。',
                          style: TextStyle(
                            height: 1.5,
                            color: context.appSecondaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: context.appSecondaryText)),
      ],
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.app,
    required this.busy,
    required this.onChanged,
  });

  final LearnableApp app;
  final bool busy;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: app.added,
              onChanged: busy ? null : (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}
