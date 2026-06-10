import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/community_model.dart';
import '../models/user_model.dart';
import '../widgets/custom_avatar.dart';
import '../utils/constants.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final String communityId;

  const CommunityDetailScreen({super.key, required this.communityId});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';
  bool get _isAdmin => FirebaseAuth.instance.currentUser?.email == 'fatihkull17@gmail.com';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('communities').doc(widget.communityId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          debugPrint('Firestore Error in CommunityDetailScreen: $error');
          debugPrint('Community ID: ${widget.communityId}');
          debugPrint('Current User ID: $_currentUserId');
          
          String displayError = error;
          if (error.contains('permission-denied')) {
            displayError = 'Erişim Engellendi (403).\n\n'
                'Muhtemel Sebepler:\n'
                '1. App Check doğrulaması başarısız (Debug Token eksik).\n'
                '2. Firestore kuralları bu veriye erişime izin vermiyor.\n'
                '3. İnternet bağlantısı veya oturum hatası.\n\n'
                'Kullanıcı ID: $_currentUserId';
          }

          return Scaffold(
            appBar: AppBar(title: const Text('Hata')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Bir hata oluştu:\n$displayError',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Geri Dön'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text('Topluluk bulunamadı.')));

        final community = CommunityModel.fromFirestore(snapshot.data!);
        final isModerator = community.moderators.contains(_currentUserId) || _isAdmin;
        final isMember = community.members.contains(_currentUserId);

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(community.name),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Hakkında'),
                  Tab(text: 'Üyeler'),
                ],
              ),
              actions: [
                if (isModerator)
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () => _showSettingsDialog(community),
                  ),
              ],
            ),
            body: TabBarView(
              children: [
                _buildAboutTab(community, isMember),
                _buildMembersTab(community, isModerator),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAboutTab(CommunityModel community, bool isMember) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Topluluk Açıklaması',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 8),
          Text(
            community.description.isEmpty ? 'Henüz bir açıklama eklenmemiş.' : community.description,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Genel Topluluk Kuralları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              if (_isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: Colors.redAccent),
                  onPressed: () => _showEditGlobalRulesDialog(context),
                  tooltip: 'Genel Kuralları Düzenle',
                ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('app_settings').doc('config').snapshots(),
            builder: (context, configSnapshot) {
              String rules = defaultCommunityRules;
              if (configSnapshot.hasData && configSnapshot.data!.exists) {
                final data = configSnapshot.data!.data() as Map<String, dynamic>;
                rules = data['community_rules'] ?? defaultCommunityRules;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rules, style: const TextStyle(fontSize: 14, height: 1.5)),
                  const SizedBox(height: 24),
                  const Text(
                    'Topluluğa Özel Kurallar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    community.rules.isEmpty ? 'Bu topluluk için özel bir kural eklenmemiş.' : community.rules,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          if (!isMember)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _joinCommunity(community),
                icon: const Icon(Icons.group_add),
                label: const Text('Topluluğa Katıl', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatId: community.id,
                        chatName: community.name,
                        isGroup: true,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Sohbete Gir', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMembersTab(CommunityModel community, bool isModerator) {
    if (community.members.isEmpty) {
      return const Center(child: Text('Henüz üye yok.'));
    }

    return ListView.builder(
      itemCount: community.members.length,
      itemBuilder: (context, index) {
        final userId = community.members[index];
        return MemberListTile(
          userId: userId,
          community: community,
          isModerator: isModerator,
          currentUserId: _currentUserId,
        );
      },
    );
  }

  void _handleMemberAction(BuildContext context, String action, String userId, CommunityModel community) async {
    switch (action) {
      case 'make_mod':
        await FirebaseFirestore.instance.collection('communities').doc(community.id).update({
          'moderators': FieldValue.arrayUnion([userId]),
        });
        break;
      case 'remove_mod':
        await FirebaseFirestore.instance.collection('communities').doc(community.id).update({
          'moderators': FieldValue.arrayRemove([userId]),
        });
        break;
      case 'restrict':
        await FirebaseFirestore.instance.collection('communities').doc(community.id).update({
          'restrictedMembers': FieldValue.arrayUnion([userId]),
        });
        break;
      case 'remove_restriction':
        await FirebaseFirestore.instance.collection('communities').doc(community.id).update({
          'restrictedMembers': FieldValue.arrayRemove([userId]),
        });
        break;
      case 'kick':
        await FirebaseFirestore.instance.collection('communities').doc(community.id).update({
          'members': FieldValue.arrayRemove([userId]),
          'moderators': FieldValue.arrayRemove([userId]),
          'restrictedMembers': FieldValue.arrayRemove([userId]),
        });
        break;
    }
  }

  void _joinCommunity(CommunityModel community) async {
    await FirebaseFirestore.instance.collection('communities').doc(community.id).update({
      'members': FieldValue.arrayUnion([_currentUserId]),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Topluluğa katıldınız!')));
    }
  }

  void _showEditGlobalRulesDialog(BuildContext context) async {
    final doc = await FirebaseFirestore.instance.collection('app_settings').doc('config').get();
    String currentRules = defaultCommunityRules;
    if (doc.exists) {
      currentRules = (doc.data() as Map<String, dynamic>)['community_rules'] ?? defaultCommunityRules;
    }
    
    if (!context.mounted) return;
    final controller = TextEditingController(text: currentRules);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Genel Kuralları Düzenle'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 15,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Tüm gruplar için geçerli kurallar...',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('app_settings').doc('config').set({
                'community_rules': controller.text.trim(),
              }, SetOptions(merge: true));
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(CommunityModel community) {
    final descriptionController = TextEditingController(text: community.description);
    final rulesController = TextEditingController(text: community.rules);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Topluluğu Düzenle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Topluluk Açıklaması',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: rulesController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Topluluğa Özel Ek Kurallar',
                  border: OutlineInputBorder(),
                  hintText: 'Sadece bu gruba özel kuralları buraya yazın...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('communities').doc(community.id).update({
                'description': descriptionController.text.trim(),
                'rules': rulesController.text.trim(),
              });
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }
}

class MemberListTile extends StatelessWidget {
  final String userId;
  final CommunityModel community;
  final bool isModerator;
  final String currentUserId;

  const MemberListTile({
    super.key,
    required this.userId,
    required this.community,
    required this.isModerator,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.hasError) {
          return ListTile(
            title: const Text('Kullanıcı bilgisi alınamadı'),
            subtitle: Text('ID: $userId'),
          );
        }
        if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
          return const ListTile(title: Text('Yükleniyor...'));
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return ListTile(
            title: const Text('Bulunamayan Kullanıcı'),
            subtitle: Text('ID: $userId'),
          );
        }

        final user = UserModel.fromFirestore(userSnapshot.data!);
        final isUserModerator = community.moderators.contains(userId);
        final isUserRestricted = community.restrictedMembers.contains(userId);

        return ListTile(
          leading: CustomAvatar(imageUrl: user.profileImage, radius: 20),
          title: Text(user.name),
          subtitle: Row(
            children: [
              if (isUserModerator) const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.verified_user_rounded, color: Colors.teal, size: 14),
              ),
              Text(
                isUserModerator ? 'Topluluk Rehberi' : 'Üye',
                style: TextStyle(
                  color: isUserModerator ? Colors.teal : null,
                  fontWeight: isUserModerator ? FontWeight.bold : null,
                  fontSize: 12,
                ),
              ),
              if (isUserRestricted) const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text(' (Kısıtlı)', style: TextStyle(color: Colors.red, fontSize: 11)),
              ),
            ],
          ),
          trailing: isModerator && userId != currentUserId
              ? PopupMenuButton<String>(
                  onSelected: (value) {
                    final state = context.findAncestorStateOfType<_CommunityDetailScreenState>();
                    state?._handleMemberAction(context, value, userId, community);
                  },
                  itemBuilder: (context) {
                    final bool isUserAdmin = user.email == adminEmail;
                    return [
                      PopupMenuItem(
                        value: isUserModerator ? 'remove_mod' : 'make_mod',
                        enabled: !isUserAdmin,
                        child: Text(isUserModerator ? 'Rehberliği Kaldır' : 'Topluluk Rehberi Yap'),
                      ),
                      PopupMenuItem(
                        value: isUserRestricted ? 'remove_restriction' : 'restrict',
                        enabled: !isUserAdmin,
                        child: Text(isUserRestricted ? 'Mesaj Kısıtlamasını Kaldır' : 'Mesaj Yazmasını Kısıtla'),
                      ),
                      PopupMenuItem(
                        value: 'kick',
                        enabled: !isUserAdmin,
                        child: const Text('Topluluktan Çıkar', style: TextStyle(color: Colors.red)),
                      ),
                    ];
                  },
                )
              : null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: userId))),
        );
      },
    );
  }
}
