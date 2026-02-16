import 'package:uuid/uuid.dart';
import 'realtime_database_service.dart';
import '../models/notification_model.dart';

class NotificationService {
  final RealtimeDatabaseService _dbService;

  NotificationService(this._dbService);

  // Send a notification to a specific user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    NotificationType type = NotificationType.info,
    Map<String, dynamic>? data,
  }) async {
    final notificationId = const Uuid().v4();
    final notification = NotificationModel(
      id: notificationId,
      userId: userId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      data: data,
    );

    await _dbService.writeData(
      'notifications/$userId/$notificationId',
      notification.toMap(),
    );
  }

  // Stream notifications for a specific user
  Stream<List<NotificationModel>> streamNotifications(String userId) {
    return _dbService.streamList('notifications/$userId').map((list) {
      final notifications = list
          .map((data) => NotificationModel.fromMap(data))
          .toList();
      // Sort by date descending (newest first)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    });
  }

  // Mark a notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _dbService.updateData('notifications/$userId/$notificationId', {
      'isRead': true,
    });
  }

  // Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _dbService.deleteData('notifications/$userId/$notificationId');
  }
}
