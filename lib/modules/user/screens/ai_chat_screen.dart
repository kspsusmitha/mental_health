import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../services/ai_service.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/message_model.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MessageModel> _messages = [];
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      setState(() => _currentUserId = user.id);
      _loadChatHistory();
    }
  }

  Future<void> _loadChatHistory() async {
    if (_currentUserId == null) return;
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;
      
      final messagesData = await dbService.readList('$userNodePath/$_currentUserId/ai_chats');
      
      setState(() {
        _messages.clear();
        _messages.addAll(
          messagesData.map((data) => MessageModel.fromMap(data)).toList()
        );
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      });
      
      if (_messages.isNotEmpty && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentUserId == null) return;

    final userMessage = MessageModel(
      id: const Uuid().v4(),
      senderId: _currentUserId!,
      receiverId: 'ai',
      content: _messageController.text.trim(),
      timestamp: DateTime.now(),
      isRead: true,
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    final messageText = _messageController.text.trim();
    _messageController.clear();
    _scrollToBottom();

    try {
      // Save user message to database
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;
      
      await dbService.writeData(
        '$userNodePath/$_currentUserId/ai_chats/${userMessage.id}',
        userMessage.toMap(),
      );

      // Get AI response
      final chatHistory = _messages
          .where((m) => m.senderId == _currentUserId || m.receiverId == 'ai')
          .take(10)
          .map((m) => {
                'user': m.senderId == _currentUserId ? m.content : '',
                'assistant': m.senderId == 'ai' ? m.content : '',
              })
          .where((m) => m['user']!.isNotEmpty || m['assistant']!.isNotEmpty)
          .map((m) => Map<String, String>.from(m))
          .toList();

      final aiService = Provider.of<AIService>(context, listen: false);
      final response = await aiService.getChatResponse(messageText, chatHistory);

      final aiMessage = MessageModel(
        id: const Uuid().v4(),
        senderId: 'ai',
        receiverId: _currentUserId!,
        content: response,
        timestamp: DateTime.now(),
        isRead: true,
      );

      setState(() {
        _messages.add(aiMessage);
        _isLoading = false;
      });

      // Save AI message to database
      await dbService.writeData(
        '$userNodePath/$_currentUserId/ai_chats/${aiMessage.id}',
        aiMessage.toMap(),
      );

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.blue),
            SizedBox(width: 8),
            Text('AI Support Assistant'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with AI',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(width: 16),
                              Text('AI is thinking...'),
                            ],
                          ),
                        );
                      }
                      final message = _messages[index];
                      final isUser = message.senderId == _currentUserId;
                      return _buildMessageBubble(message, isUser);
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
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
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
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

  Widget _buildMessageBubble(MessageModel message, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: isUser
                    ? Colors.white.withOpacity(0.7)
                    : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

