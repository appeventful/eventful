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

  group('checkOrganizerAttendanceDuty tests', () {
    test('Automatically marks unmarked participants as absent after 6 hours', () async {
      const String eventId = 'old_event';
      const String creatorId = 'creator_1';
      const String participantId = 'participant_1';
      const String referrerId = 'referrer_1';

      // 1. Setup event (7 hours ago)
      final sevenHoursAgo = DateTime.now().subtract(const Duration(hours: 7));
      await db.collection('events').doc(eventId).set({
        'creatorId': creatorId,
        'participants': [creatorId, participantId],
        'referrals': [{'user': participantId, 'referrer': referrerId}],
        'attendanceYes': [],
        'attendanceNo': [],
        'scoredUsers': [],
        'eventDate': Timestamp.fromDate(sevenHoursAgo),
        'isAttendanceDutyChecked': false,
      });

      // 2. Setup users
      await db.collection('users').doc(creatorId).set({'points': 1000});
      await db.collection('users').doc(participantId).set({'points': 100});
      await db.collection('users').doc(referrerId).set({'points': 500});

      // 3. Run check
      await scoreService.checkOrganizerAttendanceDuty(eventId);

      // 4. Verify results
      final eventDoc = await db.collection('events').doc(eventId).get();
      final eventData = eventDoc.data()!;
      expect(eventData['isAttendanceDutyChecked'], true);
      expect(eventData['isArchived'], true);
      expect(eventData['attendanceNo'], contains(participantId));

      // Check participant penalty (-15)
      final participantDoc = await db.collection('users').doc(participantId).get();
      expect(participantDoc.data()!['points'], 100 - 15);

      // Check referrer penalty (-15)
      final referrerDoc = await db.collection('users').doc(referrerId).get();
      expect(referrerDoc.data()!['points'], 500 - 15);

      // Check creator penalty for not taking attendance (-100)
      // Because markedCount was 0 and guestCount was 1 (0/1 < 0.8)
      final creatorDoc = await db.collection('users').doc(creatorId).get();
      expect(creatorDoc.data()!['points'], 1000 - 100);
    });

    test('Does NOT penalize creator if 80% of guests are marked', () async {
      const String eventId = 'recent_event';
      const String creatorId = 'creator_1';
      const String p1 = 'p1';
      const String p2 = 'p2';

      // 1. Setup event (7 hours ago)
      final sevenHoursAgo = DateTime.now().subtract(const Duration(hours: 7));
      await db.collection('events').doc(eventId).set({
        'creatorId': creatorId,
        'participants': [creatorId, p1, p2],
        'attendanceYes': [p1], // 1 out of 2 guests marked (50%)
        'attendanceNo': [],
        'scoredUsers': [],
        'eventDate': Timestamp.fromDate(sevenHoursAgo),
        'isAttendanceDutyChecked': false,
      });

      // Add p2 to attendanceNo manually to reach 100% (2/2)
      await db.collection('events').doc(eventId).update({
        'attendanceNo': [p2]
      });

      await db.collection('users').doc(creatorId).set({'points': 1000});
      await db.collection('users').doc(p1).set({'points': 100});
      await db.collection('users').doc(p2).set({'points': 100});

      // 3. Run check
      await scoreService.checkOrganizerAttendanceDuty(eventId);

      // 4. Verify creator NOT penalized -100 (but maybe other scores applied)
      final creatorDoc = await db.collection('users').doc(creatorId).get();
      // Creator shouldn't have the -100 penalty
      expect(creatorDoc.data()!['points'], 1000);
    });
   group('checkUserPendingDuties tests', () {
    test('Processes all pending duties for a user', () async {
      const String creatorId = 'creator_pending';
      
      // Event 1: Pending
      await db.collection('events').doc('ev1').set({
        'creatorId': creatorId,
        'participants': [creatorId, 'p1'],
        'eventDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 10))),
        'isAttendanceDutyChecked': false,
      });

      // Event 2: Already checked
      await db.collection('events').doc('ev2').set({
        'creatorId': creatorId,
        'participants': [creatorId, 'p2'],
        'eventDate': Timestamp.fromDate(DateTime.now().subtract(const Duration(hours: 10))),
        'isAttendanceDutyChecked': true,
      });

      await db.collection('users').doc(creatorId).set({'points': 1000});

      await scoreService.checkUserPendingDuties(creatorId);

      final ev1 = await db.collection('events').doc('ev1').get();
      expect(ev1.data()!['isAttendanceDutyChecked'], true);
      
      final creatorDoc = await db.collection('users').doc(creatorId).get();
      expect(creatorDoc.data()!['points'], 1000 - 100); // Penalty for ev1 only
    });
  });
});
}
