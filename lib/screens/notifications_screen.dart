import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../widgets/custom_avatar.dart';
import 'profile_screen.dart';
import 'event_detail_screen.dart';
import 'chat_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  void _markAllAsRead(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  void _deleteAllNotifications(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();

    for (var doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  void _showDeleteConfirmation(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bildirimleri Temizle'),
        content: const Text('Tüm bildirimleriniz kalıcı olarak silinecektir. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () {
              _deleteAllNotifications(uid);
              Navigator.pop(context);
            },
            child: const Text('Temizle', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
        actions: [
          if (uid != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
                
                final hasUnread = snapshot.data!.docs.any((doc) => (doc.data() as Map<String, dynamic>)['isRead'] == false);
                
                return Row(
                  children: [
                    if (hasUnread)
                      TextButton(
                        onPressed: () => _markAllAsRead(uid),
                        child: const Text('Tümünü Oku', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
                      tooltip: 'Bildirimleri Temizle',
                      onPressed: () => _showDeleteConfirmation(context, uid),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Lütfen giriş yapın.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Bildirimler yüklenirken bir hata oluştu: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Henüz bildirim yok.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isRead = data['isRead'] ?? false;

                    return Container(
                      color: isRead ? Colors.transparent : Colors.orange.withValues(alpha: 0.05),
                      child: ListTile(
                        leading: GestureDetector(
                          onTap: data['senderId'] != null 
                              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: data['senderId'])))
                              : null,
                          child: _getLeadingIcon(data['type']),
                        ),
                        title: data['title'] != null 
                          ? Text(data['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
                          : RichText(
                              text: TextSpan(
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14),
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: GestureDetector(
                                      onTap: data['senderId'] != null 
                                          ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: data['senderId'])))
                                          : null,
                                      child: StreamBuilder<DocumentSnapshot>(
                                        stream: FirebaseFirestore.instance.collection('users').doc(data['senderId']).snapshots(),
                                        builder: (context, userSnap) {
                                          if (!userSnap.hasData) return Text(data['senderName'] ?? 'Birisi');
                                          final user = UserModel.fromFirestore(userSnap.data!);
                                          final bool isPassive = user.isFrozen || user.isDeleted;
                                          
                                          return Text(
                                            user.isDeleted ? 'Silinmiş Kullanıcı' : (data['senderName'] ?? 'Birisi'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              decoration: isPassive ? TextDecoration.lineThrough : null,
                                              color: Colors.blue, // Make it look clickable
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  TextSpan(text: ' ${data['content']}'),
                                ],
                              ),
                            ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data['title'] != null) Text(data['content'] ?? '', style: const TextStyle(fontSize: 13)),
                            Text(
                              data['timestamp'] != null
                                  ? DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(
                                      data['timestamp'] is Timestamp 
                                          ? (data['timestamp'] as Timestamp).toDate() 
                                          : (data['timestamp'] is String 
                                              ? (DateTime.tryParse(data['timestamp']) ?? DateTime.now())
                                              : DateTime.now())
                                    )
                                  : '',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                        trailing: _buildTrailingAction(context, doc.id, data, authService),
                        onTap: () {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('notifications')
                              .doc(doc.id)
                              .update({'isRead': true});
                          
                          final type = data['type'];
                          final senderId = data['senderId'];
                          final eventId = data['eventId'];

                          // Profil Yönlendirmeleri
                          if (type == 'friend_request' || type == 'friend_accepted' || type == 'new_follower') {
                            if (senderId != null) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: senderId)));
                            }
                          } 
                          // Mesaj Yönlendirmesi
                          else if (type == 'message') {
                            if (senderId != null) {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    receiverId: senderId, 
                                    receiverName: data['senderName'] ?? 'Sohbet',
                                  ),
                                ),
                              );
                            }
                          } 
                          // Etkinlik/Yorum/Mention Yönlendirmeleri
                          else if (eventId != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(
                                  eventId: eventId,
                                  initialCode: data['code'],
                                ),
                              ),
                            );
                          } 
                          // Diğer durumlar
                          else if (type == 'rating_prompt') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventDetailScreen(eventId: data['eventId']),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _getLeadingIcon(String? type) {
    switch (type) {
      case 'friend_request': return const CustomAvatar(backgroundColor: Colors.blue, placeholderIcon: Icons.person_add, iconColor: Colors.white);
      case 'friend_accepted': return const CustomAvatar(backgroundColor: Colors.green, placeholderIcon: Icons.person, iconColor: Colors.white);
      case 'message': return const CustomAvatar(backgroundColor: Colors.orange, placeholderIcon: Icons.chat, iconColor: Colors.white);
      case 'comment': return const CustomAvatar(backgroundColor: Colors.purple, placeholderIcon: Icons.comment, iconColor: Colors.white);
      case 'event_request': return const CustomAvatar(backgroundColor: Colors.deepOrange, placeholderIcon: Icons.event, iconColor: Colors.white);
      case 'event_promo': return const CustomAvatar(backgroundColor: Colors.redAccent, placeholderIcon: Icons.campaign, iconColor: Colors.white);
      case 'reference_code_received': return const CustomAvatar(backgroundColor: Colors.teal, placeholderIcon: Icons.vpn_key, iconColor: Colors.white);
      case 'point_change': return const CustomAvatar(backgroundColor: Colors.amber, placeholderIcon: Icons.stars, iconColor: Colors.white);
      case 'status_change': return const CustomAvatar(backgroundColor: Colors.blueGrey, placeholderIcon: Icons.verified_user, iconColor: Colors.white);
      case 'appeal_accepted': return const CustomAvatar(backgroundColor: Colors.green, placeholderIcon: Icons.gavel, iconColor: Colors.white);
      case 'rating_prompt': return const CustomAvatar(backgroundColor: Colors.amber, placeholderIcon: Icons.star, iconColor: Colors.white);
      case 'chat_mention': return const CustomAvatar(backgroundColor: Colors.blue, placeholderIcon: Icons.alternate_email, iconColor: Colors.white);
      case 'chat_mention_all': return const CustomAvatar(backgroundColor: Colors.orange, placeholderIcon: Icons.campaign, iconColor: Colors.white);
      default: return const CustomAvatar(backgroundColor: Colors.grey, placeholderIcon: Icons.notifications, iconColor: Colors.white);
    }
  }

  Widget? _buildTrailingAction(BuildContext context, String docId, Map<String, dynamic> data, AuthService authService) {
    // Status pending değilse veya boş değilse işlem butonlarını gösterme
    if (data['status'] != null && data['status'] != 'pending') return null;

    if (data['type'] == 'friend_request') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => authService.acceptFriendRequest(docId, data['senderId']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Kabul Et', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: () => authService.rejectFriendRequest(docId),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Reddet', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }
    
    if (data['type'] == 'event_request') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () => authService.acceptEventRequest(docId, data['eventId'], data['senderId']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Onayla', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 4),
          OutlinedButton(
            onPressed: () => authService.rejectEventRequest(docId, data['eventId'], data['senderId']),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: const BorderSide(color: Colors.grey),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: const Text('Reddet', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }

    return null;
  }
}
