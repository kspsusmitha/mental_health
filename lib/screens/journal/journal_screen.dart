import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../services/mock_firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/ai_service.dart';
import '../../models/journal_entry_model.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user != null) {
      setState(() => _currentUserId = user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Well-Being Journal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEntryDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<JournalEntryModel>>(
        stream: Provider.of<MockFirestoreService>(context).getJournalEntries(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No journal entries yet',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _showAddEntryDialog(),
                    child: const Text('Write Your First Entry'),
                  ),
                ],
              ),
            );
          }

          final entries = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _JournalEntryCard(entry: entry);
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddEntryDialog() async {
    final contentController = TextEditingController();
    String selectedMood = 'neutral';
    final moods = ['happy', 'sad', 'anxious', 'stressed', 'angry', 'neutral', 'depressed', 'overwhelmed'];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Journal Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How are you feeling today?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: moods.map((mood) {
                    final isSelected = selectedMood == mood;
                    return FilterChip(
                      label: Text(mood),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => selectedMood = mood);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: 'Write your thoughts...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (contentController.text.trim().isNotEmpty) {
                  await _saveEntry(contentController.text.trim(), selectedMood);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEntry(String content, String mood) async {
    if (_currentUserId == null) return;

    try {
      final aiService = Provider.of<AIService>(context, listen: false);
      final firestoreService = Provider.of<MockFirestoreService>(context, listen: false);

      // Analyze emotions from journal entry
      final emotionAnalysis = await aiService.analyzeEmotions(
        content,
        _currentUserId!,
        null,
      );

      // Calculate mood score from emotion analysis
      final moodScore = emotionAnalysis.overallScore;

      // Create journal entry
      final entry = JournalEntryModel(
        id: const Uuid().v4(),
        userId: _currentUserId!,
        content: content,
        mood: mood,
        moodScore: moodScore,
        date: DateTime.now(),
        emotionAnalysis: emotionAnalysis.emotionScores,
        stressTriggers: emotionAnalysis.suggestedActions,
      );

      await firestoreService.saveJournalEntry(entry);
      await firestoreService.saveEmotionAnalysis(emotionAnalysis);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving entry: ${e.toString()}')),
        );
      }
    }
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntryModel entry;

  const _JournalEntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final moodColors = {
      'happy': Colors.green,
      'sad': Colors.blue,
      'anxious': Colors.orange,
      'stressed': Colors.red,
      'angry': Colors.deepOrange,
      'neutral': Colors.grey,
      'depressed': Colors.purple,
      'overwhelmed': Colors.pink,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: moodColors[entry.mood]?.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        entry.mood.toUpperCase(),
                        style: TextStyle(
                          color: moodColors[entry.mood],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(entry.moodScore * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  dateFormat.format(entry.date),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.content,
              style: const TextStyle(fontSize: 15),
            ),
            if (entry.stressTriggers != null && entry.stressTriggers!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: entry.stressTriggers!.take(3).map((trigger) {
                  return Chip(
                    label: Text(trigger),
                    labelStyle: const TextStyle(fontSize: 11),
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

