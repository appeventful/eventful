import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AdminLogService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logAction({
    required String actionType, // 'ban', 'unban', 'role_change', 'wipe_data', 'event_delete'
    required String targetId,
    required String targetName,
    String? reason,
    Map<String, dynamic>? extraData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Fetch admin details for the log
      final adminDoc = await _db.collection('users').doc(user.uid).get();
      final adminData = adminDoc.data();
      final String adminName = adminData?['name'] ?? adminData?['username'] ?? 'Bilinmeyen Admin';

      await _db.collection('admin_logs').add({
        'adminId': user.uid,
        'adminName': adminName,
        'actionType': actionType,
        'targetId': targetId,
        'targetName': targetName,
        'reason': reason ?? 'Neden belirtilmedi',
        'extraData': extraData ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Admin Log Hatası: $e");
    }
  }
}
