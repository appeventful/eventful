import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/constants.dart';

class EventPhotosSection extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final bool canModerate;
  final Function(Map<String, dynamic> event) onUploadPhoto;
  final Function(Map<String, dynamic> photo, String photoId, bool canModerate) onViewPhoto;

  const EventPhotosSection({
    super.key,
    required this.eventId,
    required this.event,
    required this.canModerate,
    required this.onUploadPhoto,
    required this.onViewPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Etkinlik Fotoğrafları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: () => onUploadPhoto(event),
              icon: const Icon(Icons.add_a_photo, size: 18, color: Colors.orange),
              label: const Text('Fotoğraf Ekle', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: (() {
            Query query = db.collection('events').doc(eventId).collection('photos');
            if (!canModerate) {
              query = query.where('status', isEqualTo: 'approved');
            }
            return query.orderBy('timestamp', descending: true).snapshots();
          })(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Photos Stream Error: ${snapshot.error}');
              if (snapshot.error.toString().contains('index')) {
                return StreamBuilder<QuerySnapshot>(
                  stream: db.collection('events').doc(eventId).collection('photos').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, fallbackSnap) {
                    if (fallbackSnap.hasData) {
                      return _buildPhotoList(context, fallbackSnap.data!.docs, canModerate);
                    }
                    return const SizedBox.shrink();
                  },
                );
              }
              return const Center(child: Text('Henüz onaylanmış fotoğraf bulunmuyor.', style: TextStyle(fontSize: 12, color: Colors.grey)));
            }
            if (!snapshot.hasData) return const SizedBox.shrink();

            return _buildPhotoList(context, snapshot.data!.docs, canModerate);
          },
        ),
      ],
    );
  }

  Widget _buildPhotoList(BuildContext context, List<QueryDocumentSnapshot> photos, bool canModerate) {
    if (photos.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Center(child: Text('Henüz fotoğraf paylaşılmamış.', style: TextStyle(color: Colors.grey, fontSize: 13))),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        itemExtent: 132,
        itemBuilder: (context, index) {
          var photo = photos[index].data() as Map<String, dynamic>;
          bool isPending = photo['status'] == 'pending';
          bool isRejected = photo['status'] == 'rejected';

          return GestureDetector(
            onTap: () => onViewPhoto(photo, photos[index].id, canModerate),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: photo['url'],
                      fit: BoxFit.cover,
                      memCacheWidth: 360,
                      placeholder: (context, url) => Container(color: Colors.grey[200]),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                    ),
                    if (isPending || isRejected)
                      Container(
                        color: Colors.black45,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRejected ? Colors.red : Colors.orange,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isRejected ? 'Reddedildi' : 'Onay Bekliyor',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
