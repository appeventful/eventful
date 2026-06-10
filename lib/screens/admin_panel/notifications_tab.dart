import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationsTab extends StatelessWidget {
  final VoidCallback onClearAll;

  const NotificationsTab({super.key, required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bildirim Geçmişi (Son 50)', style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(onPressed: onClearAll, icon: const Icon(Icons.delete_sweep, size: 18), label: const Text('Temizle')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('push_notifications').orderBy('createdAt', descending: true).limit(50).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              
              if (docs.isEmpty) return const Center(child: Text('Bildirim kaydı yok.'));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String status = data['status'] ?? 'pending';
                  Color color = status == 'sent' ? Colors.green : (status == 'error' ? Colors.red : Colors.orange);
                  
                  return ListTile(
                    leading: Icon(Icons.notification_important, color: color),
                    title: Text(data['notification']?['title'] ?? 'Başlıksız', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(data['notification']?['body'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                    trailing: Text(
                      data['createdAt'] != null ? DateFormat('HH:mm').format((data['createdAt'] as Timestamp).toDate()) : '',
                      style: const TextStyle(fontSize: 9),
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
