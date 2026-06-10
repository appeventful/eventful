import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String eventId;
  final String fromId;
  final String toId;
  final double score;
  final String? comment;
  final Timestamp timestamp;

  RatingModel({
    required this.id,
    required this.eventId,
    required this.fromId,
    required this.toId,
    required this.score,
    this.comment,
    required this.timestamp,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingModel(
      id: doc.id,
      eventId: data['eventId'] ?? '',
      fromId: data['fromId'] ?? '',
      toId: data['toId'] ?? '',
      score: (data['score'] ?? 0.0).toDouble(),
      comment: data['comment'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'fromId': fromId,
      'toId': toId,
      'score': score,
      'comment': comment,
      'timestamp': timestamp,
    };
  }
}
