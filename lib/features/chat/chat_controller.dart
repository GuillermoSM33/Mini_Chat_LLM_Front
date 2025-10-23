import 'package:flutter/material.dart';
import '../../core/models.dart';
import 'chat_repository.dart';

class ChatController extends ChangeNotifier {
  final ChatRepository _repo = ChatRepository();

  final List<Message> messages = [];
  bool loading = false;
  String? error;

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;

    messages.add(Message(role: 'user', content: text));
    loading = true;
    error = null;
    notifyListeners();

    try {
      final answer = await _repo.ask(text, messages);
      messages.add(Message(role: 'assistant', content: answer));
    } catch (e) {
      error = 'Error de conexión: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
