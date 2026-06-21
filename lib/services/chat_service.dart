import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/notification_service.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // İki kullanıcının daha önce bir etkinlikte beraber "GELDİ" olarak işaretlenip işaretlenmediğini kontrol eder
  Future<bool> haveMetBefore(String otherUserId) async {
    if (_currentUserId.isEmpty) return false;

    // 1. Mevcut kullanıcının katıldığı (attended) etkinlikleri bul
    final myEvents = await _db.collection('events')
        .where('attended', arrayContains: _currentUserId)
        .get();

    // 2. Bu etkinlikler arasında diğer kullanıcının da "attendanceYes" veya legacy "attended" listesinde olduğu bir tane var mı bak
    for (var doc in myEvents.docs) {
      List attendedList = doc.data()['attendanceYes'] ?? doc.data()['attended'] ?? [];
      if (attendedList.contains(otherUserId)) {
        return true;
      }
    }

    // 3. Yeni alan adıyla da kontrol et
    final myEventsNew = await _db.collection('events')
        .where('attendanceYes', arrayContains: _currentUserId)
        .get();

    for (var doc in myEventsNew.docs) {
      List attendedList = doc.data()['attendanceYes'] ?? doc.data()['attended'] ?? [];
      if (attendedList.contains(otherUserId)) {
        return true;
      }
    }

    return false;
  }

  // Sohbet durumunu kontrol et veya yeni bir sohbet başlat
  Future<String> getOrCreateChat(String otherUserId) async {
    if (_currentUserId.isEmpty) throw Exception("Oturum açılmamış.");

    // Target user check
    final targetDoc = await _db.collection('users').doc(otherUserId).get();
    if (!targetDoc.exists) throw Exception("Kullanıcı bulunamadı.");
    final targetData = targetDoc.data() as Map<String, dynamic>;
    if (targetData['isFrozen'] == true) throw Exception("Bu kullanıcı hesabı dondurulmuştur.");
    if (targetData['isDeleted'] == true) throw Exception("Bu kullanıcı artık mevcut değil.");

    List<String> ids = [_currentUserId, otherUserId];
    ids.sort();
    String chatId = ids.join('_');

    final chatDoc = await _db.collection('chats').doc(chatId).get();

    if (!chatDoc.exists) {
      // Arkadaşlık kontrolü
      final myDoc = await _db.collection('users').doc(_currentUserId).get();
      final myFriends = List<String>.from(myDoc.data()?['friends'] ?? []);
      bool isFriend = myFriends.contains(otherUserId);

      // Daha önce buluştular mı?
      bool metBefore = await haveMetBefore(otherUserId);

      await _db.collection('chats').doc(chatId).set({
        'users': ids,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'status': (isFriend || metBefore) ? 'accepted' : 'pending',
        'initiatedBy': _currentUserId, // İsteği başlatan
      });
    } else {
      // Eğer zaten varsa ama durumu pending ise ve arkadaş olmuşlarsa veya beraber bir etkinliğe katılmışlarsa otomatik accepted yap
      String currentStatus = chatDoc.data()?['status'] ?? 'pending';
      if (currentStatus == 'pending') {
        final myDoc = await _db.collection('users').doc(_currentUserId).get();
        final myFriends = List<String>.from(myDoc.data()?['friends'] ?? []);
        bool isFriend = myFriends.contains(otherUserId);

        bool metBefore = await haveMetBefore(otherUserId);
        if (isFriend || metBefore) {
          await _db.collection('chats').doc(chatId).update({'status': 'accepted'});
        }
      }
    }

    return chatId;
  }

  // Mesaj gönder
  Future<void> sendMessage(String otherUserId, String text) async {
    if (_currentUserId.isEmpty) return;

    String chatId = await getOrCreateChat(otherUserId);
    
    final messageData = {
      'senderId': _currentUserId,
      'receiverId': otherUserId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    };

    await _db.collection('chats').doc(chatId).collection('messages').add(messageData);

    await _db.collection('chats').doc(chatId).update({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    // Bildirim gönder
    try {
      final senderDoc = await _db.collection('users').doc(_currentUserId).get();
      final senderName = senderDoc.data()?['name'] ?? senderDoc.data()?['username'] ?? 'Bir kullanıcı';
      
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      final String status = chatDoc.data()?['status'] ?? 'accepted';

      if (status == 'pending') {
        await NotificationService.sendNotification(
          recipientId: otherUserId,
          title: 'Yeni Mesaj İsteği 📩',
          body: '$senderName size bir mesaj isteği gönderdi.',
          data: {
            'type': 'chat_request',
            'senderId': _currentUserId,
            'chatId': chatId,
          },
        );
      } else {
        await NotificationService.sendNotification(
          recipientId: otherUserId,
          title: senderName,
          body: text,
          data: {
            'type': 'chat_message',
            'senderId': _currentUserId,
            'chatId': chatId,
          },
        );
      }
    } catch (e) {
      debugPrint("Bildirim gönderme hatası: $e");
    }
  }

  // Mesaj isteğini kabul et
  Future<void> acceptChatRequest(String chatId) async {
    await _db.collection('chats').doc(chatId).update({
      'status': 'accepted'
    });
  }

  // Sohbeti sil (Reddetme durumu için)
  Future<void> deleteChat(String chatId) async {
    // Mesajları temizle
    var messages = await _db.collection('chats').doc(chatId).collection('messages').get();
    for (var doc in messages.docs) {
      await doc.reference.delete();
    }
    // Sohbeti sil
    await _db.collection('chats').doc(chatId).delete();
  }
}
