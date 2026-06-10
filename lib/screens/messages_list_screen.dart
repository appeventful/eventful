import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_avatar.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'chat_screen.dart';
import 'search_screen.dart';

class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesajlarım', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          tabs: [
            const Tab(text: 'Sohbetler'),
            Tab(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .where('users', arrayContains: _currentUserId)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {
                  int requestCount = 0;
                  if (snapshot.hasData) {
                    // Sadece BİZE gelen (bizim başlatmadığımız) bekleyen istekleri say
                    requestCount = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return data['initiatedBy'] != _currentUserId;
                    }).length;
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('İstekler'),
                      if (requestCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                          child: Text('$requestCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _currentUserId.isEmpty
          ? const Center(child: Text('Lütfen giriş yapın.'))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildChatList(isPending: false),
                _buildChatList(isPending: true),
              ],
            ),
    );
  }

  Widget _buildChatList({required bool isPending}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: _currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text('Sohbetler yüklenirken bir hata oluştu: ${snapshot.error}', textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var allDocs = snapshot.data?.docs ?? [];
        
        // Filtreleme mantığı:
        // 1. "Sohbetler" Sekmesi (isPending: false): 
        //    - Durumu 'accepted' olanlar 
        //    VEYA
        //    - Durumu 'pending' olup, BİZİM başlattığımız ve mesaj gönderdiğimiz sohbetler.
        // 2. "İstekler" Sekmesi (isPending: true):
        //    - Durumu 'pending' olup, BAŞKASININ başlattığı (bize gelen) istekler.

        var docs = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool isGroup = data['isGroup'] ?? false;
          String status = data['status'] ?? 'accepted';
          String initiatedBy = data['initiatedBy'] ?? '';
          bool hasSentMessage = (data['lastMessage'] ?? '').toString().isNotEmpty;

          if (isGroup) {
            return !isPending; // Group chats always in "Sohbetler"
          }

          if (!isPending) {
            // Sohbetler sekmesi
            return status == 'accepted' || (status == 'pending' && initiatedBy == _currentUserId && hasSentMessage);
          } else {
            // İstekler sekmesi (Sadece bize gelenler)
            return status == 'pending' && initiatedBy != _currentUserId;
          }
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isPending ? Icons.mark_email_unread_outlined : Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  isPending ? 'Bekleyen mesaj isteği yok.' : 'Henüz bir mesajınız yok.', 
                  style: const TextStyle(color: Colors.grey)
                ),
              ],
            ),
          );
        }

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>? ?? {};
          final bData = b.data() as Map<String, dynamic>? ?? {};
          
          final raw1 = aData['lastMessageTime'];
          final raw2 = bData['lastMessageTime'];
          
          DateTime t1;
          if (raw1 is Timestamp) {
            t1 = raw1.toDate();
          } else if (raw1 is String) {
            t1 = DateTime.tryParse(raw1) ?? DateTime.fromMillisecondsSinceEpoch(0);
          } else {
            t1 = DateTime.fromMillisecondsSinceEpoch(0);
          }

          DateTime t2;
          if (raw2 is Timestamp) {
            t2 = raw2.toDate();
          } else if (raw2 is String) {
            t2 = DateTime.tryParse(raw2) ?? DateTime.fromMillisecondsSinceEpoch(0);
          } else {
            t2 = DateTime.fromMillisecondsSinceEpoch(0);
          }

          return t2.compareTo(t1);
        });

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var chatDoc = docs[index];
            var chatData = chatDoc.data() as Map<String, dynamic>;
            bool isGroup = chatData['isGroup'] ?? false;

            if (isGroup) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.orange.shade50,
                  child: Icon(Icons.groups, color: Colors.orange, size: 30),
                ),
                title: Text(
                  chatData['chatName'] ?? 'Topluluk Grubu',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  chatData['lastMessage'] ?? 'Sohbete katılın...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: chatDoc.id,
                        chatName: chatData['chatName'],
                        isGroup: true,
                      ),
                    ),
                  );
                },
              );
            }

            List users = chatData['users'] ?? [];
            String otherUserId = users.firstWhere((id) => id != _currentUserId, orElse: () => '');

            if (otherUserId.isEmpty) {
              return const SizedBox.shrink();
            }

            bool iAmInitiator = chatData['initiatedBy'] == _currentUserId;
            String status = chatData['status'] ?? 'accepted';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnap) {
                if (userSnap.hasError) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.error_outline)),
                    title: const Text('Kullanıcı yüklenemedi'),
                    subtitle: Text('ID: $otherUserId'),
                  );
                }
                if (!userSnap.hasData || !userSnap.data!.exists) {
                  if (userSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 80); // Placeholder for loading
                  }
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person_off)),
                    title: const Text('Bilinmeyen Kullanıcı'),
                    subtitle: const Text('Bu hesap artık mevcut değil.'),
                  );
                }

                final otherUser = UserModel.fromFirestore(userSnap.data!);
                final bool isPassive = otherUser.isFrozen || otherUser.isDeleted;

                // Map badge IDs to emojis
                final List<String> badgeIcons = otherUser.badges.map((badgeId) {
                  final badge = availableBadges.firstWhere(
                    (b) => b['id'] == badgeId,
                    orElse: () => <String, dynamic>{},
                  );
                  return badge['icon'] as String? ?? '';
                }).where((icon) => icon.isNotEmpty).toList();

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CustomAvatar(
                    radius: 28, 
                    imageUrl: otherUser.profileImage,
                    isPassive: isPassive,
                    badgeIcons: badgeIcons,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          otherUser.name, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            color: isPassive ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                            decoration: isPassive ? TextDecoration.lineThrough : null,
                          )
                        )
                      ),
                      if (otherUser.isDeleted)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                          child: const Text('Silinmiş', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                        )
                      else if (otherUser.isFrozen)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                          child: const Text('Dondurulmuş', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      if (isPending && iAmInitiator && !otherUser.isDeleted && !otherUser.isFrozen)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                          child: const Text('İstek Gönderildi', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    chatData['lastMessage']?.isEmpty == true ? (iAmInitiator ? 'İstek yanıt bekliyor...' : 'Yeni bir mesaj isteği!') : chatData['lastMessage'] ?? '...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: (chatData['unreadCount']?[_currentUserId] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                      fontStyle: chatData['lastMessage']?.isEmpty == true ? FontStyle.italic : FontStyle.normal,
                      color: (chatData['unreadCount']?[_currentUserId] ?? 0) > 0 
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : (chatData['lastMessage']?.isEmpty == true ? (status == 'pending' ? Colors.blue : Colors.orange) : Colors.grey.shade600),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status == 'pending' && iAmInitiator)
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                          onPressed: () => _showCancelRequestDialog(chatDoc.id),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (chatData['lastMessageTime'] != null)
                            Text(
                              _formatTime(chatData['lastMessageTime'] is Timestamp ? (chatData['lastMessageTime'] as Timestamp).toDate() : DateTime.now()),
                              style: TextStyle(
                                fontSize: 11, 
                                color: (chatData['unreadCount']?[_currentUserId] ?? 0) > 0 ? Colors.orange : Colors.grey.shade500,
                                fontWeight: (chatData['unreadCount']?[_currentUserId] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          const SizedBox(height: 4),
                          if ((chatData['unreadCount']?[_currentUserId] ?? 0) > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                              child: Text(
                                '${chatData['unreadCount'][_currentUserId]}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            )
                          else
                            const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(receiverId: otherUserId, receiverName: otherUser.name),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCancelRequestDialog(String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İsteği Geri Çek'),
        content: const Text('Gönderdiğiniz mesaj isteğini iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Evet, İptal Et', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.day}/${date.month}/${date.year}";
  }
}
