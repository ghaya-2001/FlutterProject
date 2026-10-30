import 'package:flutter/material.dart';

import '../../../shared/widgets/screen_header.dart';
import '../../donations/presentation/donations_screen.dart';
import '../../expiry/presentation/expiring_soon_screen.dart';
import '../../list/presentation/list_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../domain/chatbot_engine.dart';

class _ChatMessage {
  const _ChatMessage.user(this.text) : fromUser = true, reply = null;

  _ChatMessage.bot(ChatbotReply this.reply)
    : fromUser = false,
      text = reply.text;

  final bool fromUser;
  final String text;
  final ChatbotReply? reply;
}

/// Simple rule-based assistant with predefined questions.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key, this.engine});

  /// Defaults to an engine using the app-wide repositories.
  final ChatbotEngine? engine;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  late final ChatbotEngine _engine = widget.engine ?? ChatbotEngine();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    _ChatMessage.bot(ChatbotEngine.welcome),
  ];

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _ask(ChatbotQuestion question) {
    _addExchange(question.label, _engine.answer(question.topic));
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    _addExchange(text, _engine.answerText(text));
  }

  void _addExchange(String question, ChatbotReply reply) {
    setState(() {
      _messages.add(_ChatMessage.user(question));
      _messages.add(_ChatMessage.bot(reply));
    });
    // Scroll to the newest message once it is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openLink(ChatbotLink link) {
    final Widget screen;
    switch (link) {
      case ChatbotLink.expiringSoon:
        screen = const ExpiringSoonScreen();
      case ChatbotLink.shoppingList:
        screen = const ListScreen();
      case ChatbotLink.donations:
        screen = const DonationsScreen();
      case ChatbotLink.notifications:
        screen = const NotificationsScreen();
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: ScreenHeader(title: 'Assistant'),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 8,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return _Bubble(
                    message: message,
                    onLink: message.reply?.link == null
                        ? null
                        : () => _openLink(message.reply!.link!),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Every predefined question stays visible.
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final question in chatbotQuestions)
                        ActionChip(
                          key: ValueKey(
                            'chatbot-question-${question.topic.name}',
                          ),
                          label: Text(question.label),
                          onPressed: () => _ask(question),
                          backgroundColor: const Color(0xFFE8F5E9),
                          side: BorderSide.none,
                          labelStyle: const TextStyle(
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('chatbot-input'),
                          controller: _inputController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Ask a question…',
                            filled: true,
                            fillColor: const Color(0xFFF5F9F3),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(16),
                        child: IconButton(
                          key: const ValueKey('chatbot-send'),
                          onPressed: _send,
                          icon: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.onLink});

  final _ChatMessage message;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final fromUser = message.fromUser;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromUser) ...[
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFC8E6C9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.eco_rounded,
                size: 20,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: fromUser ? const Color(0xFF2E7D32) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(fromUser ? 20 : 4),
                  bottomRight: Radius.circular(fromUser ? 4 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: fromUser ? Colors.white : const Color(0xFF1B1B1B),
                    ),
                  ),
                  if (onLink != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: onLink,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2E7D32),
                        side: const BorderSide(color: Color(0xFF2E7D32)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(message.reply!.linkLabel ?? 'Open'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
