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
import '../../../widgets/animated_background.dart';
import '../../../widgets/glass_container.dart';
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
    if (_selectedMood == null &&
        _selectedEmotions.isEmpty &&
        _descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one emotion or describe how you feel',
          ),
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
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
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

      final userId = currentUser.id;
      final today = DateTime.now();
      final dateKey = DateFormat('yyyy-MM-dd').format(today);

      // Check if mood check already exists for today
      try {
        final existingMoodChecks = await dbService.readList(
          '$userNodePath/$userId/mood_checks',
        );
        for (var checkData in existingMoodChecks) {
          try {
            if (checkData['date'] != null) {
              final checkDate = DateTime.fromMillisecondsSinceEpoch(
                checkData['date'] as int,
              );
              final checkDateKey = DateFormat('yyyy-MM-dd').format(checkDate);
              if (checkDateKey == dateKey) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You already have a mood check for today (${DateFormat('MMM dd, yyyy').format(today)}). Only one mood check per day is allowed.',
                      ),
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
        final existingEntries = await dbService.readList(
          '$userNodePath/$userId/journal_entries',
        );
        for (var entryData in existingEntries) {
          try {
            final existingEntry = JournalEntryModel.fromMap(entryData);
            final existingDateKey = DateFormat(
              'yyyy-MM-dd',
            ).format(existingEntry.date);
            if (existingDateKey == dateKey) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'You already have a journal entry for today (${DateFormat('MMM dd, yyyy').format(today)}). Only one entry per day is allowed.',
                    ),
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
      final journalData = await dbService.readList(
        '$userNodePath/$userId/journal_entries',
      );
      final journalHistory = journalData.take(5).toList();

      // Analyze with AI
      final analysis = await aiService.analyzeEmotions(
        combinedText,
        _currentUserId!,
        journalHistory,
      );

      // Determine mood from selection or AI
      String mood =
          _selectedMood?.toLowerCase().replaceAll(' ', '_') ??
          analysis.primaryEmotion.toLowerCase();

      // Calculate mood score from intensity and AI analysis
      final moodScore =
          (_moodIntensity / 10.0) * 0.5 + (analysis.overallScore * 0.5);

      final checkId = const Uuid().v4();

      // Save mood check details
      final moodCheckData = {
        'id': checkId,
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
        '$userNodePath/$userId/mood_checks/$checkId',
        moodCheckData,
      );

      // Save as journal entry (mood checks also create journal entries)
      // Use the SAME ID as mood check for easy linking/deletion
      final entry = JournalEntryModel(
        id: checkId,
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
        '$userNodePath/$userId/journal_entries/$checkId',
        entry.toMap(),
      );

      // Save mood analysis
      await dbService.pushData(
        '$userNodePath/$userId/mood_analyses',
        analysis.toMap(),
      );

      // Get personalized recommendations based on current mood
      final recommendationService = Provider.of<RecommendationService>(
        context,
        listen: false,
      );
      final recommendations = await recommendationService
          .getPersonalizedRecommendations(_currentUserId!);

      setState(() {
        _analysisResult = analysis;
        _recommendations = recommendations;
        _isAnalyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Mood check saved successfully for ${DateFormat('MMM dd, yyyy').format(today)}!',
            ),
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

  Future<void> _loadMoodHistory() async {
    if (_currentUserId == null) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      final moodChecksData = await dbService.readList(
        '$userNodePath/$_currentUserId/mood_checks',
      );

      setState(() {
        _moodChecks = moodChecksData;
      });
    } catch (e) {
      debugPrint('Error loading mood history: $e');
    }
  }

  Future<void> _deleteMoodCheck(String checkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Mood Check'),
        content: const Text(
          'Are you sure you want to delete this mood check? This will also remove the corresponding journal entry.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(
        context,
        listen: false,
      );
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) return;

      // Delete from mood_checks
      await dbService.deleteData(
        '$userNodePath/$_currentUserId/mood_checks/$checkId',
      );

      // Also try to delete from journal_entries (they share the same ID for new entries)
      await dbService.deleteData(
        '$userNodePath/$_currentUserId/journal_entries/$checkId',
      );

      _loadMoodHistory();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Mood check-in deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting mood check: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Mood Check-In',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.check_circle_outline : Icons.calendar_today,
              color: Colors.white,
            ),
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
              icon: const Icon(Icons.refresh, color: Colors.white),
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
      body: AnimatedBackground(
        imageUrl:
            'https://images.unsplash.com/photo-1518531933037-8845d583afa2?auto=format&fit=crop&q=80',
        child: _showCalendar
            ? _buildMoodCalendarView()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome Card
                    GlassContainer(
                      opacity: 0.6,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.mood,
                              size: 48,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'How are you feeling right now?',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Take a moment to check in with yourself',
                              style: TextStyle(
                                color: Colors.black54,
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
                    GlassContainer(
                      opacity: 0.6,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.sentiment_satisfied,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Overall Mood',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
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
                                    setState(
                                      () => _selectedMood = selected
                                          ? mood
                                          : null,
                                    );
                                  },
                                  selectedColor: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.2),
                                  checkmarkColor: Theme.of(
                                    context,
                                  ).primaryColor,
                                  backgroundColor: Colors.black.withOpacity(
                                    0.05,
                                  ),
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.transparent,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Mood Intensity Slider
                    GlassContainer(
                      opacity: 0.6,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.speed,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Intensity Level',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${_moodIntensity.toInt()}/10',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Theme.of(
                                  context,
                                ).primaryColor,
                                inactiveTrackColor: Colors.black12,
                                thumbColor: Theme.of(context).primaryColor,
                                overlayColor: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.1),
                                valueIndicatorColor: Theme.of(
                                  context,
                                ).primaryColor,
                                valueIndicatorTextStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              child: Slider(
                                value: _moodIntensity,
                                min: 1,
                                max: 10,
                                divisions: 9,
                                label: _moodIntensity.toInt().toString(),
                                onChanged: (value) {
                                  setState(() => _moodIntensity = value);
                                },
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Low',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'High',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Emotion Checkboxes
                    ..._emotionSuggestions.entries.map((entry) {
                      return GlassContainer(
                        margin: const EdgeInsets.only(bottom: 16),
                        opacity: 0.6,
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
                                        : Colors.blueGrey,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    entry.key,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.value.map((emotion) {
                                  final isSelected = _selectedEmotions.contains(
                                    emotion,
                                  );
                                  return FilterChip(
                                    label: Text(emotion),
                                    selected: isSelected,
                                    onSelected: (_) => _toggleEmotion(emotion),
                                    selectedColor: Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.2),
                                    checkmarkColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    backgroundColor: Colors.black.withOpacity(
                                      0.05,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.black87,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected
                                            ? Theme.of(context).primaryColor
                                            : Colors.transparent,
                                      ),
                                    ),
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
                    GlassContainer(
                      opacity: 0.6,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Describe Your Feelings',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Optional: Add more details about what you\'re experiencing',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _descriptionController,
                              maxLines: 5,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                hintText:
                                    'What\'s on your mind? What\'s causing these feelings?',
                                hintStyle: const TextStyle(
                                  color: Colors.black38,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: Colors.black12,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.black.withOpacity(0.05),
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
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isAnalyzing
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline),
                                  SizedBox(width: 12),
                                  Text(
                                    'Save Mood Check',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
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
      ),
    );
  }

  Widget _buildAnalysisResult(EmotionAnalysisModel analysis) {
    return GlassContainer(
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analysis Results',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...analysis.suggestedActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        action,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              value.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, double score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Row(
            children: [
              Text(
                (score * 100).toInt().toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const Text(
                '/100',
                style: TextStyle(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCard(String label, String risk) {
    Color riskColor;
    if (risk.toLowerCase() == 'high') {
      riskColor = Colors.redAccent;
    } else if (risk.toLowerCase() == 'medium') {
      riskColor = Colors.orangeAccent;
    } else {
      riskColor = Colors.greenAccent;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: riskColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Row(
            children: [
              Icon(
                risk.toLowerCase() == 'high'
                    ? Icons.warning
                    : risk.toLowerCase() == 'medium'
                    ? Icons.info
                    : Icons.check_circle,
                color: riskColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                risk.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: riskColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Recommendations Section
  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.recommend, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(
                'Recommended for You',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recommendations.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final recommendation = _recommendations[index];
            return _buildRecommendationCard(recommendation);
          },
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(Recommendation recommendation) {
    IconData icon;
    Color color;

    switch (recommendation.type) {
      case RecommendationType.meditation:
      case RecommendationType.breathing:
        icon = Icons.self_improvement;
        color = Colors.purpleAccent;
        break;
      case RecommendationType.journaling:
        icon = Icons.edit_note;
        color = Colors.blueAccent;
        break;
      case RecommendationType.therapy:
        icon = Icons.people;
        color = Colors.greenAccent;
        break;
      case RecommendationType.wellness:
        icon = Icons.spa;
        color = Colors.orangeAccent;
        break;
    }

    return GlassContainer(
      opacity: 0.6,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          recommendation.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              recommendation.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.black26,
        ),
        onTap: () {
          if (recommendation.type == RecommendationType.journaling) {
            Navigator.push(context, createAnimatedRoute(const JournalScreen()));
          } else if (recommendation.type == RecommendationType.therapy) {
            Navigator.push(
              context,
              createAnimatedRoute(const TherapistMatchingScreen()),
            );
          } else if (recommendation.type == RecommendationType.wellness ||
              recommendation.type == RecommendationType.meditation ||
              recommendation.type == RecommendationType.breathing) {
            Navigator.push(
              context,
              createAnimatedRoute(const WellnessScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildMoodCalendarView() {
    return Column(
      children: [
        GlassContainer(
          margin: const EdgeInsets.fromLTRB(16, 100, 16, 16),
          opacity: 0.6,
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
            calendarStyle: CalendarStyle(
              defaultTextStyle: const TextStyle(color: Colors.black87),
              weekendTextStyle: const TextStyle(color: Colors.black45),
              outsideTextStyle: const TextStyle(color: Colors.black12),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonTextStyle: const TextStyle(color: Colors.black87),
              formatButtonDecoration: BoxDecoration(
                border: const Border.fromBorderSide(
                  BorderSide(color: Colors.black26),
                ),
                borderRadius: const BorderRadius.all(Radius.circular(12.0)),
              ),
              titleTextStyle: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: Theme.of(context).primaryColor,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: Theme.of(context).primaryColor,
              ),
            ),
            eventLoader: (day) {
              // Check if we have mood check for this day
              final dateKey = DateFormat('yyyy-MM-dd').format(day);
              final hasCheck = _moodChecks.any((check) {
                if (check['date'] != null) {
                  final checkDate = DateTime.fromMillisecondsSinceEpoch(
                    check['date'] as int,
                  );
                  return DateFormat('yyyy-MM-dd').format(checkDate) == dateKey;
                }
                return false;
              });
              return hasCheck ? ['Check'] : [];
            },
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedDay != null) ...[
                  Text(
                    'Mood History for ${DateFormat('MMM dd, yyyy').format(_selectedDay!)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMoodCheckForDate(_selectedDay!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodCheckForDate(DateTime date) {
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final check = _moodChecks.firstWhere((check) {
      if (check['date'] != null) {
        final checkDate = DateTime.fromMillisecondsSinceEpoch(
          check['date'] as int,
        );
        return DateFormat('yyyy-MM-dd').format(checkDate) == dateKey;
      }
      return false;
    }, orElse: () => {});

    if (check.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No mood check recorded for this day',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return _buildMoodCheckDetailCard(check);
  }

  Widget _buildMoodCheckDetailCard(Map<String, dynamic> check) {
    final mood = check['mood'] as String? ?? 'neutral';
    final moodScore = check['moodScore'] as double? ?? 0.5;
    final description = check['description'] as String? ?? '';
    final emotions = (check['selectedEmotions'] as List?)?.cast<String>() ?? [];

    // Mood Colors & Icons
    final moodColors = {
      'happy': Colors.greenAccent,
      'sad': Colors.blueAccent,
      'anxious': Colors.orangeAccent,
      'stressed': Colors.redAccent,
      'angry': Colors.red,
      'neutral': Colors.grey,
      'depressed': Colors.purpleAccent,
      'overwhelmed': Colors.deepOrangeAccent,
      'excited': Colors.yellowAccent,
    };

    final moodIcons = {
      'happy': Icons.sentiment_very_satisfied,
      'sad': Icons.sentiment_dissatisfied,
      'anxious': Icons.sentiment_very_dissatisfied,
      'stressed': Icons.sentiment_dissatisfied,
      'angry': Icons.sentiment_very_dissatisfied,
      'neutral': Icons.sentiment_neutral,
      'depressed': Icons.sentiment_dissatisfied,
      'overwhelmed': Icons.sentiment_dissatisfied,
      'excited': Icons.sentiment_very_satisfied,
    };

    final color = moodColors[mood.toLowerCase()] ?? Colors.grey;
    final icon = moodIcons[mood.toLowerCase()] ?? Icons.sentiment_neutral;

    return GlassContainer(
      opacity: 0.6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mood.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'Score: ${(moodScore * 100).toInt()}%',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () => _deleteMoodCheck(check['id']),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.black12),
              const SizedBox(height: 16),
              Text(
                description,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
            if (emotions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emotions.map((emotion) {
                  return Chip(
                    label: Text(emotion, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Theme.of(
                      context,
                    ).primaryColor.withOpacity(0.1),
                    labelStyle: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
