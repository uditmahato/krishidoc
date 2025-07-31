// llm_chat_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/locale/language_ar.dart';
import '../providers/chat_provider.dart';

class LlmChatPage extends StatefulWidget {
  const LlmChatPage({super.key});

  @override
  State<LlmChatPage> createState() => _LlmChatPageState();
}

class _LlmChatPageState extends State<LlmChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final theme = Theme.of(context);
    final BaseLanguage lang = BaseLanguage.of(context);

    // Flatten into a list of chat items: user question then AI reply
    final raw = chatProvider.chats;
    final items = <_ChatItem>[];
    for (final chat in raw) {
      items.add(_ChatItem(text: chat.message, isUser: true));
      items.add(_ChatItem(text: chat.reply, isUser: false));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(lang.chatTitle),
        backgroundColor: theme.colorScheme.primary,
        elevation: 2,
      ),
      body: Column(
        children: [
          // ─── Chat List ─────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                // reverse the flat list so newest at bottom
                final item = items[items.length - 1 - idx];
                return _buildBubble(item, theme, lang);
              },
            ),
          ),

          // ─── Loading Indicator ───────────────────────────────
          if (chatProvider.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            ),

          // ─── Input Row ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.primary, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: lang.chatInputHint,
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: theme.colorScheme.primary),
                  onPressed: () {
                    final text = _controller.text.trim();
                    if (text.isNotEmpty) {
                      chatProvider.sendMessage(
                        text,
                        lang is LanguageAr ? 'ar' : 'en',
                      );
                      _controller.clear();
                      // scroll to bottom
                      Future.delayed(const Duration(milliseconds: 100), () {
                        _scrollController.animateTo(
                          0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatItem item, ThemeData theme, BaseLanguage lang) {
    final bgColor = item.isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = item.isUser
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: item.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(item.isUser ? 12 : 0),
            topRight: Radius.circular(item.isUser ? 0 : 12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: MarkdownBody(
          data: item.text,
          styleSheet: MarkdownStyleSheet.fromTheme(
            theme,
          ).copyWith(p: theme.textTheme.bodyMedium?.copyWith(color: textColor)),
        ),
      ),
    );
  }
}

class _ChatItem {
  final String text;
  final bool isUser;
  _ChatItem({required this.text, required this.isUser});
}
