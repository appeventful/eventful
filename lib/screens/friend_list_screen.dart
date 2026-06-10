import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';
import '../widgets/custom_avatar.dart';
import '../models/user_model.dart';
import 'profile_screen.dart';

class FriendListScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const FriendListScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = userId == FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Arkadaşlarım' : '$userName - Arkadaşlar'),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Kullanıcı bulunamadı.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final List<dynamic> friends = data?['friends'] ?? [];

          if (friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    isMe ? 'Henüz arkadaşınız yok.' : 'Bu kullanıcının henüz arkadaşı yok.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              return _FriendTile(friendId: friends[index]);
            },
          );
        },
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  final String friendId;

  const _FriendTile({required this.friendId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final user = UserModel.fromFirestore(snapshot.data!);
        final isGhostMode = snapshot.data!.get('isGhostMode') ?? false;
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
            isPassive: isPassive,
            badgeIcons: badgeIcons,
          ),
          title: Text(
            user.name,
            style: TextStyle(
              decoration: isPassive ? TextDecoration.lineThrough : null,
              color: isPassive ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          subtitle: isGhostMode ? const Text('Hayalet Mod') : null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(otherUserId: friendId),
              ),
            );
          },
        );
      },
    );
  }
}
