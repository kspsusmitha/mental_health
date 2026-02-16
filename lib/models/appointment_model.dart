class AppointmentModel {
  final String id;
  final String userId;
  final String therapistId;
  final DateTime scheduledTime;
  final AppointmentStatus status;
  final AppointmentType type;
  final String? notes;
  final String? sessionLink;
  final DateTime? completedAt;
  final Map<String, dynamic>? feedback;

  AppointmentModel({
    required this.id,
    required this.userId,
    required this.therapistId,
    required this.scheduledTime,
    required this.status,
    required this.type,
    this.notes,
    this.sessionLink,
    this.completedAt,
    this.feedback,
  });

  factory AppointmentModel.fromMap(Map<String, dynamic> map) {
    return AppointmentModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      therapistId: map['therapistId'] ?? '',
      scheduledTime: map['scheduledTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduledTime'] as int)
          : DateTime.now(),
      status: AppointmentStatus.fromString(map['status'] ?? 'scheduled'),
      type: AppointmentType.fromString(map['type'] ?? 'text'),
      notes: map['notes'],
      sessionLink: map['sessionLink'],
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
      feedback: map['feedback'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'therapistId': therapistId,
      'scheduledTime': scheduledTime.millisecondsSinceEpoch,
      'status': status.toString(),
      'type': type.toString(),
      'notes': notes,
      'sessionLink': sessionLink,
      'completedAt': completedAt?.millisecondsSinceEpoch,
      'feedback': feedback,
    };
  }
}

enum AppointmentStatus {
  scheduled,
  completed,
  cancelled,
  rescheduled,
  pending,
  accepted,
  declined;

  static AppointmentStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'completed':
        return AppointmentStatus.completed;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      case 'rescheduled':
        return AppointmentStatus.rescheduled;
      case 'pending':
        return AppointmentStatus.pending;
      case 'accepted':
        return AppointmentStatus.accepted;
      case 'declined':
        return AppointmentStatus.declined;
      default:
        return AppointmentStatus.scheduled;
    }
  }

  @override
  String toString() {
    switch (this) {
      case AppointmentStatus.completed:
        return 'completed';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      case AppointmentStatus.rescheduled:
        return 'rescheduled';
      case AppointmentStatus.pending:
        return 'pending';
      case AppointmentStatus.accepted:
        return 'accepted';
      case AppointmentStatus.declined:
        return 'declined';
      default:
        return 'scheduled';
    }
  }
}

enum AppointmentType {
  text,
  audio,
  video;

  static AppointmentType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'audio':
        return AppointmentType.audio;
      case 'video':
        return AppointmentType.video;
      default:
        return AppointmentType.text;
    }
  }

  @override
  String toString() {
    switch (this) {
      case AppointmentType.audio:
        return 'audio';
      case AppointmentType.video:
        return 'video';
      default:
        return 'text';
    }
  }
}
