import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'chat_controller.dart';
import '../../widgets/message_bubble.dart';
import '../../widgets/input_bar.dart';
import '../../widgets/typing_indicator.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatController(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Chatbot RAG'), centerTitle: true),
        body: const SafeArea(child: _ChatView()),
      ),
    );
  }
}

class _ChatView extends StatelessWidget {
  const _ChatView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: controller.messages.length,
            itemBuilder: (context, index) {
              final msg = controller.messages[index];
              return MessageBubble(
                text: msg.content,
                isMe: msg.role == 'user',
                timestamp: DateTime.now(),
              );
            },
          ),
        ),
        if (controller.loading) const TypingIndicator(),
        MessageInput(
          onSend: (text) {
            if (!controller.loading && text.trim().isNotEmpty) {
              controller.send(text);
            }
          },
        ),
      ],
    );
  }
}
