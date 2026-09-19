import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../models/language.dart';
import '../../services/localization_service.dart';
import '../../services/mock_ai_service.dart';

class AiChatScreen extends StatefulWidget {
  final AppLocale currentLocale;
  final UserProfile userProfile;
  final String? initialTask;

  const AiChatScreen({
    super.key,
    required this.currentLocale,
    required this.userProfile,
    this.initialTask,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  late List<ChatMessage> _messages;

  @override
  void initState() {
    super.initState();
    final localizations = AppLocalizations(widget.currentLocale);
    
    if (widget.initialTask != null) {
      // Start with task-specific greeting
      _messages = [
        ChatMessage(
          sender: localizations.appName,
          text: MockAiService.getTaskGreeting(
            widget.initialTask!,
            widget.userProfile,
            widget.currentLocale,
          ),
          isUser: false,
        ),
      ];
    } else {
      // Default greeting
      _messages = [
        ChatMessage(
          sender: localizations.appName,
          text: _getDefaultGreeting(localizations),
          isUser: false,
        ),
      ];
    }
  }

  String _getDefaultGreeting(AppLocalizations localizations) {
    // Simple greeting based on learning language
    switch (widget.userProfile.learningLanguage) {
      case Language.english:
        return "Hey! Let's use some English today. What are you doing right now?";
      case Language.russian:
        return "Привет! Давайте сегодня поупражняемся в русском. Что вы делаете прямо сейчас?";
      case Language.kazakh:
        return "Сәлем! Бүгін қазақ тілінде жаттайық. Қазір не істеп жатсыз?";
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        sender: 'You',
        text: text,
        isUser: true,
      ));
      _messageController.clear();

      // Add varied mock response after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final localizations = AppLocalizations(widget.currentLocale);
          final response = MockAiService.getResponse(
            text,
            widget.userProfile,
            widget.currentLocale,
          );
          
          setState(() {
            _messages.add(ChatMessage(
              sender: localizations.appName,
              text: response,
              isUser: false,
            ));
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLocale);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.aiChatTitle),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _messages[index];
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: localizations.aiMessageHint,
                      border: const OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String sender;
  final String text;
  final bool isUser;

  const ChatMessage({
    super.key,
    required this.sender,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  radius: 16,
                  child: const Text(
                    'O',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                constraints: const BoxConstraints(maxWidth: 280),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isUser ? AppTheme.primaryColor : AppTheme.lightBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: isUser ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppTheme.textSecondary,
                  radius: 16,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
