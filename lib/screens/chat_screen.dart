import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_avatar.dart';
import 'profile_screen.dart';
import 'community_detail_screen.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final String? receiverId;
  final String? receiverName;
  final String? chatId;
  final String? chatName;
  final bool isGroup;

  const ChatScreen({
    super.key,
    this.receiverId,
    this.receiverName,
    this.chatId,
    this.chatName,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _metBefore = false;

  String? _replyingToId;
  String? _replyingToText;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    if (!widget.isGroup && widget.receiverId != null) {
      _checkMetBefore();
    }
  }

  void _checkMetBefore() async {
    final met = await ChatService().haveMetBefore(widget.receiverId!);
    if (mounted) {
      setState(() {
        _metBefore = met;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String get _chatId {
    if (widget.isGroup && widget.chatId != null) {
      return widget.chatId!;
    }
    // Create a unique and consistent room ID between two users (Ordered UID combination)
    List<String> ids = [_currentUserId, widget.receiverId!];
    ids.sort();
    return ids.join('_');
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    String text = _messageController.text.trim();

    if (widget.isGroup) {
      _messageController.clear();
      final messageData = {
        'senderId': _currentUserId,
        'senderName': FirebaseAuth.instance.currentUser?.displayName ?? 'Kullanıcı',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        if (_replyingToId != null) 'replyToId': _replyingToId,
        if (_replyingToText != null) 'replyToText': _replyingToText,
        if (_replyingToName != null) 'replyToName': _replyingToName,
      };
      
      setState(() {
        _replyingToId = null;
        _replyingToText = null;
        _replyingToName = null;
      });

      await FirebaseFirestore.instance.collection('community_messages').doc(_chatId).collection('messages').add(messageData);
      await FirebaseFirestore.instance.collection('communities').doc(_chatId).set({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'isGroup': true,
        'chatName': widget.chatName,
        'participants': FieldValue.arrayUnion([_currentUserId]),
        'users': FieldValue.arrayUnion([_currentUserId]),
      }, SetOptions(merge: true));
      return;
    }

    // 0. Privacy & Restriction Check
    final receiverDoc = await FirebaseFirestore.instance.collection('users').doc(widget.receiverId!).get();
    final receiverData = receiverDoc.data() as Map<String, dynamic>?;

    if (receiverData?['isFrozen'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu kullanıcının hesabı dondurulmuştur, mesaj gönderilemez.'))
        );
      }
      return;
    }

    if (receiverData?['isDeleted'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu kullanıcı artık mevcut değil.'))
        );
      }
      return;
    }

    final String preference = receiverData?['messagePreference'] ?? 'everyone';
    
    if (preference == 'nobody') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu kullanıcı mesaj alımını kapatmıştır.'))
        );
      }
      return;
    }

    if (preference == 'metBefore') {
      final chatService = ChatService();
      bool met = await chatService.haveMetBefore(widget.receiverId!);
      
      // Arkadaşlık kontrolü de yapalım (Kullanıcı "buluştuklarım" dediyse arkadaşları da kapsamalıdır genelde)
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      final myFriends = List<String>.from(myDoc.data()?['friends'] ?? []);
      bool isFriend = myFriends.contains(widget.receiverId!);

      if (!met && !isFriend) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu kullanıcı sadece arkadaşları veya daha önce etkinlikte buluştuğu kişilerden mesaj kabul ediyor.'))
          );
        }
        return;
      }
    }

    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(_chatId).get();
    
    String status;
    String initiatedBy;

    if (!chatDoc.exists) {
      // İlk mesaj: Durumu belirle (Arkadaşlık veya Buluşma kontrolü)
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      final myFriends = List<String>.from(myDoc.data()?['friends'] ?? []);
      bool isFriend = myFriends.contains(widget.receiverId!);
      bool met = await ChatService().haveMetBefore(widget.receiverId!);
      
      status = (isFriend || met) ? 'accepted' : 'pending';
      initiatedBy = _currentUserId;
    } else {
      status = chatDoc.data()?['status'] ?? 'accepted';
      initiatedBy = chatDoc.data()?['initiatedBy'] ?? '';

      // Alıcı bir mesaj gönderirse isteği otomatik olarak kabul et
      if (status == 'pending' && initiatedBy != _currentUserId) {
        status = 'accepted';
      }
    }

    // Reddedilmişse tekrar kontrol et (Arkadaş olmuş olabilirler)
    if (status == 'rejected') {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      final myFriends = List<String>.from(myDoc.data()?['friends'] ?? []);
      if (myFriends.contains(widget.receiverId!)) {
        status = 'accepted';
        await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({'status': 'accepted'});
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bu mesaj isteği reddedildi. Tekrar mesaj göndermek için arkadaş olmalısınız.'))
          );
        }
        return;
      }
    }
    
    // Eğer durum pending ise ve biz başlattıysak, mesaj sayısını kontrol et
    if (status == 'pending' && initiatedBy == _currentUserId) {
      final messagesCount = await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .count()
          .get();
      
      if ((messagesCount.count ?? 0) >= 1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Karşı taraf isteğinizi kabul edene kadar sadece 1 mesaj gönderebilirsiniz.'))
          );
        }
        return;
      }
    }

    _messageController.clear();

    await FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages').add({
      'senderId': _currentUserId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update chat summary
    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'users': [_currentUserId, widget.receiverId!],
      'participants': [_currentUserId, widget.receiverId!],
      'status': status,
      'initiatedBy': initiatedBy,
      'isGroup': false,
    }, SetOptions(merge: true));

    // 3. Send notification
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
    final myName = myDoc.data()?['name'] ?? 'Biri';

    if (status == 'pending') {
      await NotificationService.sendNotification(
        recipientId: widget.receiverId!,
        title: 'Yeni Mesaj İsteği 📩',
        body: '$myName size bir mesaj isteği gönderdi: "$text"',
        data: {
          'type': 'message',
          'senderId': _currentUserId,
          'chatId': _chatId,
        },
      );
    } else {
      await NotificationService.sendNotification(
        recipientId: widget.receiverId!,
        title: '$myName bir mesaj gönderdi',
        body: text,
        data: {
          'type': 'message',
          'senderId': _currentUserId,
          'chatId': _chatId,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGroup) {
      return _buildGroupChat();
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
      builder: (userCtx, userSnapshot) {
        if (userSnapshot.hasError) {
          return Scaffold(body: Center(child: Text('Hata: ${userSnapshot.error}')));
        }
        if (!userSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final List mutedChats = userData?['mutedChats'] ?? [];
        final List blockedChats = userData?['blockedUsers'] ?? [];
        
        final bool isMuted = mutedChats.contains(widget.receiverId!);
        final bool iBlocked = blockedChats.contains(widget.receiverId!);
        final List friends = userData?['friends'] ?? [];
        final bool isFriend = friends.contains(widget.receiverId!);

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.receiverId!).snapshots(),
          builder: (receiverCtx, receiverSnapshot) {
            if (receiverSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: Text(widget.receiverName ?? 'Sohbet')),
                body: Center(child: Text('Kullanıcı bilgileri yüklenirken hata oluştu: ${receiverSnapshot.error}')),
              );
            }
            if (!receiverSnapshot.hasData) {
              return Scaffold(
                appBar: AppBar(title: Text(widget.receiverName ?? 'Sohbet')),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final receiver = UserModel.fromFirestore(receiverSnapshot.data!);
            final List receiverBlockedList = receiverSnapshot.data?.data() != null && (receiverSnapshot.data!.data() as Map<String, dynamic>).containsKey('blockedUsers') 
                ? receiverSnapshot.data!.get('blockedUsers') 
                : [];
            final bool theyBlockedMe = receiverBlockedList.contains(_currentUserId);
            final bool isBlocked = iBlocked || theyBlockedMe;
            final bool isPassive = receiver.isFrozen || receiver.isDeleted;

            return Scaffold(
              resizeToAvoidBottomInset: true,
              appBar: AppBar(
                title: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: widget.receiverId!))),
                  child: Row(
                    children: [
                      CustomAvatar(
                        radius: 16, 
                        imageUrl: receiver.profileImage,
                        isPassive: isPassive,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.receiverName ?? '', 
                                style: TextStyle(
                                  fontSize: 18,
                                  decoration: isPassive ? TextDecoration.lineThrough : null,
                                ), 
                                overflow: TextOverflow.ellipsis
                              )
                            ),
                            if (receiver.isFounder) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.stars_rounded, size: 16, color: Colors.amber),
                            ],
                            if (receiver.role == 'admin') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.blueAccent),
                            ] else if (receiver.role == 'moderator') ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.shield_rounded, size: 16, color: Colors.purple),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                elevation: 1,
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(context, value, isMuted, iBlocked),
                    itemBuilder: (popCtx) => [
                      const PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.person_outline), SizedBox(width: 8), Text('Profili Görüntüle')])),
                      PopupMenuItem(
                        value: 'mute', 
                        child: Row(
                          children: [
                            Icon(isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined), 
                            const SizedBox(width: 8), 
                            Text(isMuted ? 'Sesi Aç' : 'Sessize Al')
                          ]
                        )
                      ),
                      PopupMenuItem(
                        value: 'block', 
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red), 
                            const SizedBox(width: 8), 
                            Text(iBlocked ? 'Engeli Kaldır' : 'Sohbeti Engelle', style: const TextStyle(color: Colors.red))
                          ]
                        )
                      ),
                      const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.report_problem_outlined, color: Colors.orange), SizedBox(width: 8), Text('Yöneticiye Bildir', style: TextStyle(color: Colors.orange))])),
                    ],
                  ),
                ],
              ),
              body: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('chats').doc(_chatId).snapshots(),
                builder: (chatCtx, chatSnapshot) {
                  if (chatSnapshot.hasError) {
                    return Center(child: Text('Sohbet verisi yüklenirken hata: ${chatSnapshot.error}'));
                  }
                  if (!chatSnapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final chatData = chatSnapshot.data?.data() as Map<String, dynamic>?;
                  
                  // Veritabanında henüz yoksa veya status alanı boşsa, arkadaşlık/buluşma durumuna göre varsayılanı belirle
                  String status = chatData?['status'] ?? '';
                  if (status.isEmpty) {
                    status = (isFriend || _metBefore) ? 'accepted' : 'pending';
                  }

                  final String initiatedBy = chatData?['initiatedBy'] ?? (status == 'pending' ? _currentUserId : '');
                  final bool isPending = status == 'pending';
                  final bool isRejected = status == 'rejected';
                  final bool iAmInitiator = initiatedBy == _currentUserId;
                  final bool iAmReceiver = !iAmInitiator;
                  final bool hasSentMessage = (chatData?['lastMessage'] ?? '').toString().isNotEmpty;

                  return Column(
                    children: [
                      if (isRejected)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Colors.red.withValues(alpha: 0.1),
                          child: const Text(
                            'Bu mesaj isteği reddedildi. Tekrar mesajlaşmak için arkadaş olmalısınız.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (isPending && iAmReceiver)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Colors.orange.withValues(alpha: 0.1),
                          child: Column(
                            children: [
                              const Text(
                                'Bu kullanıcıyla arkadaş değilsiniz veya daha önce bir etkinlikte buluşmadınız. Mesajlaşmaya devam etmek için isteği kabul etmelisiniz.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.orange),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                    onPressed: () => FirebaseFirestore.instance.collection('chats').doc(_chatId).update({'status': 'accepted'}),
                                    child: const Text('Kabul Et', style: TextStyle(color: Colors.white)),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton(
                                    onPressed: () async {
                                      bool confirm = await _showConfirmDialog(context, 'İsteği Reddet', 'Bu mesaj isteğini reddetmek istediğinize emin misiniz?');
                                      if (confirm) {
                                        await FirebaseFirestore.instance.collection('chats').doc(_chatId).update({'status': 'rejected'});
                                      }
                                    },
                                    child: const Text('Reddet'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (isPending && iAmInitiator)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.blue.withValues(alpha: 0.1),
                          child: Text(
                            hasSentMessage 
                              ? 'Mesaj isteğiniz gönderildi. Karşı taraf kabul edene kadar başka mesaj gönderemezsiniz.'
                              : 'Bu kullanıcıyla arkadaş değilsiniz veya daha önce buluşmadınız. Sadece 1 mesaj hakkınız bulunmaktadır.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: hasSentMessage ? Colors.blue : Colors.orange, fontStyle: FontStyle.italic),
                          ),
                        ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection(widget.isGroup ? 'community_messages' : 'chats')
                              .doc(_chatId)
                              .collection('messages')
                              .snapshots(),
                          builder: (msgCtx, snapshot) {
                            if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                            
                            var messages = snapshot.data!.docs.toList();
                            messages.sort((a, b) {
                              final aData = a.data() as Map<String, dynamic>? ?? {};
                              final bData = b.data() as Map<String, dynamic>? ?? {};
                              
                              DateTime aTime;
                              dynamic aRaw = aData['createdAt'];
                              if (aRaw is Timestamp) {
                                aTime = aRaw.toDate();
                              } else if (aRaw is String) {
                                aTime = DateTime.tryParse(aRaw) ?? DateTime.now();
                              } else {
                                aTime = DateTime.now();
                              }

                              DateTime bTime;
                              dynamic bRaw = bData['createdAt'];
                              if (bRaw is Timestamp) {
                                bTime = bRaw.toDate();
                              } else if (bRaw is String) {
                                bTime = DateTime.tryParse(bRaw) ?? DateTime.now();
                              } else {
                                bTime = DateTime.now();
                              }

                              return bTime.compareTo(aTime);
                            });

                            return ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(16),
                              itemCount: messages.length,
                              itemBuilder: (itemCtx, index) {
                                var doc = messages[index];
                                var data = doc.data() as Map<String, dynamic>;
                                bool isMe = data['senderId'] == _currentUserId;
                                bool isDeleted = data['isDeleted'] ?? false;
                                bool isHidden = data['isHidden'] ?? false;
                                bool isAdmin = FirebaseAuth.instance.currentUser?.email == 'fatihkull17@gmail.com';

                                if (isHidden && !isAdmin) {
                                  return Align(
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: Theme.of(context).disabledColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                      child: const Text('🚫 Bu içerik moderasyon tarafından gizlendi.', 
                                        style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                                    ),
                                  );
                                }
                                
                                DateTime? createdAt;
                                dynamic rawCreatedAt = data['createdAt'];
                                if (rawCreatedAt is Timestamp) {
                                  createdAt = rawCreatedAt.toDate();
                                } else if (rawCreatedAt is String) {
                                  createdAt = DateTime.tryParse(rawCreatedAt);
                                }

                                return Align(
                                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (!isMe && !isDeleted)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                data['senderName'] ?? widget.receiverName ?? '',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodySmall?.color),
                                              ),
                                              if (receiver.isFounder) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.stars_rounded, size: 12, color: Colors.amber),
                                                ],
                                                if (receiver.role == 'admin') ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.workspace_premium_rounded, size: 14, color: Colors.blueAccent),
                                                ] else if (receiver.role == 'moderator') ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.shield_rounded, size: 12, color: Colors.purple),
                                                ],
                                            ],
                                          ),
                                        ),
                                      GestureDetector(
                                        onLongPress: () => _showMessageOptions(context, doc.id, data['text'], data['senderId']),
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isDeleted ? Theme.of(context).disabledColor.withValues(alpha: 0.1) : (isMe ? Colors.orange : Theme.of(context).cardColor),
                                            border: isHidden ? Border.all(color: Colors.purple.shade200, width: 2) : null,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(16),
                                              topRight: const Radius.circular(16),
                                              bottomLeft: Radius.circular(isMe ? 16 : 0),
                                              bottomRight: Radius.circular(isMe ? 0 : 16),
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: [
                                              if (isHidden)
                                                const Padding(
                                                  padding: EdgeInsets.only(bottom: 4.0),
                                                  child: Text('GİZLENDİ (Admin Görünümü)', style: TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.bold)),
                                                ),
                                              Text(
                                                isDeleted ? 'Bu mesaj silindi' : (data['text'] ?? ''), 
                                                style: TextStyle(
                                                  color: isDeleted ? Colors.grey : (isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color),
                                                  fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                                ),
                                              ),
                                              if (!isDeleted) const SizedBox(height: 4),
                                              if (!isDeleted) Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (data['isEdited'] == true) 
                                                    Text(
                                                      'düzenlendi  ', 
                                                      style: TextStyle(fontSize: 9, color: isMe ? Colors.white60 : Colors.grey, fontStyle: FontStyle.italic),
                                                    ),
                                                  Text(
                                                    createdAt != null ? DateFormat('HH:mm', 'tr_TR').format(createdAt) : '',
                                                    style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Emoji Tepkileri Görünümü
                                      if (data['reactions'] != null && (data['reactions'] as Map).isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Wrap(
                                            spacing: 4,
                                            children: (data['reactions'] as Map).entries.map((entry) {
                                              List users = entry.value as List;
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: users.contains(_currentUserId) ? Colors.orange.withValues(alpha: 0.2) : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: users.contains(_currentUserId) ? Colors.orange : Colors.transparent, width: 0.5),
                                                ),
                                                child: Text('${entry.key} ${users.length}', style: const TextStyle(fontSize: 10)),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      _buildInputArea(isBlocked || isRejected || (isPending && iAmInitiator && hasSentMessage)),
                    ],
                  );
                }
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildGroupChat() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(_chatId).snapshots(),
      builder: (context, communitySnapshot) {
        if (communitySnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.chatName ?? 'Grup Sohbeti')),
            body: Center(child: Text('Hata: ${communitySnapshot.error}')),
          );
        }
        if (!communitySnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final communityData = communitySnapshot.data?.data() as Map<String, dynamic>?;
        final List moderators = communityData?['moderators'] ?? [];
        final List restrictedMembers = communityData?['restrictedMembers'] ?? [];
        final List pinnedMessages = communityData?['pinnedMessages'] ?? [];
        final bool isGodMode = FirebaseAuth.instance.currentUser?.email == 'fatihkull17@gmail.com';
        final bool isModerator = moderators.contains(_currentUserId) || isGodMode;
        final bool isRestricted = restrictedMembers.contains(_currentUserId) && !isGodMode;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatName ?? 'Grup Sohbeti', style: const TextStyle(fontSize: 16)),
                if (pinnedMessages.isNotEmpty)
                  const Text('📍 Sabitlenmiş mesajlar var', style: TextStyle(fontSize: 10, color: Colors.orange)),
              ],
            ),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
            elevation: 1,
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () => Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => CommunityDetailScreen(communityId: _chatId))
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (pinnedMessages.isNotEmpty)
                _buildPinnedMessagesBar(pinnedMessages),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('community_messages')
                      .doc(_chatId)
                      .collection('messages')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Hata: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    
                    var messages = snapshot.data!.docs.toList();
                    messages.sort((a, b) {
                      Timestamp aTime = (a.data() as Map)['createdAt'] ?? Timestamp.now();
                      Timestamp bTime = (b.data() as Map)['createdAt'] ?? Timestamp.now();
                      return bTime.compareTo(aTime);
                    });

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var doc = messages[index];
                        var data = doc.data() as Map<String, dynamic>;
                        bool isMe = data['senderId'] == _currentUserId;
                        bool isPinned = pinnedMessages.contains(doc.id);
                        bool isDeleted = data['isDeleted'] ?? false;
                        bool isSenderModerator = moderators.contains(data['senderId']);

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (!isMe && !isDeleted)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        data['senderName'] ?? 'Kullanıcı',
                                        style: TextStyle(
                                          fontSize: 11, 
                                          fontWeight: FontWeight.bold, 
                                          color: isSenderModerator ? Colors.teal : Theme.of(context).textTheme.bodySmall?.color
                                        ),
                                      ),
                                      if (isSenderModerator) ...[
                                        const SizedBox(width: 4),
                                        const Icon(Icons.verified_user_rounded, color: Colors.teal, size: 12),
                                      ],
                                    ],
                                  ),
                                ),
                              GestureDetector(
                                onLongPress: () => _showGroupMessageOptions(context, doc.id, data['text'], data['senderId'], isModerator, isPinned),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isPinned ? Colors.orange.withValues(alpha: 0.1) : (isMe ? Colors.orange : Theme.of(context).cardColor),
                                    border: isPinned ? Border.all(color: Colors.orange, width: 1) : null,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                                      bottomRight: Radius.circular(isMe ? 0 : 16),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (data['replyToText'] != null)
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          margin: const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Replying to: ${data['replyToText']}',
                                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      if (isPinned)
                                        const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.push_pin, size: 12, color: Colors.orange),
                                            SizedBox(width: 4),
                                            Text('Sabitlendi', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      Text(
                                        isDeleted ? 'Bu mesaj silindi' : (data['text'] ?? ''),
                                        style: TextStyle(color: isDeleted ? Colors.grey : (isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_replyingToId != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.reply, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Yanıtlanıyor: $_replyingToText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => setState(() {
                          _replyingToId = null;
                          _replyingToText = null;
                          _replyingToName = null;
                        }),
                      ),
                    ],
                  ),
                ),
              _buildInputArea(isRestricted),
            ],
          ),
        );
      }
    );
  }

  Widget _buildPinnedMessagesBar(List pinnedMessages) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.withValues(alpha: 0.1),
      child: const Row(
        children: [
          Icon(Icons.push_pin, size: 16, color: Colors.orange),
          SizedBox(width: 8),
          Text('Sabitlenmiş mesajlar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
        ],
      ),
    );
  }

  void _showGroupMessageOptions(BuildContext context, String messageId, String? text, String senderId, bool isModerator, bool isPinned) {
    bool isMe = senderId == _currentUserId;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji Tepkileri Satırı
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                  return IconButton(
                    icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _handleReaction(messageId, emoji);
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Yanıtla'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyingToId = messageId;
                  _replyingToText = text;
                  _replyingToName = isMe ? 'Sen' : 'Kullanıcı';
                });
              },
            ),
            if (isMe || isModerator) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, messageId, text ?? '');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  bool confirm = await _showConfirmDialog(context, 'Sil', 'Bu mesajı silmek istediğinizden emin misiniz?');
                  if (confirm) {
                    await FirebaseFirestore.instance
                        .collection(widget.isGroup ? 'community_messages' : 'chats')
                        .doc(_chatId)
                        .collection('messages')
                        .doc(messageId)
                        .update({
                      'isDeleted': true,
                      'text': 'Bu mesaj silindi',
                    });
                  }
                },
              ),
            ],
            if (isModerator)
              ListTile(
                leading: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin),
                title: Text(isPinned ? 'Sabitlemeyi Kaldır' : 'Sabitle'),
                onTap: () async {
                  Navigator.pop(context);
                  if (isPinned) {
                    await FirebaseFirestore.instance.collection('communities').doc(_chatId).update({
                      'pinnedMessages': FieldValue.arrayRemove([messageId]),
                    });
                  } else {
                    await FirebaseFirestore.instance.collection('communities').doc(_chatId).update({
                      'pinnedMessages': FieldValue.arrayUnion([messageId]),
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleReaction(String messageId, String emoji) async {
    final docRef = FirebaseFirestore.instance
        .collection(widget.isGroup ? 'community_messages' : 'chats')
        .doc(_chatId)
        .collection('messages')
        .doc(messageId);

    final doc = await docRef.get();
    Map<String, dynamic> reactions = Map<String, dynamic>.from(doc.data()?['reactions'] ?? {});

    // Eğer kullanıcı zaten bu emojiye basmışsa kaldır, basmamışsa ekle
    List users = reactions[emoji] ?? [];
    if (users.contains(_currentUserId)) {
      users.remove(_currentUserId);
    } else {
      // Diğer emojilerden uidi temizle (opsiyonel: tek tepki sınırı)
      reactions.forEach((key, value) {
        if (value is List) value.remove(_currentUserId);
      });
      users.add(_currentUserId);
    }

    if (users.isEmpty) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = users;
    }

    await docRef.update({'reactions': reactions});
  }

  void _showMessageOptions(BuildContext context, String messageId, String? currentText, String senderId) {
    bool isMe = senderId == _currentUserId;
    bool isGodMode = FirebaseAuth.instance.currentUser?.email == 'fatihkull17@gmail.com';
    
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.orange),
                title: const Text('Mesajı Bildir'),
                onTap: () {
                  Navigator.pop(context);
                  _showSingleMessageReportDialog(context, messageId, currentText, senderId);
                },
              ),
            if (isMe || isGodMode) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(isGodMode && !isMe ? 'Düzenle (Admin)' : 'Mesajı Düzenle'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, messageId, currentText ?? '');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(isGodMode && !isMe ? 'Sil (Admin)' : 'Mesajı Sil', style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  bool confirm = await _showConfirmDialog(context, 'Sil', 'Bu mesajı silmek istediğinizden emin misiniz?');
                  if (confirm) {
                    await FirebaseFirestore.instance
                        .collection(widget.isGroup ? 'community_messages' : 'chats')
                        .doc(_chatId)
                        .collection('messages')
                        .doc(messageId)
                        .update({
                      'isDeleted': true,
                      'text': 'Bu mesaj silindi',
                    });
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSingleMessageReportDialog(BuildContext context, String messageId, String? content, String senderId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesajı Bildir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Bildirme sebebi...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () {
            FocusScope.of(dialogContext).unfocus();
            Navigator.pop(dialogContext);
          }, child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              
              FocusScope.of(dialogContext).unfocus();

              // Get reported user's name
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(senderId).get();
              final senderName = userDoc.data()?['name'] ?? 'Kullanıcı';

              await FirebaseFirestore.instance.collection('reports').add({
                'category': 'message',
                'targetId': messageId,
                'targetContent': content,
                'targetUserId': senderId,
                'targetUserName': senderName,
                'reason': reason,
                'reporterId': _currentUserId,
                'reporterName': FirebaseAuth.instance.currentUser?.displayName ?? FirebaseAuth.instance.currentUser?.email,
                'status': 'pending',
                'timestamp': FieldValue.serverTimestamp(),
                'chatId': _chatId,
              });
              
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mesaj bildirildi.')));
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showEditDialog(BuildContext context, String messageId, String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mesajı Düzenle'),
        content: TextField(
          controller: controller,
          maxLength: 280,
          decoration: const InputDecoration(hintText: 'Mesajınızı güncelleyin...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection(widget.isGroup ? 'community_messages' : 'chats')
                  .doc(_chatId)
                  .collection('messages')
                  .doc(messageId)
                  .update({
                'text': controller.text.trim(),
                'isEdited': true,
              });
              if (context.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
  void _handleMenuAction(BuildContext context, String action, bool isMuted, bool iBlocked) async {
    switch (action) {
      case 'profile':
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: widget.receiverId)));
        break;
      case 'mute':
        if (isMuted) {
          await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
            'mutedChats': FieldValue.arrayRemove([widget.receiverId])
          });
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sohbet sesi açıldı.')));
        } else {
          await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
            'mutedChats': FieldValue.arrayUnion([widget.receiverId])
          });
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sohbet sessize alındı.')));
        }
        break;
      case 'block':
        if (iBlocked) {
          await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
            'blockedUsers': FieldValue.arrayRemove([widget.receiverId])
          });
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Engel kaldırıldı.')));
        } else {
          bool confirm = await _showConfirmDialog(context, 'Engelle', 'Bu kullanıcıdan mesaj almak istemediğinize emin misiniz?');
          if (confirm) {
            await FirebaseFirestore.instance.collection('users').doc(_currentUserId).update({
              'blockedUsers': FieldValue.arrayUnion([widget.receiverId])
            });
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı engellendi.')));
          }
        }
        break;
      case 'report':
        _showReportDialog(context);
        break;
    }
  }

  Future<bool> _showConfirmDialog(BuildContext context, String title, String content) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(title, style: const TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  void _showReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sohbeti Bildir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Bildirme sebebi...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () {
            FocusScope.of(dialogContext).unfocus();
            Navigator.pop(dialogContext);
          }, child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              
              FocusScope.of(dialogContext).unfocus();

              await FirebaseFirestore.instance.collection('reports').add({
                'category': 'chat',
                'targetId': _chatId,
                'reason': reason,
                'reporterId': _currentUserId,
                'reporterName': FirebaseAuth.instance.currentUser?.displayName ?? FirebaseAuth.instance.currentUser?.email,
                'status': 'pending',
                'timestamp': FieldValue.serverTimestamp(),
                'reportedUserId': widget.receiverId,
              });
              if (context.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sohbet bildirildi.')));
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }
  Widget _buildInputArea(bool isBlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, 
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor))
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController, 
                enabled: !isBlocked,
                minLines: 1,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: isBlocked ? 'Bu sohbete mesaj gönderilemez.' : 'Bir mesaj yazın...',
                  border: InputBorder.none,
                  counterText: "", 
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20), 
                onPressed: isBlocked ? null : _sendMessage,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
