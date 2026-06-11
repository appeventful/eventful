import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import '../utils/constants.dart';

class ScoreService {
  final FirebaseFirestore _db;
  ScoreService({FirebaseFirestore? firestore}) : _db = firestore ?? FirebaseFirestore.instance;
  static final ScoreService instance = ScoreService();

  // Score Types and Values
  static const int dailyLogin = 3;
  static const int createEvent = 10;
  static const int joinEvent = 5;
  static const int photoShareReward = 5;
  static const int instagramFollowReward = 50;
  static const int penaltyCreatorAbsent = -25;
  static const int penaltyCreatorNoAttendance = -100;
  static const int penaltyJoinerAbsent = -15;

  // Update only last login timestamp
  Future<void> updateLastActive(String userId) async {
    await _db.collection('users').doc(userId).update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
  }

  // Add/Subtract Points and Save to History
  Future<void> updateScore({
    required String userId,
    required int amount,
    required String reason,
    String? relatedId,
    bool updateLastLogin = false,
  }) async {
    final userRef = _db.collection('users').doc(userId);

    bool alreadyProcessed = await _db.runTransaction<bool>((transaction) async {
      if (relatedId != null) {
        final sanitizedReason = reason.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final historyId = "${relatedId}_$sanitizedReason";
        final historyRef = userRef.collection('pointHistory').doc(historyId);
        final historyDoc = await transaction.get(historyRef);
        
        if (historyDoc.exists) {
          return true;
        }

        transaction.update(userRef, {
          'points': FieldValue.increment(amount),
          if (updateLastLogin) 'lastLogin': FieldValue.serverTimestamp(),
        });

        transaction.set(historyRef, {
          'amount': amount,
          'reason': reason,
          'relatedId': relatedId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return false;
      } else {
        transaction.update(userRef, {
          'points': FieldValue.increment(amount),
          if (updateLastLogin) 'lastLogin': FieldValue.serverTimestamp(),
        });

        final historyRef = userRef.collection('pointHistory').doc();
        transaction.set(historyRef, {
          'amount': amount,
          'reason': reason,
          'relatedId': relatedId,
          'timestamp': FieldValue.serverTimestamp(),
        });
        return false;
      }
    });

    if (alreadyProcessed) return;

    await NotificationService.sendNotification(
      recipientId: userId,
      title: amount > 0 ? 'Tebrikler, Puan Kazandın! ✨' : 'Eyvah, Puan Kaybettin! 📉',
      body: '$reason: ${amount > 0 ? "+" : ""}$amount puan cüzdanına yansıdı.',
      data: {'type': 'point_change'},
    );

    if (amount < 0) {
      await _checkAndApplyRestriction(userId);
    } else {
      await checkAndAwardBadges(userId);
    }
  }

  // Automatic Badge Check
  Future<void> checkAndAwardBadges(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final List<String> currentBadges = List<String>.from(data['badges'] ?? []);
    final int points = (data['points'] ?? 0).toInt();
    
    List<String> newBadges = [];

    if (points >= 500 && !currentBadges.contains('loyal_user')) {
      newBadges.add('loyal_user');
    }

    final eventsQuery = await _db.collection('events')
        .where('creatorId', isEqualTo: userId)
        .where('isApproved', isEqualTo: true)
        .count().get();
    
    if ((eventsQuery.count ?? 0) >= 10 && !currentBadges.contains('event_master')) {
      newBadges.add('event_master');
    }

    if (data['isFounder'] == true && !currentBadges.contains('founder')) {
      newBadges.add('founder');
    }

    if (data['isProfileImageApproved'] == true && !currentBadges.contains('verified')) {
      newBadges.add('verified');
    }

    if (!currentBadges.contains('explorer')) {
      final attendedSnapshot = await _db.collection('events')
          .where('attendanceYes', arrayContains: userId)
          .get();
      
      final Set<String> categories = {};
      for (var doc in attendedSnapshot.docs) {
        final cat = doc.data()['category'];
        if (cat != null) categories.add(cat.toString());
      }
      
      if (categories.length >= 5) {
        newBadges.add('explorer');
      }
    }

    if (!currentBadges.contains('photographer')) {
      final photosSnapshot = await _db.collectionGroup('photos')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'approved')
          .count().get();
      
      if ((photosSnapshot.count ?? 0) >= 10) {
        newBadges.add('photographer');
      }
    }

    if (!currentBadges.contains('chatter')) {
      final commentsSnapshot = await _db.collectionGroup('comments')
          .where('userId', isEqualTo: userId)
          .count().get();
      
      if ((commentsSnapshot.count ?? 0) >= 50) {
        newBadges.add('chatter');
      }
    }

    if (!currentBadges.contains('helper')) {
      double trust = (data['trustScore'] ?? 0.0).toDouble();
      int ratings = (data['ratingCount'] ?? 0).toInt();
      if (trust >= 4.5 && ratings >= 5) {
        newBadges.add('helper');
      }
    }

    if (!currentBadges.contains('top_organizer')) {
      final eventsQuery = await _db.collection('events')
          .where('creatorId', isEqualTo: userId)
          .where('isApproved', isEqualTo: true)
          .count().get();
      
      if ((eventsQuery.count ?? 0) >= 20) {
        newBadges.add('top_organizer');
      }
    }

    if (newBadges.isNotEmpty) {
      await _db.collection('users').doc(userId).update({
        'badges': FieldValue.arrayUnion(newBadges),
      });

      for (String badgeId in newBadges) {
        final badgeInfo = availableBadges.firstWhere((b) => b['id'] == badgeId, orElse: () => {'name': 'Yeni'});
        await NotificationService.sendNotification(
          recipientId: userId,
          title: 'Yeni Rozet Kazandın! 🏆',
          body: 'Tebrikler, "${badgeInfo['name']}" rozeti profilinde parlıyor!',
          data: {'type': 'badge_earned', 'badgeId': badgeId},
        );
      }
    }
  }

  Future<void> _checkAndApplyRestriction(String userId) async {
    bool exceeded = await hasExceededAbsenceLimit(userId);
    if (exceeded) {
      final userDoc = await _db.collection('users').doc(userId).get();
      final currentRestricted = (userDoc.data() as Map<String, dynamic>?)?['isRestricted'] ?? false;
      
      if (!currentRestricted) {
        await _db.collection('users').doc(userId).update({'isRestricted': true});
        
        await NotificationService.sendNotification(
          recipientId: userId,
          title: 'Hesabın Kısıtlandı! ⚠️',
          body: 'Devamsızlık limitini aştığın için hesabın kısıtlandı. Yeniden aktif olmak için güven tazeleme sürecini tamamlamalısın.',
          data: {'type': 'status_change'},
        );
      }
    }
  }

  Future<void> checkDailyLogin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final dateId = "${now.year}${now.month}${now.day}"; 
    
    await updateScore(
      userId: user.uid,
      amount: dailyLogin,
      reason: 'Günlük Giriş Ödülü',
      relatedId: 'daily_login_$dateId',
      updateLastLogin: true,
    );
  }

  Future<int> getMonthlyAbsenceCount(String userId) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    final query = await _db.collection('users').doc(userId)
        .collection('pointHistory')
        .where('timestamp', isGreaterThanOrEqualTo: firstDayOfMonth)
        .get();

    int absenceCount = 0;
    for (var doc in query.docs) {
      final amount = doc.data()['amount'];
      if (amount == penaltyJoinerAbsent || amount == penaltyCreatorAbsent) absenceCount++;
    }
    return absenceCount;
  }

  Future<bool> hasExceededAbsenceLimit(String userId) async {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    final query = await _db.collection('users').doc(userId)
        .collection('pointHistory')
        .where('timestamp', isGreaterThanOrEqualTo: firstDayOfMonth)
        .get();

    int absenceCount = 0;
    for (var doc in query.docs) {
      final data = doc.data();
      final amount = data['amount'];
      if (amount == penaltyJoinerAbsent || amount == penaltyCreatorAbsent) {
        absenceCount++;
      }
    }
    return absenceCount >= 2;
  }

  Future<bool> needsReference(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    if (!userDoc.exists) return false;
    
    final userData = userDoc.data() as Map<String, dynamic>;
    return userData['isRestricted'] == true;
  }

  Future<bool> canCreateEvent(String userId) async {
    return !(await needsReference(userId));
  }

  Future<void> incrementReferenceParticipation(String userId) async {
    final userRef = _db.collection('users').doc(userId);
    
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(userRef);
      if (!doc.exists) return;
      
      final data = doc.data() as Map<String, dynamic>;
      int currentCount = ((data['referenceParticipationCount'] ?? 0) as num).toInt() + 1;
      
      Map<String, dynamic> updates = {
        'referenceParticipationCount': currentCount,
      };

      if (currentCount >= 5) {
        updates['isRestricted'] = false;
        updates['referenceParticipationCount'] = 0;
      }
      
      transaction.update(userRef, updates);
    });

    final finalDoc = await userRef.get();
    if (finalDoc.exists && finalDoc.data()?['isRestricted'] == false && finalDoc.data()?['referenceParticipationCount'] == 0) {
       await NotificationService.sendNotification(
        recipientId: userId,
        title: 'Kısıtlaman Kaldırıldı! 🎉',
        body: 'Tebrikler, güven tazeleme sürecini başarıyla tamamladın. Artık özgürce etkinlik oluşturabilirsin!',
        data: {'type': 'status_change'},
      );
    }
  }

  Future<String?> getReferrerId(String eventId, String userId) async {
    final eventDoc = await _db.collection('events').doc(eventId).get();
    if (!eventDoc.exists) return null;

    final List referrals = (eventDoc.data() as Map<String, dynamic>)['referrals'] ?? [];
    for (var ref in referrals) {
      if (ref['user'] == userId) {
        return ref['referrer'] as String?;
      }
    }
    return null;
  }

  Future<void> processAttendanceScores(String eventId, String userId, String status) async {
    final eventRef = _db.collection('events').doc(eventId);

    bool alreadyScored = await _db.runTransaction((transaction) async {
      final eventDoc = await transaction.get(eventRef);
      if (!eventDoc.exists) return true;
      final scoredUsers = List<String>.from(eventDoc.data()?['scoredUsers'] ?? []);
      if (scoredUsers.contains(userId)) return true;
      
      transaction.update(eventRef, {
        'scoredUsers': FieldValue.arrayUnion([userId])
      });
      return false;
    });

    if (alreadyScored) return;

    if (status == 'attendanceYes') {
      await updateScore(
        userId: userId,
        amount: joinEvent,
        reason: 'Etkinlik Katılım Ödülü',
        relatedId: 'attendance_${eventId}_$userId',
      );
    } else if (status == 'attendanceNo') {
      final eventDoc = await eventRef.get();
      final creatorId = eventDoc.data()?['creatorId'];
      int penalty = (userId == creatorId) ? penaltyCreatorAbsent : penaltyJoinerAbsent;
      String reason = (userId == creatorId) ? 'Düzenleyen Olarak Gelmeme Cezası' : 'Etkinliğe Gelmeme Cezası';
      
      await updateScore(
        userId: userId,
        amount: penalty,
        reason: reason,
        relatedId: 'attendance_${eventId}_$userId',
      );
    }
  }

  Future<void> checkOrganizerAttendanceDuty(String eventId) async {
    final eventDoc = await _db.collection('events').doc(eventId).get();
    if (!eventDoc.exists) return;

    final data = eventDoc.data()!;
    if (data['isAttendanceDutyChecked'] == true) return;

    final creatorId = data['creatorId'];
    if (creatorId == null) return;

    final List participants = data['participants'] ?? [];
    if (participants.length <= 1) return; 

    final List attended = data['attendanceYes'] ?? [];
    final List absent = data['attendanceNo'] ?? [];
    
    for (String uid in attended) {
      await processAttendanceScores(eventId, uid, 'attendanceYes');
    }
    for (String uid in absent) {
      await processAttendanceScores(eventId, uid, 'attendanceNo');
    }

    final int guestCount = participants.where((id) => id != creatorId).length;
    final int markedCount = (attended.where((id) => id != creatorId).length) + 
                             (absent.where((id) => id != creatorId).length);

    final dynamic eventDateData = data['eventDate'] ?? data['date'];
    DateTime eventDate;
    if (eventDateData is Timestamp) {
      eventDate = eventDateData.toDate();
    } else if (eventDateData is String) {
      eventDate = DateTime.tryParse(eventDateData) ?? DateTime.now();
    } else {
      eventDate = DateTime.now();
    }
    bool isOldEvent = DateTime.now().difference(eventDate).inHours > 6;
    bool allMarked = markedCount >= guestCount;

    if (isOldEvent || allMarked) {
      for (String uid in participants) {
        if (uid != creatorId && !attended.contains(uid) && !absent.contains(uid)) {
          await processAttendanceScores(eventId, uid, 'attendanceNo');
          await _db.collection('events').doc(eventId).update({
            'attendanceNo': FieldValue.arrayUnion([uid]),
          });
        }
      }

      if (guestCount > 0) {
        if (markedCount / guestCount < 0.8) {
          await updateScore(
            userId: creatorId,
            amount: penaltyCreatorNoAttendance,
            reason: 'Yoklama Almama Cezası (%80 Sınırı)',
            relatedId: eventId,
          );
        }
      }
      
      await _db.collection('events').doc(eventId).update({
        'isAttendanceDutyChecked': true,
        'isArchived': true,
      });
    } else if (DateTime.now().isAfter(eventDate) && !allMarked) {
      await NotificationService.sendNotification(
        recipientId: creatorId,
        title: 'Yoklama Hatırlatması ⏰',
        body: '"${data['title']}" etkinliği sona erdi. Puan cezası almamak için lütfen katılımcıları işaretle.',
        data: {
          'type': 'attendance_reminder',
          'eventId': eventId,
        },
      );
    }
  }

  Future<void> checkUserPendingDuties(String userId) async {
    try {
      final query = await _db.collection('events')
          .where('creatorId', isEqualTo: userId)
          .where('isAttendanceDutyChecked', isEqualTo: false)
          .limit(5)
          .get();

      for (var doc in query.docs) {
        await checkOrganizerAttendanceDuty(doc.id);
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint("Error checking pending duties: $e");
    }
  }
}
