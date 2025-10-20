import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Allow overriding the backend URL at compile/run time with --dart-define=BACKEND_BASE_URL=http://host:8000
const String _kBackendBaseUrlFromDefine = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intentamos cargar .env para entornos donde esté disponible (mobile/desktop/dev).
  // En Flutter Web lo recomendable es usar --dart-define; si el archivo no existe, lo ignoramos.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // No detener la app si no existe el archivo (por ejemplo en builds web sin assets/.env)
    // El getter backendBaseUrl ya usa --dart-define y fallback a localhost.
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FrontChat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  // Cambia esta URL a la de tu backend FastAPI si es necesario.
  // Ejemplo local en emulador Android: http://10.0.2.2:8000
  // o en desktop: http://localhost:8000
  static String get backendBaseUrl {
    // Priority: --dart-define > .env file > fallback
    if (_kBackendBaseUrlFromDefine.isNotEmpty) return _kBackendBaseUrlFromDefine;
    // En Web es preferible usar --dart-define; evitar acceder a dotenv.env porque
    // puede no haberse inicializado y lanzar NotInitializedError.
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    try {
      final v = dotenv.env['BACKEND_BASE_URL'];
      return (v == null || v.isEmpty) ? 'http://localhost:8000' : v;
    } catch (_) {
      // Si dotenv no fue inicializado, usar fallback
      return 'http://localhost:8000';
    }
  }

  bool _isLoading = false;

  Future<void> _handleSend(String text) async {
    if (text.trim().isEmpty) return;

    final message = _ChatMessage(
      text: text.trim(),
      timestamp: DateTime.now(),
      isMe: true,
    );

    setState(() {
      _messages.add(message);
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

    // construir historial simple para enviar al backend
    final history = _messages
        .map((m) => {
              'role': m.isMe ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final base = backendBaseUrl.endsWith('/') ? backendBaseUrl.substring(0, backendBaseUrl.length - 1) : backendBaseUrl;
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

          // éxito, salimos del loop
          break;
        } else {
          final msg = 'Error del servidor: ${resp.statusCode} (intento $attempt/$maxRetries)';
          if (attempt >= maxRetries) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            setState(() => _isLoading = false);
          } else {
            await Future.delayed(backoff);
            backoff *= 2;
          }
        }
      } catch (e) {
        if (attempt >= maxRetries) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          setState(() => _isLoading = false);
        } else {
          await Future.delayed(backoff);
          backoff *= 2;
        }
      }
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
        title: const Text('FrontChat'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (_isLoading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: Container(
                color: Colors.grey[100],
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
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
  _ChatMessage({required this.text, required this.timestamp, required this.isMe});

  final String text;
  final DateTime timestamp;
  final bool isMe;
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.text, required this.isMe, required this.timestamp});

  final String text;
  final bool isMe;
  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isMe ? Colors.blueAccent : Colors.white;
    final textColor = isMe ? Colors.white : Colors.black87;
    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );

    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: align,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    )
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: TextStyle(color: textColor, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(color: textColor.withAlpha((0.8 * 255).round()), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTimestamp(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class MessageInput extends StatefulWidget {
  const MessageInput({super.key, required this.onSend});

  final void Function(String) onSend;

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  void _onChanged() {
    setState(() {
      _canSend = _controller.text.trim().isNotEmpty;
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje...',
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: _canSend ? Theme.of(context).primaryColor : Colors.grey),
            onPressed: _canSend ? _submit : null,
          ),
        ],
      ),
    );
  }
}
