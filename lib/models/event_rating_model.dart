import 'package:cloud_firestore/cloud_firestore.dart';

class EventRatingModel {
  final String id;
  final String eventId;
  final String userId;
  final double score;
  final String? comment;
  final Timestamp timestamp;

  EventRatingModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.score,
    this.comment,
    required this.timestamp,
  });

  factory EventRatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventRatingModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      userId: data['userId'] ?? '',
      score: (data['score'] ?? 0.0).toDouble(),
      comment: data['comment'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'score': score,
      'comment': comment,
      'timestamp': timestamp,
    };
  }
}
