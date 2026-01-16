import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/ai_service.dart';
import '../../../services/realtime_database_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/emotion_analysis_model.dart';

class MoodTrackingScreen extends StatefulWidget {
  const MoodTrackingScreen({super.key});

  @override
  State<MoodTrackingScreen> createState() => _MoodTrackingScreenState();
}

class _MoodTrackingScreenState extends State<MoodTrackingScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isAnalyzing = false;
  EmotionAnalysisModel? _analysisResult;

  @override
  void dispose() {
    _textController.dispose();
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

  Future<void> _analyzeMood() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter how you\'re feeling')),
      );
      return;
    }

    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, loading user data...')),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      // Load journal history for context
      final authService = Provider.of<AuthService>(context, listen: false);
      final dbService = Provider.of<RealtimeDatabaseService>(context, listen: false);
      final userNodePath = authService.getCurrentUserNodePath();
      if (userNodePath == null) {
        setState(() => _isAnalyzing = false);
        return;
      }
      
      final journalData = await dbService.readList('$userNodePath/$_currentUserId/journal_entries');
      final journalHistory = journalData.take(5).toList();

      final aiService = Provider.of<AIService>(context, listen: false);
      final analysis = await aiService.analyzeEmotions(
        _textController.text.trim(),
        _currentUserId!,
        journalHistory,
      );

      setState(() {
        _analysisResult = analysis;
        _isAnalyzing = false;
      });

      // Save to database
      await dbService.pushData(
        '$userNodePath/$_currentUserId/mood_analyses',
        analysis.toMap(),
      );
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing mood: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Tracking'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How are you feeling?',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _textController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Describe your current mood, thoughts, or feelings...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _isAnalyzing ? null : _analyzeMood,
                      child: _isAnalyzing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Analyze Mood'),
                    ),
                  ],
                ),
              ),
            ),
            if (_analysisResult != null) ...[
              const SizedBox(height: 24),
              _buildAnalysisResult(_analysisResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResult(EmotionAnalysisModel analysis) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analysis Results',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildEmotionCard('Primary Emotion', analysis.primaryEmotion),
            const SizedBox(height: 12),
            _buildScoreCard('Overall Score', analysis.overallScore),
            const SizedBox(height: 12),
            _buildRiskCard('Risk Level', analysis.riskLevel),
            const SizedBox(height: 16),
            Text(
              'Suggested Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ...analysis.suggestedActions.map((action) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(action)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, double score) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${(score * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: score,
          backgroundColor: Colors.grey[300],
        ),
      ],
    );
  }

  Widget _buildRiskCard(String label, String value) {
    Color riskColor;
    switch (value.toLowerCase()) {
      case 'critical':
        riskColor = Colors.red;
        break;
      case 'high':
        riskColor = Colors.orange;
        break;
      case 'medium':
        riskColor = Colors.yellow;
        break;
      default:
        riskColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: riskColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: riskColor,
            ),
          ),
        ],
      ),
    );
  }
}

