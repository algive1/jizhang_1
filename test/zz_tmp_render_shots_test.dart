// 临时渲染脚本：把导航栏和新页面真实渲染成 PNG，用于人工查看效果。
// 加载系统中文字体 + Material 图标字体，避免渲染成方块。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/custom_apps_page.dart';

const _outDir = r'E:\putong\mumu\UI渲染';
const _cjkFont = r'C:\Windows\Fonts\Deng.ttf';
const _cjkBold = r'C:\Windows\Fonts\Dengb.ttf';
const _iconsFont =
    r'E:\jizhang_1\tools\flutter_sdk\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf';

Future<ByteData> _read(String path) async {
  final bytes = File(path).readAsBytesSync();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final data = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png));
  final dir = Directory(_outDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('$_outDir\\$name').writeAsBytesSync(data!.buffer.asUint8List());
  // ignore: avoid_print
  print('WROTE $name (${image!.width}x${image.height})');
}

class _BusyBackdrop extends StatelessWidget {
  const _BusyBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12203A), Color(0xFF2A1B3D), Color(0xFF0E2A2A)],
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
        itemCount: 24,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('第 $i 笔交易 · 收款方示例名称',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('09-21 12:${(i * 3) % 60}  ·  已入账',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text('¥${(i * 13.5 + 8).toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LightBusyBackdrop extends StatelessWidget {
  const _LightBusyBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F4F8),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
        itemCount: 34,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${i + 1}. 交易记录条目 收款方 金额 ¥${(i * 7.25).toStringAsFixed(2)} 备注文字',
            style: const TextStyle(color: Color(0xFF344054), fontSize: 14),
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() async {
    final roboto = FontLoader('Roboto')
      ..addFont(_read(_cjkFont))
      ..addFont(_read(_cjkBold));
    await roboto.load();
    final icons = FontLoader('MaterialIcons')..addFont(_read(_iconsFont));
    await icons.load();
  });

  testWidgets('渲染：液态玻璃导航栏（深色密集内容）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: RepaintBoundary(
          key: key,
          child: const Scaffold(
            extendBody: true,
            body: _BusyBackdrop(),
            bottomNavigationBar: AppBottomNavigation(location: '/'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await _shoot(tester, key, '01_导航栏_深色密集内容.png');
  });

  testWidgets('渲染：液态玻璃导航栏（浅色密集文字）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: RepaintBoundary(
          key: key,
          child: const Scaffold(
            extendBody: true,
            body: _LightBusyBackdrop(),
            bottomNavigationBar: AppBottomNavigation(location: '/insights'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await _shoot(tester, key, '02_导航栏_浅色密集文字.png');
  });

  testWidgets('渲染：药丸在首/末位', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();

    Widget app(String location) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(BuiltInThemes.liquidGlass),
          home: RepaintBoundary(
            key: key,
            child: Scaffold(
              extendBody: true,
              body: const _BusyBackdrop(),
              bottomNavigationBar: AppBottomNavigation(location: location),
            ),
          ),
        );

    await tester.pumpWidget(app('/'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await _shoot(tester, key, '03_药丸在首页.png');

    await tester.pumpWidget(app('/profile'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await _shoot(tester, key, '04_药丸在我的.png');
  });

  testWidgets('渲染：自定义应用页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: RepaintBoundary(
          key: key,
          child: const Scaffold(body: CustomAppsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await _shoot(tester, key, '05_自定义应用页.png');
  });
}
