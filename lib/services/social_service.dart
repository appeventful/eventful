import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Planlanmış gönderi ekle
  Future<void> schedulePost({
    required String type, // 'event' or 'photo'
    required String targetId,
    required DateTime scheduleDate,
    required String platform, // 'instagram', 'twitter', etc.
    String? caption,
  }) async {
    try {
      await _db.collection('social_scheduler').add({
        'type': type,
        'targetId': targetId,
        'scheduledAt': Timestamp.fromDate(scheduleDate),
        'platform': platform,
        'caption': caption,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error scheduling post: $e");
      rethrow;
    }
  }

  // Planlanmış gönderileri getir
  Stream<QuerySnapshot> getScheduledPosts() {
    return _db
        .collection('social_scheduler')
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  // Gönderi durumunu güncelle
  Future<void> updatePostStatus(String postId, String status) async {
    try {
      await _db.collection('social_scheduler').doc(postId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error updating post status: $e");
      rethrow;
    }
  }

  // Haftalık Özet için Etkinlikleri Getir
  Future<List<Map<String, dynamic>>> getEventsForWeeklySummary() async {
    List<Map<String, dynamic>> tempEvents = [];
    final List<String> mandatoryCities = ['İstanbul', 'Ankara', 'İzmir'];
    final List<String> weekDays = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
    ];

    try {
      // 1. Gelecekteki onaylı tüm etkinlikleri çek (daha geniş bir havuz)
      var snapshot = await _db
          .collection('events')
          .where('eventDate', isGreaterThan: Timestamp.now())
          .where('isApproved', isEqualTo: true)
          .where('isArchived', isEqualTo: false)
          .orderBy('eventDate', descending: false)
          .limit(40)
          .get();

      List<Map<String, dynamic>> allEvents = snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // 2. Zorunlu şehirlerden birer tane seçmeye çalış
      for (String city in mandatoryCities) {
        int index = allEvents.indexWhere((e) => e['city'] == city);
        if (index != -1) {
          tempEvents.add(allEvents.removeAt(index));
        }
      }

      // 3. Kalan boşlukları tarih sırasına göre doldur
      while (tempEvents.length < 7 && allEvents.isNotEmpty) {
        tempEvents.add(allEvents.removeAt(0));
      }

      // 4. Günleri ve tarih aralığını ata (Her zaman 7 gün dön)
      DateTime now = DateTime.now();
      // Gelecek Pazartesi'yi bul
      DateTime startDate = now.add(Duration(days: 8 - now.weekday));
      // Eğer haftanın başındaysak (Pzt-Çar), bu haftanın özetini yapalım
      if (now.weekday <= 3) {
        startDate = now.subtract(Duration(days: now.weekday - 1));
      }
      
      List<Map<String, dynamic>> finalEvents = [];
      for (int i = 0; i < 7; i++) {
        Map<String, dynamic> dayData = (i < tempEvents.length) 
            ? Map<String, dynamic>.from(tempEvents[i]) 
            : {};
        
        dayData['weekDay'] = weekDays[i];
        DateTime dayDate = startDate.add(Duration(days: i));
        dayData['displayDate'] = DateFormat('dd.MM').format(dayDate);
        finalEvents.add(dayData);
      }

      return finalEvents;
    } catch (e) {
      debugPrint("Error fetching weekly summary events: $e");
      return [];
    }
  }

  // Günlük Ajanda için Etkinlikleri Getir
  Future<List<Map<String, dynamic>>> getEventsForDailyAgenda() async {
    try {
      DateTime now = DateTime.now();
      DateTime startOfDay = DateTime(now.year, now.month, now.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      var snapshot = await _db
          .collection('events')
          .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('eventDate', isLessThan: Timestamp.fromDate(endOfDay))
          .where('isApproved', isEqualTo: true)
          .where('isArchived', isEqualTo: false)
          .orderBy('eventDate', descending: false)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) {
        // Eğer bugün etkinlik yoksa, en yakın gelecekteki 5 etkinliği getir
        snapshot = await _db
            .collection('events')
            .where('eventDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('isApproved', isEqualTo: true)
            .where('isArchived', isEqualTo: false)
            .orderBy('eventDate', descending: false)
            .limit(5)
            .get();
      }

      return snapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Error fetching daily agenda events: $e");
      return [];
    }
  }

  // İstatistikleri Gerçek Verilerle Getir
  Future<Map<String, dynamic>> getSocialStats() async {
    try {
      final results = await Future.wait([
        // Instagram takipçi ödülünü alan gerçek kullanıcı sayısı
        _db.collection('users').where('isInstagramFollowed', isEqualTo: true).count().get(),
        // Toplam planlanmış/paylaşılmış işlem sayısı
        _db.collection('social_scheduler').count().get(),
        // Paylaşılan fotoğraflar (planlayıcı üzerinden)
        _db.collection('social_scheduler').where('type', isEqualTo: 'photo').count().get(),
        // Son 7 günde takip edenler (Büyüme oranı hesaplamak için)
        _db.collection('users')
            .where('isInstagramFollowed', isEqualTo: true)
            .where('updatedAt', isGreaterThan: DateTime.now().subtract(const Duration(days: 7)))
            .count().get(),
      ]);

      int followerCount = results[0].count ?? 0;
      int totalScheduled = results[1].count ?? 0;
      int photoScheduled = results[2].count ?? 0;
      int recentFollowers = results[3].count ?? 0;

      // Basit bir büyüme oranı hesaplama
      double growth = followerCount > 0 ? (recentFollowers / followerCount) * 100 : 0;

      return {
        'instagramFollowers': followerCount,
        'totalShares': totalScheduled,
        'photoShares': photoScheduled,
        'growthRate': '+%${growth.toStringAsFixed(1)}',
      };
    } catch (e) {
      debugPrint("Social Stats Error: $e");
      return {
        'instagramFollowers': 0,
        'totalShares': 0,
        'photoShares': 0,
        'growthRate': '%0',
      };
    }
  }
}
