import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommunitiesTab extends StatelessWidget {
  final Function(String id, Map<String, dynamic> data) onShowCommunityMembersDialog;
  final Function(String id, Map<String, dynamic> data) onShowEditCommunityDialog;
  final Function(String id, String name) onDeleteCommunity;
  final Function(String url)? launchUrl;
  final String? Function(String error)? extractIndexUrl;

  const CommunitiesTab({
    super.key,
    required this.onShowCommunityMembersDialog,
    required this.onShowEditCommunityDialog,
    required this.onDeleteCommunity,
    this.launchUrl,
    this.extractIndexUrl,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('communities').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final errorStr = snapshot.error.toString();
                final indexUrl = extractIndexUrl?.call(errorStr);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 48),
                        const SizedBox(height: 16),
                        const Text('Veri çekme hatası (İndeks gerekiyor olabilir)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (indexUrl != null && launchUrl != null) 
                          ElevatedButton.icon(
                            onPressed: () => launchUrl!(indexUrl), 
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Gerekli İndeksi Oluştur'),
                          )
                        else
                          Text(errorStr, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var communities = snapshot.data!.docs;
              if (communities.isEmpty) return const Center(child: Text('Henüz topluluk oluşturulmamış.'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: communities.length,
                itemBuilder: (context, index) {
                  var doc = communities[index];
                  var data = doc.data() as Map<String, dynamic>;
                  
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      title: Text(data['name'] ?? 'Adsız', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(data['description'] ?? 'Açıklama yok', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('Üye: ${ (data['members'] as List?)?.length ?? 0 }', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.people, color: Colors.teal),
                            onPressed: () => onShowCommunityMembersDialog(doc.id, data),
                            tooltip: 'Üyeleri Yönet',
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => onShowEditCommunityDialog(doc.id, data),
                            tooltip: 'Düzenle',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => onDeleteCommunity(doc.id, data['name'] ?? 'Adsız'),
                            tooltip: 'Sil',
                          ),
                        ],
                      ),
                      onTap: () => onShowEditCommunityDialog(doc.id, data),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
