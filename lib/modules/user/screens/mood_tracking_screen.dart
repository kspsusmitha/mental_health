import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../services/ai_service.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../models/emotion_analysis_model.dart';
import '../../../models/journal_entry_model.dart';
import '../../../utils/page_transitions.dart';
import 'wellness_screen.dart';
import 'journal_screen.dart';
import 'therapist_matching_screen.dart';

class MoodTrackingScreen extends StatefulWidget {
  const MoodTrackingScreen({super.key});

  @override
  State<MoodTrackingScreen> createState() => _MoodTrackingScreenState();
}

class _MoodTrackingScreenState extends State<MoodTrackingScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final Set<String> _selectedEmotions = {};
  String? _selectedMood;
  double _moodIntensity = 5.0; // 1-10 scale
  bool _isAnalyzing = false;
  EmotionAnalysisModel? _analysisResult;
  List<Recommendation> _recommendations = [];
  final RecommendationService _recommendationService = RecommendationService();
  bool _showCalendar = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Map<String, dynamic>> _moodChecks = [];

  // Emotion suggestions organized by category
  final Map<String, List<String>> _emotionSuggestions = {
    'Positive': [
      'Happy',
      'Grateful',
      'Content',
      'Excited',
      'Hopeful',
      'Peaceful',
      'Confident',
      'Motivated',
    ],
    'Negative': [
      'Sad',
      'Anxious',
      'Stressed',
      'Angry',
      'Frustrated',
      'Overwhelmed',
      'Lonely',
      'Tired',
    ],
    'Neutral': [
      'Calm',
      'Neutral',
      'Thoughtful',
      'Reflective',
      'Uncertain',
      'Curious',
    ],
  };

  final List<String> _moodOptions = [
    'Very Happy',
    'Happy',
    'Neutral',
    'Sad',
    'Very Sad',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

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

  void _toggleEmotion(String emotion) {
    setState(() {
      if (_selectedEmotions.contains(emotion)) {
        _selectedEmotions.remove(emotion);
      } else {
        _selectedEmotions.add(emotion);
      }
    });
  }

  Future<void> _saveMoodCheck() async {
    if (_selectedMood == null && _selectedEmotions.isEmpty && _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one emotion or describe how you feel'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading user data...')),
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final aiService = Provider.of<AIService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      
      if (userNodePath == null) {
        setState(() => _isAnalyzing = false);
        return;
      }
      
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        setState(() => _isAnalyzing = false);
        return;
      }

      final username = currentUser.name.toLowerCase().replaceAll(' ', '_');
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

      // Check if mood check already exists for today
      try {
        final existingMoodChecks = await dbService.readList('$userNodePath/$username/mood_checks');
        for (var checkData in existingMoodChecks) {
          try {
            if (checkData['date'] != null) {
              final checkDate = DateTime.fromMillisecondsSinceEpoch(checkData['date'] as int);
              final checkDateKey = DateFormat('yyyy-MM-dd').format(checkDate);
              if (checkDateKey == dateKey) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You already have a mood check for today (${DateFormat('MMM dd, yyyy').format(today)}). Only one mood check per day is allowed.'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
                setState(() => _isAnalyzing = false);
                return;
              }
            }
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        // No existing mood checks, continue
      }

      // Also check journal entries for today
      try {
        final existingEntries = await dbService.readList('$userNodePath/$username/journal_entries');
        for (var entryData in existingEntries) {
          try {
            final existingEntry = JournalEntryModel.fromMap(entryData);
            final existingDateKey = DateFormat('yyyy-MM-dd').format(existingEntry.date);
            if (existingDateKey == dateKey) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('You already have a journal entry for today (${DateFormat('MMM dd, yyyy').format(today)}). Only one entry per day is allowed.'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              setState(() => _isAnalyzing = false);
              return;
            }
          } catch (e) {
            continue;
          }
        }
      } catch (e) {
        // No existing entries, continue
      }

      // Build description text for AI analysis
      final descriptionText = _descriptionController.text.trim();
      final emotionsText = _selectedEmotions.join(', ');
      final combinedText = descriptionText.isNotEmpty
          ? '$descriptionText. Emotions: $emotionsText'
          : 'Emotions: $emotionsText';

      // Load journal history for context
      final journalData = await dbService.readList('$userNodePath/$username/journal_entries');
      final journalHistory = journalData.take(5).toList();

      // Analyze with AI
      final analysis = await aiService.analyzeEmotions(
        combinedText,
        _currentUserId!,
        journalHistory,
      );

      // Determine mood from selection or AI
      String mood = _selectedMood?.toLowerCase().replaceAll(' ', '_') ?? 
                    analysis.primaryEmotion.toLowerCase();

      // Calculate mood score from intensity and AI analysis
      final moodScore = (_moodIntensity / 10.0) * 0.5 + (analysis.overallScore * 0.5);

      // Save mood check details
      final moodCheckData = {
        'id': const Uuid().v4(),
        'userId': _currentUserId!,
        'mood': mood,
        'moodScore': moodScore.clamp(0.0, 1.0),
        'moodIntensity': _moodIntensity,
        'selectedEmotions': _selectedEmotions.toList(),
        'description': descriptionText,
        'date': today.millisecondsSinceEpoch,
        'emotionAnalysis': analysis.emotionScores,
        'stressTriggers': analysis.suggestedActions,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      };

      await dbService.writeData(
        '$userNodePath/$username/mood_checks/${moodCheckData['id']}',
        moodCheckData,
      );

      // Save as journal entry (mood checks also create journal entries)
      final entry = JournalEntryModel(
        id: const Uuid().v4(),
        userId: _currentUserId!,
        content: descriptionText.isNotEmpty 
            ? descriptionText 
            : 'Mood check: ${_selectedEmotions.join(", ")}',
        mood: mood,
        moodScore: moodScore.clamp(0.0, 1.0),
        date: today,
        emotionAnalysis: analysis.emotionScores,
        stressTriggers: analysis.suggestedActions,
        tags: _selectedEmotions.toList(),
      );

      await dbService.writeData(
        '$userNodePath/$username/journal_entries/${entry.id}',
        entry.toMap(),
      );

      // Save mood analysis
      await dbService.pushData(
        '$userNodePath/$username/mood_analyses',
        analysis.toMap(),
      );

      // Get personalized recommendations based on current mood
      final recommendations = await _recommendationService.getPersonalizedRecommendations(_currentUserId!);

      setState(() {
        _analysisResult = analysis;
        _recommendations = recommendations;
        _isAnalyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Mood check saved successfully for ${DateFormat('MMM dd, yyyy').format(today)}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving mood check: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Check-In'),
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.check_circle_outline : Icons.calendar_today),
            onPressed: () {
              setState(() {
                _showCalendar = !_showCalendar;
                if (_showCalendar) {
                  _loadMoodHistory();
                  if (_selectedDay == null) {
                    _selectedDay = DateTime.now();
                  }
                }
              });
            },
            tooltip: _showCalendar ? 'Show Check-In' : 'Show Calendar',
          ),
          if (_analysisResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _selectedEmotions.clear();
                  _selectedMood = null;
                  _moodIntensity = 5.0;
                  _descriptionController.clear();
                  _analysisResult = null;
                });
              },
              tooltip: 'New Check-In',
            ),
        ],
      ),
      body: _showCalendar
          ? _buildMoodCalendarView()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Card
            Card(
              elevation: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.mood,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'How are you feeling right now?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take a moment to check in with yourself',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Overall Mood Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.sentiment_satisfied, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Overall Mood',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _moodOptions.map((mood) {
                        final isSelected = _selectedMood == mood;
                        return FilterChip(
                          label: Text(mood),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedMood = selected ? mood : null);
                          },
                          selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          checkmarkColor: Theme.of(context).colorScheme.primary,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mood Intensity Slider
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Intensity Level',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${_moodIntensity.toInt()}/10',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _moodIntensity,
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _moodIntensity.toInt().toString(),
                      onChanged: (value) {
                        setState(() => _moodIntensity = value);
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Low', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        Text('High', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Emotion Checkboxes
            ..._emotionSuggestions.entries.map((entry) {
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            entry.key == 'Positive'
                                ? Icons.emoji_emotions
                                : entry.key == 'Negative'
                                    ? Icons.sentiment_dissatisfied
                                    : Icons.sentiment_neutral,
                            color: entry.key == 'Positive'
                                ? Colors.green
                                : entry.key == 'Negative'
                                    ? Colors.red
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            entry.key,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: entry.value.map((emotion) {
                          final isSelected = _selectedEmotions.contains(emotion);
                          return FilterChip(
                            label: Text(emotion),
                            selected: isSelected,
                            onSelected: (_) => _toggleEmotion(emotion),
                            selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                            checkmarkColor: Theme.of(context).colorScheme.primary,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            // Description Text Field
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit_note, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Describe Your Feelings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Optional: Add more details about what you\'re experiencing',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind? What\'s causing these feelings?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _saveMoodCheck,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                      child: _isAnalyzing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 8),
                          Text(
                            'Save Mood Check',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Analysis Results
            if (_analysisResult != null) ...[
              const SizedBox(height: 24),
              _buildAnalysisResult(_analysisResult!),
            ],

            // Personalized Recommendations
            if (_recommendations.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildRecommendationsSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult(EmotionAnalysisModel analysis) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue[50]!,
              Colors.purple[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 8),
            Text(
              'Analysis Results',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
              ],
            ),
            const SizedBox(height: 20),
            _buildEmotionCard('Primary Emotion', analysis.primaryEmotion),
            const SizedBox(height: 12),
            _buildScoreCard('Overall Score', analysis.overallScore),
            const SizedBox(height: 12),
            _buildRiskCard('Risk Level', analysis.riskLevel),
            const SizedBox(height: 20),
            Text(
              'Suggested Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...analysis.suggestedActions.map((action) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          action,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
            value.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, double score) {
    final color = score < 0.3
        ? Colors.red
        : score < 0.5
            ? Colors.orange
            : score < 0.7
                ? Colors.yellow
                : Colors.green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            Text(
              '${(score * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
          value: score,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskCard(String label, String value) {
    Color riskColor;
    IconData riskIcon;
    switch (value.toLowerCase()) {
      case 'critical':
        riskColor = Colors.red;
        riskIcon = Icons.warning;
        break;
      case 'high':
        riskColor = Colors.orange;
        riskIcon = Icons.warning_amber;
        break;
      case 'medium':
        riskColor = Colors.yellow[700]!;
        riskIcon = Icons.info;
        break;
      default:
        riskColor = Colors.green;
        riskIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(riskIcon, color: riskColor),
              const SizedBox(width: 8),
          Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: riskColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber[50]!,
              Colors.orange[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[700], size: 28),
                const SizedBox(width: 8),
                Text(
                  'Personalized Recommendations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Based on your current mood, here are some suggestions',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 16),
            ..._recommendations.take(5).map((recommendation) => _buildRecommendationCard(recommendation)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(Recommendation recommendation) {
    final icon = _getRecommendationIcon(recommendation.type);
    final color = _getRecommendationColor(recommendation.type);
    final priorityColor = _getPriorityColor(recommendation.priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: recommendation.priority == RecommendationPriority.high ? 3 : 1,
      child: InkWell(
        onTap: () => _handleRecommendationTap(recommendation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recommendation.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            recommendation.priority.toString().split('.').last.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recommendation.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRecommendationIcon(RecommendationType type) {
    switch (type) {
      case RecommendationType.meditation:
        return Icons.self_improvement;
      case RecommendationType.journaling:
        return Icons.book;
      case RecommendationType.breathing:
        return Icons.air;
      case RecommendationType.therapy:
        return Icons.medical_services;
      case RecommendationType.wellness:
        return Icons.spa;
    }
  }

  Color _getRecommendationColor(RecommendationType type) {
    switch (type) {
      case RecommendationType.meditation:
        return Colors.purple;
      case RecommendationType.journaling:
        return Colors.orange;
      case RecommendationType.breathing:
        return Colors.blue;
      case RecommendationType.therapy:
        return Colors.green;
      case RecommendationType.wellness:
        return Colors.teal;
    }
  }

  Color _getPriorityColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.high:
        return Colors.red;
      case RecommendationPriority.medium:
        return Colors.orange;
      case RecommendationPriority.low:
        return Colors.green;
    }
  }

  void _handleRecommendationTap(Recommendation recommendation) {
    switch (recommendation.type) {
      case RecommendationType.journaling:
        Navigator.push(
          context,
          createAnimatedRoute(const JournalScreen()),
        );
        break;
      case RecommendationType.wellness:
      case RecommendationType.meditation:
      case RecommendationType.breathing:
        Navigator.push(
          context,
          createAnimatedRoute(const WellnessScreen()),
        );
        break;
      case RecommendationType.therapy:
        Navigator.push(
          context,
          createAnimatedRoute(const TherapistMatchingScreen()),
        );
        break;
    }
  }

  Future<void> _loadMoodHistory() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
    final userNodePath = authService.getCurrentUserNodePath();
    final currentUser = authService.currentUser;
    
    if (userNodePath == null || currentUser == null) return;

    try {
      final username = currentUser.name.toLowerCase().replaceAll(' ', '_');
      final moodChecksData = await dbService.readList('$userNodePath/$username/mood_checks');
      
      setState(() {
        _moodChecks = moodChecksData;
      });
    } catch (e) {
      // Error loading mood checks
    }
  }

  Widget _buildMoodCalendarView() {
    final moodColors = {
      'happy': Colors.pink[300]!,
      'sad': Colors.pink[400]!,
      'anxious': Colors.pink[500]!,
      'stressed': Colors.pink[600]!,
      'angry': Colors.pink[700]!,
      'neutral': Colors.pink[200]!,
      'depressed': Colors.pink[800]!,
      'overwhelmed': Colors.pink[900]!,
    };

    // Create a map of dates to mood checks
    final Map<DateTime, List<Map<String, dynamic>>> moodChecksByDate = {};
    for (var check in _moodChecks) {
      if (check['date'] != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(check['date'] as int);
        final dateKey = DateTime(date.year, date.month, date.day);
        moodChecksByDate.putIfAbsent(dateKey, () => []).add(check);
      }
    }

    // Get mood check for selected day
    Map<String, dynamic>? selectedDayMoodCheck;
    if (_selectedDay != null) {
      final selectedDate = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
      final checks = moodChecksByDate[selectedDate];
      if (checks != null && checks.isNotEmpty) {
        selectedDayMoodCheck = checks.first;
      }
    }

    return Column(
      children: [
        // Calendar Widget
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime(2020),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            eventLoader: (day) {
              final date = DateTime(day.year, day.month, day.day);
              return moodChecksByDate[date] ?? [];
            },
            onDaySelected: (selectedDay, focusedDay) {
              if (!isSameDay(_selectedDay, selectedDay)) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              }
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              todayDecoration: BoxDecoration(
                color: Colors.pink[200],
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.pink[600],
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Colors.pink[400],
                shape: BoxShape.circle,
              ),
              markersMaxCount: 1,
              markerSize: 6,
              weekendTextStyle: TextStyle(color: Colors.pink[700]),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: Colors.pink[100],
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: TextStyle(color: Colors.pink[900]),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.pink[700]),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.pink[700]),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(color: Colors.pink[700], fontWeight: FontWeight.bold),
              weekendStyle: TextStyle(color: Colors.pink[600], fontWeight: FontWeight.bold),
            ),
            calendarBuilders: CalendarBuilders<Map<String, dynamic>>(
              markerBuilder: (context, date, List<Map<String, dynamic>>? events) {
                if (events != null && events.isNotEmpty) {
                  final check = events.first;
                  final mood = check['mood'] as String? ?? 'neutral';
                  final moodColor = moodColors[mood] ?? Colors.pink[400]!;
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: moodColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }
                return null;
              },
              todayBuilder: (context, date, focusedDay) {
                final isSelected = isSameDay(_selectedDay, date);
                final dateKey = DateTime(date.year, date.month, date.day);
                final checksForDate = moodChecksByDate[dateKey];
                final check = checksForDate != null && checksForDate.isNotEmpty ? checksForDate.first : null;
                final mood = check?['mood'] as String? ?? 'neutral';
                final moodColor = check != null ? (moodColors[mood] ?? Colors.pink[200]!) : Colors.pink[200]!;
                
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.pink[600] : moodColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.pink[600]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.pink[900],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
              selectedBuilder: (context, date, focusedDay) {
                final dateKey = DateTime(date.year, date.month, date.day);
                final checksForDate = moodChecksByDate[dateKey];
                final check = checksForDate != null && checksForDate.isNotEmpty ? checksForDate.first : null;
                final mood = check?['mood'] as String? ?? 'neutral';
                final moodColor = check != null ? (moodColors[mood] ?? Colors.pink[600]!) : Colors.pink[600]!;
                
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: moodColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.pink[900]!,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Selected Day Mood Check Details
        if (_selectedDay != null && selectedDayMoodCheck != null)
          Expanded(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mood Check - ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.pink[900],
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildMoodCheckDetailCard(selectedDayMoodCheck),
                  ],
                ),
              ),
            ),
          )
        else if (_selectedDay != null && selectedDayMoodCheck == null)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mood_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No mood check for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMoodCheckDetailCard(Map<String, dynamic> moodCheck) {
    final mood = moodCheck['mood'] as String? ?? 'neutral';
    final moodScore = (moodCheck['moodScore'] as num?)?.toDouble() ?? 0.0;
    final intensity = (moodCheck['moodIntensity'] as num?)?.toDouble() ?? 0.0;
    final emotions = (moodCheck['selectedEmotions'] as List<dynamic>?)?.cast<String>() ?? [];
    final description = moodCheck['description'] as String? ?? '';

    final moodColors = {
      'happy': Colors.pink[300]!,
      'sad': Colors.pink[400]!,
      'anxious': Colors.pink[500]!,
      'stressed': Colors.pink[600]!,
      'angry': Colors.pink[700]!,
      'neutral': Colors.pink[200]!,
      'depressed': Colors.pink[800]!,
      'overwhelmed': Colors.pink[900]!,
    };

    final moodColor = moodColors[mood] ?? Colors.pink[400]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: moodColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: moodColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: moodColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  mood.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Score: ${(moodScore * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.pink[900],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Intensity: ${intensity.toInt()}/10',
                style: TextStyle(
                  color: Colors.pink[700],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (emotions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: emotions.map((emotion) {
                return Chip(
                  label: Text(emotion),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: Colors.pink[100],
                  labelStyle: TextStyle(color: Colors.pink[900], fontSize: 11),
                );
              }).toList(),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                color: Colors.pink[900],
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
