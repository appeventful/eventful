import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_avatar.dart';
import '../../services/rating_service.dart';
import '../../utils/constants.dart';

class EventRatingSection extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final List participants;
  final Function(String targetUid, String eventTitle) onShowRatingDialog;
  final Function(double rating) onShowEventRatingDialog;

  const EventRatingSection({
    super.key,
    required this.eventId,
    required this.event,
    required this.participants,
    required this.onShowRatingDialog,
    required this.onShowEventRatingDialog,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Check if the event has started/passed
    final rawDate = event['eventDate'];
    DateTime eventDate;
    if (rawDate is Timestamp) {
      eventDate = rawDate.toDate();
    } else if (rawDate is String) {
      eventDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      eventDate = DateTime.now();
    }

    final bool hasStarted = DateTime.now().isAfter(eventDate);

    if (!hasStarted) {
      return const SizedBox.shrink();
    }
    
    // Creator + Participants, converted to Set to handle overlaps, then back to List
    Set<String> allToRateSet = {event['creatorId'], ...participants.cast<String>()};
    allToRateSet.remove(currentUser?.uid); // Don't rate yourself
    List<String> allToRate = allToRateSet.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allToRate.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star_outline, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Katılımcıları Puanla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('Katılımcıları oylayarak güven puanlarına katkıda bulunabilirsin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allToRate.length,
                    itemBuilder: (context, index) {
                      String targetUid = allToRate[index];
                      return StreamBuilder<DocumentSnapshot>(
                        stream: db.collection('ratings').doc('${eventId}_${currentUser!.uid}_$targetUid').snapshots(),
                        builder: (context, ratedSnap) {
                          bool alreadyRated = ratedSnap.hasData && ratedSnap.data!.exists;

                          return GestureDetector(
                            onTap: alreadyRated ? null : () => onShowRatingDialog(targetUid, event['title']),
                            behavior: HitTestBehavior.opaque,
                            child: Opacity(
                              opacity: alreadyRated ? 0.6 : 1.0,
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        FutureBuilder<DocumentSnapshot>(
                                          future: db.collection('users').doc(targetUid).get(),
                                          builder: (context, uSnap) {
                                            if (!uSnap.hasData || !uSnap.data!.exists) return const CustomAvatar(radius: 24);
                                            final user = UserModel.fromFirestore(uSnap.data!);

                                            final List<String> badgeIcons = user.badges.map((id) {
                                              final badge = availableBadges.firstWhere(
                                                (b) => b['id'] == id,
                                                orElse: () => {'icon': ''},
                                              );
                                              return badge['icon'] as String;
                                            }).where((icon) => icon.isNotEmpty).toList();

                                            return CustomAvatar(
                                              radius: 24,
                                              imageUrl: user.profileImage,
                                              isPassive: user.isFrozen || user.isDeleted,
                                              badgeIcons: badgeIcons,
                                            );
                                          },
                                        ),
                                        if (alreadyRated)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    FutureBuilder<DocumentSnapshot>(
                                      future: db.collection('users').doc(targetUid).get(),
                                      builder: (context, uSnap) {
                                        String name = '...';
                                        if (uSnap.hasData && uSnap.data!.exists) {
                                          final data = uSnap.data!.data() as Map<String, dynamic>;
                                          name = data['username'] ?? data['name'] ?? '...';
                                        }
                                        return Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: alreadyRated ? FontWeight.normal : FontWeight.bold,
                                            color: alreadyRated ? Colors.grey : Colors.black87
                                          ),
                                        );
                                      },
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        StreamBuilder<DocumentSnapshot>(
          stream: db.collection('event_ratings').doc('${eventId}_${currentUser!.uid}').snapshots(),
          builder: (context, snapshot) {
            bool alreadyRated = snapshot.hasData && snapshot.data!.exists;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('Etkinliği Puanla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const Spacer(),
                      if (alreadyRated)
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Etkinliği oylayarak "Öne Çıkanlar" algoritmasına katkıda bulunabilirsin.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  if (alreadyRated)
                    const Center(child: Text('Bu etkinliği puanladınız. Teşekkürler!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))
                  else
                    Center(
                      child: RatingBar.builder(
                        initialRating: 0,
                        minRating: 1,
                        direction: Axis.horizontal,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                        itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.blue),
                        onRatingUpdate: (rating) => onShowEventRatingDialog(rating),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
