import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../widgets/custom_avatar.dart';
import 'package:intl/intl.dart';

class UserReviewsScreen extends StatelessWidget {
  final String targetUserId;
  final String targetUserName;

  const UserReviewsScreen({super.key, required this.targetUserId, required this.targetUserName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$targetUserName - Değerlendirmeler', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ratings')
            .where('targetUserId', isEqualTo: targetUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var reviews = snapshot.data?.docs ?? [];

          if (reviews.isEmpty) {
            return const Center(child: Text('Henüz değerlendirme yapılmamış.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              var review = reviews[index].data() as Map<String, dynamic>;
              double rating = (review['rating'] ?? 0).toDouble();
              DateTime date = (review['timestamp'] as Timestamp).toDate();
              String senderId = review['senderId'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
                builder: (context, userSnap) {
                  UserModel? sender;
                  if (userSnap.hasData && userSnap.data!.exists) {
                    sender = UserModel.fromFirestore(userSnap.data!);
                  }
                  final bool isPassive = sender?.isFrozen == true || sender?.isDeleted == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CustomAvatar(
                                imageUrl: sender?.profileImage ?? review['senderImage'], 
                                radius: 20,
                                isPassive: isPassive,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sender?.isDeleted == true ? 'Silinmiş Kullanıcı' : (sender?.name ?? review['senderName'] ?? 'Bilinmeyen Kullanıcı'), 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: isPassive ? TextDecoration.lineThrough : null,
                                        color: isPassive ? Colors.grey : Colors.black,
                                      )
                                    ),
                                    Text(DateFormat('dd.MM.yyyy HH:mm').format(date), 
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                    const Icon(Icons.star, color: Colors.orange, size: 16),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.event, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Etkinlik: ${review['eventTitle'] ?? 'Bilinmiyor'}', 
                                    style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(review['comment'] ?? 'Yorum yapılmadı.', 
                              style: const TextStyle(fontSize: 14, height: 1.4)),
                        ],
                      ),
                    ),
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}
