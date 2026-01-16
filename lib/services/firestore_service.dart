// NOTE: This service is for Cloud Firestore, but the project uses Realtime Database.
// This file is kept for reference but is not actively used.
// Use RealtimeDatabaseService instead.

/*
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message_model.dart';
import '../models/journal_entry_model.dart';
import '../models/appointment_model.dart';
import '../models/wellness_resource_model.dart';
import '../models/therapist_model.dart';
import '../models/emotion_analysis_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Messages
  Stream<List<MessageModel>> getMessages(String userId) {
    return _firestore
        .collection('messages')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> saveMessage(MessageModel message) async {
    await _firestore.collection('messages').doc(message.id).set(message.toMap());
  }

  // Journal Entries
  Stream<List<JournalEntryModel>> getJournalEntries(String userId) {
    return _firestore
        .collection('journal_entries')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => JournalEntryModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> saveJournalEntry(JournalEntryModel entry) async {
    await _firestore.collection('journal_entries').doc(entry.id).set(entry.toMap());
  }

  Future<void> deleteJournalEntry(String entryId) async {
    await _firestore.collection('journal_entries').doc(entryId).delete();
  }

  // Appointments
  Stream<List<AppointmentModel>> getUserAppointments(String userId) {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Stream<List<AppointmentModel>> getTherapistAppointments(String therapistId) {
    return _firestore
        .collection('appointments')
        .where('therapistId', isEqualTo: therapistId)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppointmentModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> saveAppointment(AppointmentModel appointment) async {
    await _firestore.collection('appointments').doc(appointment.id).set(appointment.toMap());
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    await _firestore.collection('appointments').doc(appointment.id).update(appointment.toMap());
  }

  // Therapists
  Stream<List<TherapistModel>> getTherapists({List<String>? specializations}) {
    var query = _firestore
        .collection('therapists')
        .where('isVerified', isEqualTo: true);
    
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => TherapistModel.fromMap({...doc.data(), 'id': doc.id}))
        .toList());
  }

  Future<TherapistModel?> getTherapist(String therapistId) async {
    final doc = await _firestore.collection('therapists').doc(therapistId).get();
    if (doc.exists) {
      return TherapistModel.fromMap({...doc.data()!, 'id': doc.id});
    }
    return null;
  }

  Future<void> saveTherapist(TherapistModel therapist) async {
    await _firestore.collection('therapists').doc(therapist.id).set(therapist.toMap());
  }

  // Wellness Resources
  Stream<List<WellnessResourceModel>> getWellnessResources({ResourceType? type}) {
    var query = _firestore
        .collection('wellness_resources')
        .where('isApproved', isEqualTo: true);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type.toString());
    }
    
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WellnessResourceModel.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> saveWellnessResource(WellnessResourceModel resource) async {
    await _firestore.collection('wellness_resources').doc(resource.id).set(resource.toMap());
  }

  Future<void> approveWellnessResource(String resourceId, String adminId) async {
    await _firestore.collection('wellness_resources').doc(resourceId).update({
      'isApproved': true,
      'approvedBy': adminId,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Emotion Analysis
  Future<void> saveEmotionAnalysis(EmotionAnalysisModel analysis) async {
    await _firestore
        .collection('emotion_analysis')
        .doc('${analysis.userId}_${analysis.timestamp.millisecondsSinceEpoch}')
        .set(analysis.toMap());
  }

  Stream<List<EmotionAnalysisModel>> getEmotionAnalysisHistory(String userId, {int limit = 30}) {
    return _firestore
        .collection('emotion_analysis')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => EmotionAnalysisModel.fromMap(doc.data()))
            .toList());
  }
}
*/
