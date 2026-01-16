import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/mock_firestore_service.dart';
import '../../services/auth_service.dart';
import '../../services/ai_service.dart';
import '../../models/emotion_analysis_model.dart';

class MoodAnalyticsScreen extends StatefulWidget {
  const MoodAnalyticsScreen({super.key});

  @override
  State<MoodAnalyticsScreen> createState() => _MoodAnalyticsScreenState();
}

class _MoodAnalyticsScreenState extends State<MoodAnalyticsScreen> {
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
        title: const Text('Mood Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMoodPredictionCard(),
            const SizedBox(height: 24),
            _buildEmotionTrendChart(),
            const SizedBox(height: 24),
            _buildRecentAnalysisList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodPredictionCard() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getMoodPrediction(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final prediction = snapshot.data ?? {};
        final predictedMood = prediction['predictedMood'] ?? 'neutral';
        final confidence = (prediction['confidence'] ?? 0.5) as double;
        final trend = prediction['trend'] ?? 'stable';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mood Prediction',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Mood',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            predictedMood.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Confidence',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(confidence * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      trend == 'improving'
                          ? Icons.trending_up
                          : trend == 'declining'
                              ? Icons.trending_down
                              : Icons.trending_flat,
                      color: trend == 'improving'
                          ? Colors.green
                          : trend == 'declining'
                              ? Colors.red
                              : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Trend: ${trend.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: trend == 'improving'
                            ? Colors.green
                            : trend == 'declining'
                                ? Colors.red
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmotionTrendChart() {
    return StreamBuilder<List<EmotionAnalysisModel>>(
      stream: Provider.of<MockFirestoreService>(context)
          .getEmotionAnalysisHistory(_currentUserId!, limit: 7),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No emotion data available yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
          );
        }

        final analyses = snapshot.data!.reversed.toList();
        final maxScore = 1.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Emotion Trend (Last 7 Days)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: analyses.asMap().entries.map((entry) {
                            return FlSpot(
                              entry.key.toDouble(),
                              entry.value.overallScore,
                            );
                          }).toList(),
                          isCurved: true,
                          color: Theme.of(context).colorScheme.primary,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                          ),
                        ),
                      ],
                      minY: 0,
                      maxY: maxScore,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentAnalysisList() {
    return StreamBuilder<List<EmotionAnalysisModel>>(
      stream: Provider.of<MockFirestoreService>(context)
          .getEmotionAnalysisHistory(_currentUserId!, limit: 5),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final analyses = snapshot.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...analyses.map((analysis) => _AnalysisItem(analysis: analysis)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getMoodPrediction() async {
    try {
      final aiService = Provider.of<AIService>(context, listen: false);
      final firestoreService = Provider.of<MockFirestoreService>(context, listen: false);

      // Get recent chat messages
      final messages = await firestoreService.getMessages(_currentUserId!).first;
      final chatHistory = messages.take(10).map((msg) => {
            'text': msg.content,
            'isUser': msg.senderId == _currentUserId,
          }).toList();

      // Get recent journal entries
      final journalEntries = await firestoreService
          .getJournalEntries(_currentUserId!)
          .first;
      final journalData = journalEntries.take(7).map((entry) => {
            'mood': entry.mood,
            'moodScore': entry.moodScore,
            'content': entry.content,
          }).toList();

      return await aiService.predictMood(
        _currentUserId!,
        chatHistory,
        journalData,
      );
    } catch (e) {
      return {};
    }
  }
}

class _AnalysisItem extends StatelessWidget {
  final EmotionAnalysisModel analysis;

  const _AnalysisItem({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final riskColors = {
      'low': Colors.green,
      'medium': Colors.orange,
      'high': Colors.red,
      'critical': Colors.purple,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.primaryEmotion.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Score: ${(analysis.overallScore * 100).toInt()}%',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: riskColors[analysis.riskLevel]?.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              analysis.riskLevel.toUpperCase(),
              style: TextStyle(
                color: riskColors[analysis.riskLevel],
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

