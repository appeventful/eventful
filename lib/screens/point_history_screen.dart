import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_avatar.dart';

class PointHistoryScreen extends StatelessWidget {
  const PointHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Puan Geçmişi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: uid == null
          ? const Center(child: Text('Giriş yapmalısınız'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('pointHistory')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Henüz puan hareketi yok.'));
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    int amount = data['amount'] ?? 0;
                    String reason = data['reason'] ?? 'Bilinmiyor';
                    dynamic rawTimestamp = data['timestamp'];
                    DateTime? date;
                    if (rawTimestamp is Timestamp) {
                      date = rawTimestamp.toDate();
                    } else if (rawTimestamp is String) {
                      date = DateTime.tryParse(rawTimestamp);
                    }
                    String formattedDate = date != null ? DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(date) : '';

                    return ListTile(
                      leading: CustomAvatar(
                        backgroundColor: amount > 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                        placeholderIcon: amount > 0 ? Icons.add : Icons.remove,
                        iconColor: amount > 0 ? Colors.green : Colors.red,
                      ),
                      title: Text(reason, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(formattedDate),
                      trailing: Text(
                        '${amount > 0 ? '+' : ''}$amount',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: amount > 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
