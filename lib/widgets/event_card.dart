import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event_model.dart';
import '../screens/event_detail_screen.dart';
import '../utils/image_constants.dart';
import 'shimmer_effect.dart';
import 'custom_avatar.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'guest_guard_dialog.dart';

class EventCard extends StatelessWidget {
  final EventModel event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final bool isJoined = event.participants.contains(FirebaseAuth.instance.currentUser?.uid);

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: event.id)),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: event.imageUrl.isNotEmpty ? event.imageUrl : ImageConstants.defaultEventImage,
                      height: 180, // Biraz daha geniş ve ferah bir alan
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheHeight: 450, // Resmi belleğe alırken boyutunu küçültür (RAM tasarrufu)
                      maxWidthDiskCache: 900,
                      placeholder: (context, url) => ShimmerEffect(
                        child: Container(
                          height: 180,
                          color: Colors.white,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 180,
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[200],
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported, color: Colors.grey),
                            SizedBox(height: 4),
                            Text('Resim yüklenemedi', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (event.isPinned)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.push_pin, color: Colors.white, size: 18),
                      ),
                    ),
                  if (isJoined)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Katıldın',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (event.averageRating > 0)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              event.averageRating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (!event.isApproved)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Onay Bekliyor',
                                  style: TextStyle(
                                    color: Colors.red.shade900,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (event.source != null)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200, width: 0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.link, size: 10, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      event.source!,
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1), 
                                borderRadius: BorderRadius.circular(8)
                              ),
                              child: Text(event.category, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            if (event.source == null) _buildCreatorInfo(context, event.creatorId),
                          ],
                        ),
                        Text(
                          AuthService().isGuest 
                            ? 'Görmek için üye ol' 
                            : DateFormat('dd MMM, HH:mm', 'tr_TR').format(event.eventDate), 
                          style: TextStyle(
                            color: AuthService().isGuest ? Colors.orange : Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12, 
                            fontWeight: FontWeight.w500
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(event.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Expanded(child: Text('${event.city} - ${event.address}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.people_alt_outlined, size: 16, color: Colors.orange.shade700),
                            const SizedBox(width: 4),
                            Text(
                              '${event.participants.length} Katılımcı',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
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

  // Kullanıcı bilgilerini bellekte tutmak için basit bir cache
  static final Map<String, DocumentSnapshot> _userCache = {};

  Widget _buildCreatorInfo(BuildContext context, String creatorId) {
    if (_userCache.containsKey(creatorId)) {
      return _buildCreatorRow(context, _userCache[creatorId]!);
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(creatorId).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
        
        // Veriyi cache'e ekle
        _userCache[creatorId] = userSnap.data!;
        
        return _buildCreatorRow(context, userSnap.data!);
      },
    );
  }

  Widget _buildCreatorRow(BuildContext context, DocumentSnapshot doc) {
    final user = UserModel.fromFirestore(doc);
    final bool isPassive = user.isFrozen || user.isDeleted;

    final List<String> badgeIcons = user.badges.map((badgeId) {
      final badge = availableBadges.firstWhere(
        (b) => b['id'] == badgeId,
        orElse: () => <String, dynamic>{},
      );
      return badge['icon'] as String? ?? '';
    }).where((icon) => icon.isNotEmpty).toList();

    return Row(
      children: [
        CustomAvatar(
          radius: 10,
          imageUrl: user.profileImage,
          isPassive: isPassive,
          badgeIcons: badgeIcons,
        ),
        const SizedBox(width: 4),
        Text(
          user.username.isNotEmpty ? '@${user.username}' : user.name.split(' ').first,
          style: TextStyle(
            fontSize: 11, 
            color: isPassive ? Colors.grey : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700]),
            fontWeight: FontWeight.w500,
            decoration: isPassive ? TextDecoration.lineThrough : null,
          ),
        ),
        if (user.isDeleted)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('(Silindi)', style: TextStyle(fontSize: 9, color: Colors.red.shade300, fontWeight: FontWeight.bold)),
          )
        else if (user.isFrozen)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('(Pasif)', style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
