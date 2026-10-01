import 'package:flutter/material.dart';
import 'package:chatbotapp/models/message.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/utilities/app_motion.dart';
import 'package:chatbotapp/widgets/assistant_message_widget.dart';
import 'package:chatbotapp/widgets/my_message_widget.dart';

class ChatMessages extends StatelessWidget {
  const ChatMessages({
    super.key,
    required this.scrollController,
    required this.chatProvider,
    this.bottomPadding = 24,
  });

  final ScrollController scrollController;
  final ChatProvider chatProvider;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
      itemCount: chatProvider.inChatMessages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final message = chatProvider.inChatMessages[index];
        final isUser = message.role == Role.user;
        return _AnimatedMessage(
          key: ValueKey('${message.role.name}-${message.messageId}'),
          child: isUser
              ? MyMessageWidget(message: message)
              : AssistantMessageWidget(message: message),
        );
      },
    );
  }
}

/// Fades and slides a message in once, the first time it is built.
class _AnimatedMessage extends StatefulWidget {
  const _AnimatedMessage({super.key, required this.child});

  final Widget child;

  @override
  State<_AnimatedMessage> createState() => _AnimatedMessageState();
}

class _AnimatedMessageState extends State<_AnimatedMessage> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: AppMotion.regular,
      curve: AppMotion.curve,
      offset: _visible ? Offset.zero : const Offset(0, 0.06),
      child: AnimatedOpacity(
        duration: AppMotion.regular,
        curve: AppMotion.curve,
        opacity: _visible ? 1 : 0,
        child: widget.child,
      ),
    );
  }
}
