import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/realtime_database_service.dart';
import '../models/review_model.dart';

// Helper to run within the app context if needed, or just visual verification
class ReviewDebugScreen extends StatefulWidget {
  const ReviewDebugScreen({super.key});

  @override
  State<ReviewDebugScreen> createState() => _ReviewDebugScreenState();
}

class _ReviewDebugScreenState extends State<ReviewDebugScreen> {
  String _log = '';

  void _logger(String message) {
    setState(() {
      _log += '$message\n';
    });
    debugPrint(message);
  }

  Future<void> _runTest() async {
    _logger('Starting Review Test...');
    final dbService = Provider.of<RealtimeDatabaseService>(
      context,
      listen: false,
    );

    // 1. Create a dummy review
    final therapistId = 'test_therapist_123';
    final reviewId = 'test_review_abc';
    final review = ReviewModel(
      id: reviewId,
      therapistId: therapistId,
      userId: 'test_user_456',
      userName: 'Test User',
      rating: 5.0,
      comment: 'Test Comment',
      createdAt: DateTime.now(),
    );

    try {
      // 2. Write Review
      _logger('Writing review to therapists/$therapistId/reviews/$reviewId');
      await dbService.writeData(
        'therapists/$therapistId/reviews/$reviewId',
        review.toMap(),
      );
      _logger('Write success!');

      // 3. Read Review List
      _logger('Reading reviews from therapists/$therapistId/reviews');
      final reviewsData = await dbService.readList(
        'therapists/$therapistId/reviews',
      );
      _logger('Read ${reviewsData.length} items.');

      if (reviewsData.isNotEmpty) {
        _logger('First item: ${reviewsData.first}');
        // 4. Parse Review
        final parsedReview = ReviewModel.fromMap(reviewsData.first);
        _logger('Parsed Review Comment: ${parsedReview.comment}');
      } else {
        _logger('ERROR: No reviews found!');
      }
    } catch (e) {
      _logger('EXCEPTION: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Debugger')),
      body: Column(
        children: [
          ElevatedButton(onPressed: _runTest, child: const Text('Run Test')),
          Expanded(child: SingleChildScrollView(child: Text(_log))),
        ],
      ),
    );
  }
}
