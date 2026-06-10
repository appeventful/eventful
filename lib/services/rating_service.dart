import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/rating_model.dart';
import '../models/event_rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- KULLANICI PUANLAMA (GÜVEN SKORU) ---
  Future<void> submitRating({
    required String eventId,
    required String fromId,
    required String toId,
    required double score,
    String? comment,
  }) async {
    final ratingRef = _firestore.collection('ratings').doc('${eventId}_${fromId}_$toId');
    
    final doc = await ratingRef.get();
    if (doc.exists) {
      throw Exception('Bu etkinlik için bu kullanıcıyı zaten oyladınız.');
    }

    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) throw Exception('Etkinlik bulunamadı.');

    // Etkinlik puanlama kısıtlaması kaldırıldı, kullanıcı puanlaması hala bitişe bağlı kalabilir 
    // veya o da kaldırılabilir. İsteğinize göre kullanıcı puanlamasını da serbest bırakıyorum.

    final rating = RatingModel(
      id: ratingRef.id,
      eventId: eventId,
      fromId: fromId,
      toId: toId,
      score: score,
      comment: comment,
      timestamp: Timestamp.now(),
    );

    await _firestore.runTransaction((transaction) async {
      final userRef = _firestore.collection('users').doc(toId);
      final userDoc = await transaction.get(userRef);
      
      transaction.set(ratingRef, rating.toMap());

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        double currentTrustScore = (data['trustScore'] ?? 0.0).toDouble();
        int currentRatingCount = (data['ratingCount'] ?? 0).toInt();

        double newTrustScore = ((currentTrustScore * currentRatingCount) + score) / (currentRatingCount + 1);
        
        transaction.update(userRef, {
          'trustScore': newTrustScore,
          'ratingCount': currentRatingCount + 1,
        });
      }
    });
  }

  // --- ETKİNLİK PUANLAMA ---
  Future<void> submitEventRating({
    required String eventId,
    required String userId,
    required double score,
    String? comment,
  }) async {
    final eventRatingRef = _firestore.collection('event_ratings').doc('${eventId}_$userId');
    
    final doc = await eventRatingRef.get();
    if (doc.exists) {
      throw Exception('Bu etkinliği zaten oyladınız.');
    }

    await _firestore.runTransaction((transaction) async {
      final eventRef = _firestore.collection('events').doc(eventId);
      final eventDoc = await transaction.get(eventRef);

      if (!eventDoc.exists) throw Exception('Etkinlik bulunamadı.');

      // 1. Puanı Kaydet
      transaction.set(eventRatingRef, {
        'eventId': eventId,
        'userId': userId,
        'score': score,
        'comment': comment,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Etkinlik Ortalamasını Güncelle
      var data = eventDoc.data() as Map<String, dynamic>;
      double currentAvg = (data['averageRating'] ?? 0.0).toDouble();
      int currentCount = (data['ratingCount'] ?? 0).toInt();

      double newAvg = ((currentAvg * currentCount) + score) / (currentCount + 1);
      int newCount = currentCount + 1;

      // Trending Score Calculation: 70% average rating + 30% participant count
      // We use joinedCount (or participants.length) for the calculation
      int participantCount = (data['participants'] as List? ?? []).length;
      double trendingScore = (newAvg * 0.7) + (participantCount * 0.3);

      transaction.update(eventRef, {
        'averageRating': newAvg,
        'ratingCount': newCount,
        'trendingScore': trendingScore,
      });
    });
  }

  Stream<List<RatingModel>> getUserRatings(String userId) {
    return _firestore
        .collection('ratings')
        .where('toId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => RatingModel.fromFirestore(doc)).toList());
  }

  Stream<List<EventRatingModel>> getEventRatings(String eventId) {
    return _firestore
        .collection('event_ratings')
        .where('eventId', isEqualTo: eventId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EventRatingModel.fromFirestore(doc)).toList());
  }
  
  Future<bool> hasRatedUser(String eventId, String fromId, String toId) async {
     final doc = await _firestore.collection('ratings').doc('${eventId}_${fromId}_$toId').get();
     return doc.exists;
  }

  Future<bool> hasRatedEvent(String eventId, String userId) async {
     final doc = await _firestore.collection('event_ratings').doc('${eventId}_$userId').get();
     return doc.exists;
  }

  Future<void> sendRatingNotifications(String eventId, String eventTitle) async {
    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) return;

    final data = eventDoc.data()!;
    if (data['isRatingNotified'] == true) return;

    final List attended = data['attendanceYes'] ?? data['attended'] ?? [];
    final String creatorId = data['creatorId'] ?? '';

    Set<String> notifyIds = {creatorId, ...attended.cast<String>()};
    
    WriteBatch batch = _firestore.batch();
    for (String uid in notifyIds) {
      if (uid.isEmpty) continue;
      
      DocumentReference notifRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'type': 'rating_prompt',
        'recipientId': uid,
        'title': 'Puanlama Zamanı! ⭐',
        'content': '"$eventTitle" etkinliği sona erdi. Hem etkinliği hem de katılımcıları puanlamayı unutma!',
        'eventId': eventId,
        'eventTitle': eventTitle,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    }

    batch.update(_firestore.collection('events').doc(eventId), {'isRatingNotified': true});
    await batch.commit();
  }
}
