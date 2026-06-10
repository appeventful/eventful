import 'package:cloud_firestore/cloud_firestore.dart';

class UserFeedback {
  final String? id;
  final String userId;
  final String userName;
  final String userEmail;
  final String type; // 'suggestion', 'complaint', 'bug', 'other'
  final String message;
  final String? city;
  final DateTime timestamp;
  final String status; // 'pending', 'reviewed', 'resolved'

  UserFeedback({
    this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.type,
    required this.message,
    this.city,
    required this.timestamp,
    this.status = 'pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'type': type,
      'message': message,
      'city': city,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
    };
  }

  factory UserFeedback.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserFeedback(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      type: data['type'] ?? 'other',
      message: data['message'] ?? '',
      city: data['city'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
    );
  }
}
