import 'package:flutter/material.dart';
import 'package:krishidoc/locale/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:krishidoc/locale/base_language_key.dart';
import 'package:krishidoc/utils/colors.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';

class LlmChatPage extends StatefulWidget {
  const LlmChatPage({super.key});

  @override
  State<LlmChatPage> createState() => _LlmChatPageState();
}

class _LlmChatPageState extends State<LlmChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final BaseLanguage lang = AppLocalizations.of(context);

    final raw = chatProvider.chats;
    final items = <_ChatItem>[];
    for (final chat in raw) {
      items.add(_ChatItem(text: chat.message, isUser: true));
      items.add(_ChatItem(text: chat.reply, isUser: false));
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(
          lang.appName,
          style: TextStyle(color: textPrimaryDarkColor),
        ),
        backgroundColor: primaryColor,
        elevation: 2,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final item = items[items.length - 1 - idx];
                return _buildBubble(item, theme, lang);
              },
            ),
          ),
          if (chatProvider.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(color: progressIndicatorColor),
            ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: lang.chatInputHint,
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: textSecondaryLightColor),
                    ),
                    onSubmitted: (_) =>
                        _sendMessage(chatProvider, settingsProvider),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: primaryColor),
                  onPressed: () => _sendMessage(chatProvider, settingsProvider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(_ChatItem item, ThemeData theme, BaseLanguage lang) {
    final bgColor = item.isUser ? primaryColor : cardColor;
    final textColor = item.isUser
        ? textPrimaryDarkColor
        : textPrimaryLightColor;

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

  Future<void> _sendMessage(
    ChatProvider chatProvider,
    SettingsProvider settingsProvider,
  ) async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      print(
        'LlmChatPage: Sending message in language ${settingsProvider.language}',
      );
      await chatProvider.sendMessage(text, settingsProvider.language);
      _controller.clear();
      _focusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _ChatItem {
  final String text;
  final bool isUser;
  _ChatItem({required this.text, required this.isUser});
}
