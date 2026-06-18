import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'event_detail_screen.dart';
import '../services/auth_service.dart';

class ProfileEventsScreen extends StatelessWidget {
  final String userId;
  final String userName;
  final String type; // 'organized' or 'joined'

  const ProfileEventsScreen({
    super.key, 
    required this.userId, 
    required this.userName, 
    required this.type
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          type == 'organized' ? '$userName - Düzenlenenler' : '$userName - Katılınanlar',
          style: const TextStyle(fontWeight: FontWeight.bold)
        ),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: type == 'organized'
            ? FirebaseFirestore.instance
                .collection('events')
                .where('creatorId', isEqualTo: userId)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('events')
                .where('participants', arrayContains: userId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Firestore Error: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text('Hata: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data?.docs ?? [];
          
          // Filtering: Non-archived
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            
            // 1. Filter out archived
            if (data['isArchived'] == true) return false;

            // 2. For 'joined' type, exclude events created by the user themselves
            if (type == 'joined' && data['creatorId'] == userId) return false;

            return true;
          }).toList();

          // Sorting: Newest to Oldest
          docs.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            final rawA = aData['eventDate'];
            final rawB = bData['eventDate'];
            DateTime aDate = rawA is Timestamp ? rawA.toDate() : (rawA is String ? DateTime.tryParse(rawA) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0));
            DateTime bDate = rawB is Timestamp ? rawB.toDate() : (rawB is String ? DateTime.tryParse(rawB) ?? DateTime.fromMillisecondsSinceEpoch(0) : DateTime.fromMillisecondsSinceEpoch(0));
            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('Henüz bir etkinlik bulunmuyor.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var event = docs[index].data() as Map<String, dynamic>;
              String eventId = docs[index].id;
              final rawDate = event['eventDate'];
              DateTime date = rawDate is Timestamp ? rawDate.toDate() : (rawDate is String ? DateTime.tryParse(rawDate) ?? DateTime.now() : DateTime.now());

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: (event['imageUrl'] != null && event['imageUrl'].toString().isNotEmpty)
                      ? Image.network(
                          event['imageUrl'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(width: 50, height: 50, color: Colors.orange[100], child: const Icon(Icons.event)),
                        )
                      : Container(width: 50, height: 50, color: Colors.orange[100], child: const Icon(Icons.event)),
                  ),
                  title: Text(event['title'] ?? 'Başlıksız', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    AuthService().isGuest 
                      ? 'Görmek için üye ol' 
                      : DateFormat('dd MMMM yyyy, HH:mm').format(date), 
                    style: TextStyle(fontSize: 12, color: AuthService().isGuest ? Colors.orange : null)
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId))),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
