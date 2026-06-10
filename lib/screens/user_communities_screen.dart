import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_detail_screen.dart';

class UserCommunitiesScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const UserCommunitiesScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$userName - Topluluklar", style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('communities')
            .where('members', arrayContains: userId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text("Hata: ${snap.error}"));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30), 
                child: Text("Henüz bir topluluğa üye değil.", 
                  style: TextStyle(color: Colors.grey.shade400))
              )
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final bool isMod = (data['moderators'] as List? ?? []).contains(userId);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withAlpha(26),
                    backgroundImage: (data['icon'] != null && data['icon'].toString().isNotEmpty) 
                        ? NetworkImage(data['icon']) : null,
                    child: (data['icon'] == null || data['icon'].toString().isEmpty) 
                        ? const Icon(Icons.group, color: Colors.orange) : null,
                  ),
                  title: Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: isMod 
                      ? const Text("Topluluk Rehberi", style: TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)) 
                      : const Text("Üye", style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CommunityDetailScreen(communityId: docs[i].id))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
