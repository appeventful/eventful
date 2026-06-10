import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/feedback_model.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitFeedback(UserFeedback feedback) async {
    await _firestore.collection('feedbacks').add(feedback.toMap());
  }

  Stream<List<UserFeedback>> getUserFeedbacks(String userId) {
    return _firestore
        .collection('feedbacks')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserFeedback.fromFirestore(doc))
            .toList());
  }
}
