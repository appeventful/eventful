import 'package:cloud_firestore/cloud_firestore.dart';

class SupportRequest {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String message;
  final Timestamp timestamp;
  final String status; // 'pending', 'replied'

  SupportRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.message,
    required this.timestamp,
    required this.status,
  });

  factory SupportRequest.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return SupportRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonim',
      userEmail: data['userEmail'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      status: data['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'message': message,
      'timestamp': timestamp,
      'status': status,
    };
  }
}
