import 'dart:async';
import '../models/message_model.dart';
import '../models/journal_entry_model.dart';
import '../models/appointment_model.dart';
import '../models/wellness_resource_model.dart';
import '../models/therapist_model.dart';
import '../models/emotion_analysis_model.dart';

class MockFirestoreService {
  final List<MessageModel> _messages = [];
  final List<JournalEntryModel> _journalEntries = [];
  final List<AppointmentModel> _appointments = [];
  final List<TherapistModel> _therapists = [];
  final List<WellnessResourceModel> _wellnessResources = [];
  final List<EmotionAnalysisModel> _emotionAnalysis = [];

  // Messages
  Stream<List<MessageModel>> getMessages(String userId) {
    return Stream.value(
      _messages.where((m) => m.senderId == userId || m.receiverId == userId).toList(),
    );
  }

  Future<void> saveMessage(MessageModel message) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _messages.add(message);
  }

  // Journal Entries
  Stream<List<JournalEntryModel>> getJournalEntries(String userId) {
    return Stream.value(
      _journalEntries.where((e) => e.userId == userId).toList(),
    );
  }

  Future<void> saveJournalEntry(JournalEntryModel entry) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _journalEntries.add(entry);
  }

  Future<void> deleteJournalEntry(String entryId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _journalEntries.removeWhere((e) => e.id == entryId);
  }

  // Appointments
  Stream<List<AppointmentModel>> getUserAppointments(String userId) {
    return Stream.value(
      _appointments.where((a) => a.userId == userId).toList(),
    );
  }

  Stream<List<AppointmentModel>> getTherapistAppointments(String therapistId) {
    return Stream.value(
      _appointments.where((a) => a.therapistId == therapistId).toList(),
    );
  }

  Future<void> saveAppointment(AppointmentModel appointment) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _appointments.add(appointment);
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _appointments.indexWhere((a) => a.id == appointment.id);
    if (index != -1) {
      _appointments[index] = appointment;
    }
  }

  // Therapists
  Stream<List<TherapistModel>> getTherapists({List<String>? specializations}) {
    return Stream.value(_therapists);
  }

  Future<TherapistModel?> getTherapist(String therapistId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _therapists.firstWhere((t) => t.id == therapistId);
    } catch (e) {
      return null;
    }
  }

  Future<void> saveTherapist(TherapistModel therapist) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _therapists.add(therapist);
  }

  // Wellness Resources
  Stream<List<WellnessResourceModel>> getWellnessResources({ResourceType? type}) {
    final resources = type != null
        ? _wellnessResources.where((r) => r.type == type).toList()
        : _wellnessResources;
    return Stream.value(resources);
  }

  Future<void> saveWellnessResource(WellnessResourceModel resource) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _wellnessResources.add(resource);
  }

  Future<void> approveWellnessResource(String resourceId, String adminId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _wellnessResources.indexWhere((r) => r.id == resourceId);
    if (index != -1) {
      final resource = _wellnessResources[index];
      _wellnessResources[index] = WellnessResourceModel(
        id: resource.id,
        title: resource.title,
        description: resource.description,
        type: resource.type,
        url: resource.url,
        thumbnailUrl: resource.thumbnailUrl,
        duration: resource.duration,
        tags: resource.tags,
        isApproved: true,
        approvedBy: adminId,
        approvedAt: DateTime.now(),
        createdAt: resource.createdAt,
        views: resource.views,
        rating: resource.rating,
      );
    }
  }

  // Emotion Analysis
  Future<void> saveEmotionAnalysis(EmotionAnalysisModel analysis) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _emotionAnalysis.add(analysis);
  }

  Stream<List<EmotionAnalysisModel>> getEmotionAnalysisHistory(
    String userId, {
    int limit = 30,
  }) {
    return Stream.value(
      _emotionAnalysis
          .where((a) => a.userId == userId)
          .take(limit)
          .toList(),
    );
  }
}

