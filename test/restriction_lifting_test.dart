import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:eventful_app/services/score_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ScoreService scoreService;

  setUp(() {
    db = FakeFirebaseFirestore();
    scoreService = ScoreService(firestore: db);
  });

  group('Restriction Lifting Logic E2E', () {
    test('isRestricted flips to false after 5 reference-based attendances', () async {
      const String userId = 'test_user';
      const String referrerId = 'referrer_user';
      
      // Initialize restricted user
      await db.collection('users').doc(userId).set({
        'isRestricted': true,
        'referenceParticipationCount': 0,
        'points': 0,
      });

      // Simulation of 5 events
      for (int i = 1; i <= 5; i++) {
        final eventId = 'event_$i';
        await db.collection('events').doc(eventId).set({
          'creatorId': 'creator_$i',
          'participants': [userId, 'creator_$i'],
          'referrals': [{'user': userId, 'referrer': referrerId}],
          'attendanceYes': [],
          'attendanceNo': [],
          'scoredUsers': [],
          'eventDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
        });

        // Mark as attended
        await scoreService.processAttendanceScores(eventId, userId, 'attendanceYes');
        
        final userDoc = await db.collection('users').doc(userId).get();
        final userData = userDoc.data()!;
        
        if (i < 5) {
          expect(userData['isRestricted'], true, reason: 'Should still be restricted at step $i');
          expect(userData['referenceParticipationCount'], i);
        } else {
          expect(userData['isRestricted'], false, reason: 'Restriction should be lifted at step 5');
          expect(userData['referenceParticipationCount'], 0);
        }
      }
    });

    test('Reference participation count does NOT increment if NOT used reference', () async {
      const String userId = 'test_user_no_ref';
      
      await db.collection('users').doc(userId).set({
        'isRestricted': true,
        'referenceParticipationCount': 0,
        'points': 0,
      });

      const String eventId = 'event_no_ref';
      await db.collection('events').doc(eventId).set({
        'creatorId': 'creator_1',
        'participants': [userId, 'creator_1'],
        'referrals': [], // No reference used
        'attendanceYes': [],
        'scoredUsers': [],
        'eventDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 1))),
      });

      await scoreService.processAttendanceScores(eventId, userId, 'attendanceYes');

      final userDoc = await db.collection('users').doc(userId).get();
      expect(userDoc.data()!['referenceParticipationCount'], 0);
      expect(userDoc.data()!['isRestricted'], true);
    });
  });
}
