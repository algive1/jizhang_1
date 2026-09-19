import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../voice/presentation/voice_bookkeeping_sheet.dart';

class IosShortcutBookkeepingPage extends StatefulWidget {
  const IosShortcutBookkeepingPage({super.key});

  @override
  State<IosShortcutBookkeepingPage> createState() =>
      _IosShortcutBookkeepingPageState();
}

class _IosShortcutBookkeepingPageState
    extends State<IosShortcutBookkeepingPage> {
  static const _channel = MethodChannel('jizhang/ios_shortcut');
  late final Future<String?> _pending = _takePending();

  Future<String?> _takePending() async {
    try {
      final value = await _channel.invokeMethod<String>('takePendingText');
      final text = value?.trim();
      return text == null || text.isEmpty ? null : text;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _pending,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final text = snapshot.data;
        if (text == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('快捷记账')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('没有待确认的快捷指令账单。'),
              ),
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: VoiceBookkeepingSheet(
            textOnly: true,
            initialText: text,
          ),
        );
      },
    );
  }
}
