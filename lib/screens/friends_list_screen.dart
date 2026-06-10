import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../widgets/custom_avatar.dart';
import 'profile_screen.dart';

class FriendsListScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String listType; // 'friends', 'followers', 'following'

  const FriendsListScreen({
    super.key, 
    required this.userId, 
    required this.userName,
    this.listType = 'friends',
  });

  @override
  Widget build(BuildContext context) {
    String titleText = '$userName - ';
    if (listType == 'followers') titleText += 'Takipçiler';
    else if (listType == 'following') titleText += 'Takip Ettikleri';
    else titleText += 'Arkadaşlar';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final List ids = data[listType] ?? [];

          if (ids.isEmpty) {
            String emptyMessage = 'Henüz arkadaş bulunmuyor.';
            if (listType == 'followers') emptyMessage = 'Henüz takipçi bulunmuyor.';
            else if (listType == 'following') emptyMessage = 'Henüz takip edilen kimse yok.';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    listType == 'friends' ? Icons.people_outline : (listType == 'followers' ? Icons.group_outlined : Icons.person_search_outlined),
                    size: 64, 
                    color: Colors.grey
                  ),
                  const SizedBox(height: 16),
                  Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: ids.length,
            itemBuilder: (context, index) {
              final targetUserId = ids[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(targetUserId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || !userSnap.data!.exists) return const ListTile();
                  
                  final user = UserModel.fromFirestore(userSnap.data!);
                  final bool isPassive = user.isFrozen || user.isDeleted;

                  final List<String> badgeIcons = user.badges.map((id) {
                    final badge = availableBadges.firstWhere(
                      (b) => b['id'] == id,
                      orElse: () => {'icon': ''},
                    );
                    return badge['icon'] as String;
                  }).where((icon) => icon.isNotEmpty).toList();

                  return ListTile(
                    leading: CustomAvatar(
                      imageUrl: user.profileImage, 
                      radius: 20,
                      isPassive: isPassive,
                      badgeIcons: badgeIcons,
                    ),
                    title: Text(
                      user.name, 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: isPassive ? TextDecoration.lineThrough : null,
                        color: isPassive ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                      )
                    ),
                    subtitle: Text('@${user.username}'),
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: targetUserId))
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
