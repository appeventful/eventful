import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/event_model.dart';
import '../../screens/event_detail_screen.dart';
import '../../utils/image_constants.dart';
import '../shimmer_effect.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class TrendingSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final List<String> userInterests;
  final Map<String, Map<String, dynamic>> processedData;

  const TrendingSection({
    super.key,
    required this.docs,
    required this.userInterests,
    required this.processedData,
  });

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const SizedBox.shrink();

    var trendingDocs = List<QueryDocumentSnapshot>.from(docs);
    trendingDocs.sort((a, b) {
      final aMeta = processedData[a.id]!;
      final bMeta = processedData[b.id]!;
      
      double aScore = aMeta['trendingScore'] ?? 0.0;
      double bScore = bMeta['trendingScore'] ?? 0.0;

      // Personalized boost
      if (userInterests.contains(aMeta['category'])) aScore += 0.5;
      if (userInterests.contains(bMeta['category'])) bScore += 0.5;
      
      return bScore.compareTo(aScore);
    });

    var topTrending = trendingDocs.take(5).toList();

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_graph_rounded, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Öne Çıkanlar',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: topTrending.length,
              cacheExtent: 500,
              itemBuilder: (context, index) {
                final event = EventModel.fromFirestore(topTrending[index]);
                return _TrendingCard(event: event);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 32, 20, 16),
            child: Text(
              'Tüm Etkinlikler',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final EventModel event;
  const _TrendingCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: event.id)),
      ),
      child: Container(
        width: 300,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              CachedNetworkImage(
                imageUrl: event.imageUrl.isNotEmpty ? event.imageUrl : ImageConstants.defaultEventImage,
                height: double.infinity,
                width: double.infinity,
                fit: BoxFit.cover,
                memCacheHeight: 600,
                maxWidthDiskCache: 1000,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const ShimmerEffect(
                    child: Center(
                      child: Icon(Icons.image, color: Colors.white, size: 40),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.orange.shade800,
                  child: const Icon(Icons.image_not_supported, color: Colors.white, size: 40),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event.category.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            event.averageRating == 0 ? "YENİ" : event.averageRating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _TrendingCountdownChip(eventDate: event.eventDate),
                  ],
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _TrendingSocialProof(participants: event.participants),
                        const Spacer(),
                        _TrendingQuickJoinButton(event: event),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingCountdownChip extends StatelessWidget {
  final DateTime eventDate;
  const _TrendingCountdownChip({required this.eventDate});

  @override
  Widget build(BuildContext context) {
    if (AuthService().isGuest) return const SizedBox.shrink();

    DateTime now = DateTime.now();
    Duration diff = eventDate.difference(now);

    if (diff.isNegative || diff.inHours > 24) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '${diff.inHours}sa ${diff.inMinutes % 60}dk kaldı',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _TrendingSocialProof extends StatelessWidget {
  final List<String> participants;
  const _TrendingSocialProof({required this.participants});

  @override
  Widget build(BuildContext context) {
    int count = participants.length;
    if (count == 0) {
      return const Row(
        children: [
          Icon(Icons.people_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            'İlk sen katıl!',
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        SizedBox(
          width: count > 3 ? 60 : count * 20.0,
          height: 25,
          child: Stack(
            children: List.generate(count > 3 ? 3 : count, (index) {
              return Positioned(
                left: index * 15.0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.orange.shade200,
                    child: Text('${index + 1}', style: const TextStyle(fontSize: 8, color: Colors.black)),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$count kişi gidiyor',
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _TrendingQuickJoinButton extends StatefulWidget {
  final EventModel event;
  const _TrendingQuickJoinButton({required this.event});

  @override
  State<_TrendingQuickJoinButton> createState() => _TrendingQuickJoinButtonState();
}

class _TrendingQuickJoinButtonState extends State<_TrendingQuickJoinButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    bool isJoined = widget.event.participants.contains(uid);

    return InkWell(
      onTap: _isLoading ? null : () => _handleQuickJoin(context, uid),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isJoined ? Colors.green.withValues(alpha: 0.9) : Colors.orange.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else
              Icon(isJoined ? Icons.check : Icons.add, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              isJoined ? 'Katıldın' : 'Katıl',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _handleQuickJoin(BuildContext context, String? uid) async {
    if (uid == null) return;

    if (widget.event.participants.contains(uid)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaten katıldınız. Detaylar için karta tıklayın.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('events').doc(widget.event.id).update({
        'participants': FieldValue.arrayUnion([uid]),
        'joinedCount': FieldValue.increment(1),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Başarıyla katıldınız!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
