import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../services/ai_service.dart';
import '../../services/mock_firestore_service.dart';
import '../../services/mock_auth_service.dart';
import '../../models/message_model.dart';
import '../../models/emotion_analysis_model.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/glass_container.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, String>> _chatHistory = [];
  bool _isLoading = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
    try {
      final authService = Provider.of<MockAuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        setState(() => _currentUserId = user.id);
        await _loadChatHistory();

        // Add welcome message if no chat history
        if (_chatHistory.isEmpty) {
          setState(() {
            _chatHistory.add({
              'user': '',
              'assistant':
                  'Hello! I\'m your AI Wellness Assistant. I\'m here to listen and support you. How are you feeling today?',
            });
          });
        }
      } else {
        // If no user, still allow chat but show a message
        setState(() {
          _currentUserId = 'guest_user';
          _chatHistory.add({
            'user': '',
            'assistant':
                'Hello! I\'m your AI Wellness Assistant. Please sign in to save your chat history.',
          });
        });
      }
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    }
  }

  Future<void> _loadChatHistory() async {
    if (_currentUserId == null) return;

    try {
      final firestoreService = Provider.of<MockFirestoreService>(
        context,
        listen: false,
      );
      final messages = await firestoreService
          .getMessages(_currentUserId!)
          .first;

      setState(() {
        _chatHistory.clear();
        // Group messages by conversation pairs
        MessageModel? lastUserMessage;
        for (var msg in messages.reversed) {
          if (msg.senderId == _currentUserId) {
            lastUserMessage = msg;
            _chatHistory.add({'user': msg.content, 'assistant': ''});
          } else if (lastUserMessage != null && _chatHistory.isNotEmpty) {
            _chatHistory.last['assistant'] = msg.content;
            lastUserMessage = null;
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty ||
        _isLoading ||
        _currentUserId == null)
      return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    // Add user message to chat history
    setState(() {
      _chatHistory.add({'user': userMessage, 'assistant': ''});
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final aiService = Provider.of<AIService>(context, listen: false);
      final firestoreService = Provider.of<MockFirestoreService>(
        context,
        listen: false,
      );

      // Save user message
      final userMsg = MessageModel(
        id: const Uuid().v4(),
        senderId: _currentUserId!,
        receiverId: 'ai',
        content: userMessage,
        timestamp: DateTime.now(),
      );
      await firestoreService.saveMessage(userMsg);

      // Analyze emotions
      EmotionAnalysisModel emotionAnalysis;
      try {
        emotionAnalysis = await aiService.analyzeEmotions(
          userMessage,
          _currentUserId!,
          null,
        );
      } catch (e) {
        debugPrint('Emotion analysis error: $e');
        // Use default emotion analysis if API fails
        emotionAnalysis = EmotionAnalysisModel(
          userId: _currentUserId!,
          timestamp: DateTime.now(),
          primaryEmotion: 'neutral',
          emotionScores: {
            'anxiety': 0.3,
            'stress': 0.3,
            'sadness': 0.3,
            'anger': 0.2,
            'happiness': 0.5,
          },
          overallScore: 0.5,
          riskLevel: 'low',
          suggestedActions: [
            'Take deep breaths',
            'Practice mindfulness',
            'Consider talking to someone',
          ],
        );
      }

      // Get AI response
      String aiResponse;
      try {
        aiResponse = await aiService.getChatResponse(userMessage, _chatHistory);
      } catch (e) {
        debugPrint('AI response error: $e');
        // Fallback response if API fails
        aiResponse =
            'I understand you\'re going through something. While I\'m here to listen, '
            'it\'s important to remember that I\'m not a replacement for professional help. '
            'Would you like to talk more about what\'s on your mind?';
      }

      // Update chat history
      if (mounted) {
        setState(() {
          _chatHistory.last['assistant'] = aiResponse;
          _isLoading = false;
        });
      }

      // Save AI response
      final aiMsg = MessageModel(
        id: const Uuid().v4(),
        senderId: 'ai',
        receiverId: _currentUserId!,
        content: aiResponse,
        timestamp: DateTime.now(),
        emotionData: emotionAnalysis.emotionScores,
        suggestedAction: emotionAnalysis.suggestedActions.isNotEmpty
            ? emotionAnalysis.suggestedActions.first
            : null,
      );
      await firestoreService.saveMessage(aiMsg);

      // Save emotion analysis
      await firestoreService.saveEmotionAnalysis(emotionAnalysis);

      // Show risk warning if needed
      if (mounted &&
          (emotionAnalysis.riskLevel == 'high' ||
              emotionAnalysis.riskLevel == 'critical')) {
        _showRiskWarning(emotionAnalysis);
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showRiskWarning(EmotionAnalysisModel analysis) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Important Notice'),
        content: Text(
          'Based on your recent messages, we\'ve detected ${analysis.riskLevel} risk levels. '
          'We strongly recommend speaking with a licensed therapist or mental health professional. '
          'Would you like to find a therapist?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Navigate to therapist screen
            },
            child: const Text('Find Therapist'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      imageUrl:
          'https://images.unsplash.com/photo-1518531933037-91b2f5f229cc?auto=format&fit=crop&q=80',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Colors.white),
          title: const Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.smart_toy, color: Colors.white),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Assistant',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'Always here to help',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: _chatHistory.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start a conversation',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _chatHistory.length + (_isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _chatHistory.length) {
                          return const _LoadingMessage();
                        }

                        final entry = _chatHistory[index];
                        return Column(
                          children: [
                            if (entry['user']!.isNotEmpty)
                              _UserMessage(text: entry['user']!),
                            if (entry['assistant']!.isNotEmpty)
                              _AssistantMessage(text: entry['assistant']!),
                          ],
                        );
                      },
                    ),
            ),
            GlassContainer(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              borderRadius: BorderRadius.circular(30),
              opacity: 0.2,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: TextStyle(color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
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
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
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

class _UserMessage extends StatelessWidget {
  final String text;

  const _UserMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  final String text;

  const _AssistantMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, right: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: Colors.white24,
                child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 15, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingMessage extends StatelessWidget {
  const _LoadingMessage();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 48),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Text('Thinking...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
