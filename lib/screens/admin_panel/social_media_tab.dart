import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/social_service.dart';
import '../../utils/constants.dart';

class SocialMediaTab extends StatelessWidget {
  final VoidCallback onShowWeeklySummary;
  final VoidCallback onShowDailyAgenda;
  final VoidCallback onShowSocialKit;
  final Function({Map<String, dynamic>? photoData, String? photoId}) onShowSchedulePost;

  const SocialMediaTab({
    super.key,
    required this.onShowWeeklySummary,
    required this.onShowDailyAgenda,
    required this.onShowSocialKit,
    required this.onShowSchedulePost,
  });

  @override
  Widget build(BuildContext context) {
    final SocialService socialService = SocialService();
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Görsel Oluşturucu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _imageActionCard('Haftalık Özet', Icons.view_carousel, Colors.purple, onShowWeeklySummary),
              _imageActionCard('Günlük Ajanda', Icons.today, Colors.orange, onShowDailyAgenda),
              _imageActionCard('Etkinlik Kiti', Icons.card_giftcard, Colors.blue, onShowSocialKit),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text('Haftanın Fotoğrafları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: db.collection('events').where('isFeatured', isEqualTo: true).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var photos = snapshot.data!.docs;
            if (photos.isEmpty) return const Text('Öne çıkan fotoğraf yok.');

            return SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  var data = photos[index].data() as Map<String, dynamic>;
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(image: NetworkImage(data['imageUrl'] ?? ''), fit: BoxFit.cover),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            color: Colors.black54,
                            child: IconButton(
                              icon: const Icon(Icons.share, color: Colors.white, size: 20),
                              onPressed: () => onShowSchedulePost(photoData: data, photoId: photos[index].id),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Instagram Planlayıcı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () => onShowSchedulePost(), child: const Text('Yeni Plan')),
          ],
        ),
        StreamBuilder<QuerySnapshot>(
          stream: socialService.getScheduledPosts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            var posts = snapshot.data!.docs;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                var post = posts[index].data() as Map<String, dynamic>;
                DateTime date = (post['scheduledAt'] as Timestamp).toDate();
                return Card(
                  child: ListTile(
                    leading: Icon(post['type'] == 'event' ? Icons.event : Icons.photo),
                    title: Text(post['caption'] ?? 'Paylaşım', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(DateFormat('dd.MM HH:mm').format(date)),
                    trailing: IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: () async {
                        await Share.share(post['caption'] ?? '');
                        await socialService.updatePostStatus(posts[index].id, 'posted');
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _imageActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
