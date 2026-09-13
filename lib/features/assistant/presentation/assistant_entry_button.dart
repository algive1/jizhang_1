import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/assistant_conversation.dart';

class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/assistant-bot-icon.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    excludeFromSemantics: true,
  );
}

class AssistantEntryButton extends ConsumerWidget {
  const AssistantEntryButton({
    super.key,
    required this.onPressed,
    this.unreadBadge,
    this.icon,
  });
  final VoidCallback onPressed;
  final bool? unreadBadge;
  final Widget? icon;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = (unreadBadge ?? ref.watch(assistantUnreadProvider)) == true;
    return IconButton(
      tooltip: unread ? '记账助手，有未读消息或待处理提醒' : '记账助手',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          icon ?? const AssistantAvatar(size: 36),
          if (unread)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFE66158),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
