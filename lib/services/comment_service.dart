import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_service.dart';
import 'package:eventful_app/services/score_service.dart';

class CommentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendComment({
    required String eventId,
    required String text,
    String? replyToId,
    String? editingCommentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final String userName = userData?['username'] ?? userData?['name'] ?? 'Anonim';

    if (editingCommentId != null) {
      await _db.collection('events').doc(eventId).collection('comments').doc(editingCommentId).update({
        'text': text,
        'isEdited': true,
        'editTimestamp': FieldValue.serverTimestamp(),
      });
    } else {
      String? replyToName;
      String? replyToUserId;

      if (replyToId != null) {
        final replyToDoc = await _db.collection('events').doc(eventId).collection('comments').doc(replyToId).get();
        if (replyToDoc.exists) {
          replyToName = replyToDoc.data()?['userName'];
          replyToUserId = replyToDoc.data()?['userId'];
        }
      }

      await _db.collection('events').doc(eventId).collection('comments').add({
        'text': text,
        'userId': user.uid,
        'userName': userName,
        'userImage': userData?['profileImage'],
        'timestamp': FieldValue.serverTimestamp(),
        'replyToId': replyToId,
        'replyToName': replyToName,
      });

      if (replyToUserId != null && replyToUserId != user.uid) {
        final eventDoc = await _db.collection('events').doc(eventId).get();
        final eventTitle = eventDoc.data()?['title'] ?? 'Etkinlik';

        await NotificationService.sendNotification(
          recipientId: replyToUserId,
          title: 'Yeni Yanıt: $eventTitle',
          body: '$userName mesajına cevap verdi: $text',
          data: {
            'type': 'chat_reply',
            'eventId': eventId,
          },
        );
      }

      await _processMentions(eventId, text, userName, user.uid);
      
      // Auto badge check for 'chatter'
      await ScoreService.instance.checkAndAwardBadges(user.uid);
    }
  }

  Future<void> _processMentions(String eventId, String text, String senderName, String senderUid) async {
    final eventDoc = await _db.collection('events').doc(eventId).get();
    if (!eventDoc.exists) return;

    if (text.contains('@herkes')) {
      final String creatorId = eventDoc.data()?['creatorId'] ?? '';
      final userDoc = await _db.collection('users').doc(senderUid).get();
      final String role = userDoc.data()?['role'] ?? 'user';
      
      final bool isAuthorized = senderUid == creatorId || role == 'admin' || role == 'mod';

      if (isAuthorized) {
        final List participants = eventDoc.data()?['participants'] ?? [];
        for (final String uid in participants) {
          if (uid != senderUid) {
            await NotificationService.sendNotification(
              recipientId: uid,
              title: 'Etkinlik Sohbeti',
              body: '$senderName @herkesi etiketledi: $text',
              data: {
                'type': 'chat_mention_all',
                'eventId': eventId,
              },
            );
          }
        }
      }
      return;
    }

    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final Iterable<RegExpMatch> matches = mentionRegex.allMatches(text);
    for (final match in matches) {
      final String mentionedUsername = match.group(1)!;
      var userDocs = await _db.collection('users').where('username', isEqualTo: mentionedUsername).get();
      if (userDocs.docs.isEmpty) {
        userDocs = await _db.collection('users').where('name', isEqualTo: mentionedUsername).get();
      }
      
      for (final doc in userDocs.docs) {
        if (doc.id != senderUid) {
          await NotificationService.sendNotification(
            recipientId: doc.id,
            title: 'Senden Bahsedildi',
            body: '$senderName seni etiketledi: $text',
            data: {
              'type': 'chat_mention',
              'eventId': eventId,
            },
          );
        }
      }
    }
  }

  Future<void> toggleReaction({
    required String eventId,
    required String commentId,
    required String emoji,
    required Map<String, dynamic> allReactions,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final WriteBatch batch = _db.batch();
    final DocumentReference commentRef = _db.collection('events').doc(eventId).collection('comments').doc(commentId);

    String? existingEmoji;
    allReactions.forEach((key, value) {
      if ((value as List).contains(uid)) {
        existingEmoji = key;
      }
    });

    if (existingEmoji == emoji) {
      batch.update(commentRef, {
        'reactions.$emoji': FieldValue.arrayRemove([uid])
      });
    } else {
      if (existingEmoji != null) {
        batch.update(commentRef, {
          'reactions.$existingEmoji': FieldValue.arrayRemove([uid])
        });
      }
      batch.update(commentRef, {
        'reactions.$emoji': FieldValue.arrayUnion([uid])
      });
    }

    await batch.commit();
  }

  Future<void> reportComment({
    required String eventId,
    required String commentId,
    required String commentText,
    required String commentUserId,
    required String commentUserName,
    required String reason,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final myDoc = await _db.collection('users').doc(user.uid).get();
    final myName = myDoc.data()?['name'] ?? 'Kullanıcı';

    await _db.collection('reports').add({
      'category': 'event_comment',
      'targetId': commentId,
      'targetContent': commentText,
      'targetUserId': commentUserId,
      'targetUserName': commentUserName,
      'reason': reason,
      'reporterId': user.uid,
      'reporterName': myName,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
      'eventId': eventId,
    });
  }

  Future<void> deleteComment(String eventId, String commentId, {String? pinnedCommentId}) async {
    final WriteBatch batch = _db.batch();
    batch.delete(_db.collection('events').doc(eventId).collection('comments').doc(commentId));
    
    if (pinnedCommentId == commentId) {
      batch.update(_db.collection('events').doc(eventId), {'pinnedCommentId': null});
    }
    
    await batch.commit();
  }

  Future<void> pinComment(String eventId, String? commentId) async {
    await _db.collection('events').doc(eventId).update({'pinnedCommentId': commentId});
  }
}
