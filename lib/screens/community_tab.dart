import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import '../widgets/shimmer_effect.dart';
import 'community_detail_screen.dart';

class CommunityTab extends StatelessWidget {
  const CommunityTab({super.key});

  bool get _isAdmin => FirebaseAuth.instance.currentUser?.email == 'fatihkull17@gmail.com';

  @override
    Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Topluluklar', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('communities').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => ShimmerEffect(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            );
          }
          
          final communities = snapshot.data?.docs ?? [];

          if (communities.isEmpty) {
            return const Center(child: Text('Henüz topluluk oluşturulmamış.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: communities.length,
            itemBuilder: (context, index) {
              final doc = communities[index];
              final data = doc.data() as Map<String, dynamic>;
              final String name = data['name'] ?? 'Adsız Topluluk';
              
              return InkWell(
                onTap: () {
                  if (AuthService().isGuest) {
                    GuestGuardDialog.show(context, "Topluluklara katılma");
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CommunityDetailScreen(communityId: doc.id),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: isDark ? 0.05 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.groups_rounded, size: 40, color: Colors.orange),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'İncele',
                          style: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _isAdmin 
        ? FloatingActionButton(
            onPressed: () => _showCreateCommunityDialog(context),
            backgroundColor: Colors.orange,
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartFloat,
    );
  }

  void _showCreateCommunityDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Topluluk Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Topluluk Adı'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Kısa Açıklama'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              
              final id = 'community_${DateTime.now().millisecondsSinceEpoch}';
              await FirebaseFirestore.instance.collection('communities').doc(id).set({
                'name': nameController.text.trim(),
                'description': descController.text.trim(),
                'rules': '', // Boş başlar, detay ekranından eklenir
                'moderators': [],
                'members': [],
                'pinnedMessages': [],
                'createdAt': FieldValue.serverTimestamp(),
              });
              
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }
}
