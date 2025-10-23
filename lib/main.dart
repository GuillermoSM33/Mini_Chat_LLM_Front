import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'widgets/message_bubble.dart';
import 'widgets/input_bar.dart';
import 'widgets/typing_indicator.dart';

// Allow overriding the backend URL at compile/run time
const String _kBackendBaseUrlFromDefine =
    String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No detenemos la app si no existe el archivo (p. ej. en builds web)
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FrontChat',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  static String get backendBaseUrl {
    if (_kBackendBaseUrlFromDefine.isNotEmpty) return _kBackendBaseUrlFromDefine;
    if (kIsWeb) return 'http://localhost:8000';
    try {
      final v = dotenv.env['BACKEND_BASE_URL'];
      return (v == null || v.isEmpty) ? 'http://localhost:8000' : v;
    } catch (_) {
      return 'http://localhost:8000';
    }
  }

  Future<void> _handleSend(String text) async {
    if (text.trim().isEmpty) return;

    final message = _ChatMessage(
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    setState(() => _messages.add(message));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    final history = _messages
        .map((m) => {
              'role': m.isMe ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final base = backendBaseUrl.endsWith('/')
        ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
        : backendBaseUrl;
    final url = Uri.parse('$base/chat');

    setState(() => _isLoading = true);

    const int maxRetries = 3;
    int attempt = 0;
    Duration backoff = const Duration(milliseconds: 500);

    while (attempt < maxRetries) {
      attempt += 1;
      try {
        final resp = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'message': text.trim(), 'history': history}),
            )
            .timeout(const Duration(seconds: 20));

        if (!mounted) return;

        if (resp.statusCode == 200) {
          final Map<String, dynamic> j = jsonDecode(resp.body);
          final answer = (j['answer'] ?? '').toString();

          final reply = _ChatMessage(
            text: answer,
            timestamp: DateTime.now(),
            isMe: false,
          );

          setState(() {
            _messages.add(reply);
            _isLoading = false;
          });

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent + 80,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
          break;
        } else {
          if (attempt >= maxRetries) {
            _showSnack('Error del servidor: ${resp.statusCode}');
            setState(() => _isLoading = false);
          } else {
            await Future.delayed(backoff);
            backoff *= 2;
          }
        }
      } catch (e) {
        if (attempt >= maxRetries) {
          _showSnack('Error: $e');
          setState(() => _isLoading = false);
        } else {
          await Future.delayed(backoff);
          backoff *= 2;
        }
      }
    }
  }

  void _showSnack(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot del menú del Restaurante'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_isLoading) const TypingIndicator(),
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: MessageBubble(
                        text: msg.text,
                        isMe: msg.isMe,
                        timestamp: msg.timestamp,
                      ),
                    );
                  },
                ),
              ),
            ),
            MessageInput(onSend: _handleSend),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  final String text;
  final DateTime timestamp;
  final bool isMe;
}
