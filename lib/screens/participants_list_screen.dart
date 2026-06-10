import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';
import '../widgets/custom_avatar.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import 'profile_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';

class ParticipantsListScreen extends StatefulWidget {
  final String eventId;
  final bool isArchived;
  final bool showRequests;

  const ParticipantsListScreen({
    super.key,
    required this.eventId,
    this.isArchived = false,
    this.showRequests = false,
  });

  @override
  State<ParticipantsListScreen> createState() => _ParticipantsListScreenState();
}

class _ParticipantsListScreenState extends State<ParticipantsListScreen> {
  String? _currentUserRole;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserRole();
  }

  Future<void> _fetchCurrentUserRole() async {
    if (_currentUserId.isEmpty) return;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
    if (mounted) {
      setState(() {
        _currentUserRole = userDoc.data()?['role'] ?? 'user';
      });
    }
  }

  bool get _isAuthorized => _currentUserRole == 'admin' || _currentUserRole == 'moderator';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? kDeepCharcoal : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.showRequests 
            ? 'Katılım İstekleri' 
            : (widget.isArchived ? 'Katılımcı Geçmişi' : 'Katılımcı Listesi'), 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)
        ),
        backgroundColor: isDark ? kSurfaceDark : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, eventSnapshot) {
          if (eventSnapshot.hasError) return Center(child: Text('Bir hata oluştu.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)));
          if (!eventSnapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryOrange));

          var eventData = eventSnapshot.data!.data() as Map<String, dynamic>?;
          if (eventData == null) return Center(child: Text('Etkinlik bulunamadı.', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)));

          List listToShow = widget.showRequests 
              ? (eventData['pendingParticipants'] ?? []) 
              : (eventData['participants'] ?? []);

          if (listToShow.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.showRequests ? Icons.person_add_disabled_outlined : Icons.people_outline, 
                    size: 64, 
                    color: isDark ? Colors.white24 : Colors.grey[300]
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.showRequests ? 'Bekleyen istek bulunmuyor.' : 'Henüz katılımcı bulunmuyor.', 
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: listToShow.length,
            itemBuilder: (context, index) {
              String userId = listToShow[index];
              String creatorId = eventData['creatorId'] ?? '';
              
              bool canManageParticipants = _isAuthorized || _currentUserId == creatorId;
              // Don't allow removing the creator
              bool isTargetCreator = userId == creatorId;

              return _ParticipantTile(
                userId: userId, 
                eventId: widget.eventId,
                isRequest: widget.showRequests,
                showGhost: _isAuthorized || userId == _currentUserId || creatorId == _currentUserId,
                canManage: canManageParticipants && !isTargetCreator && !widget.showRequests,
              );
            },
          );
        },
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final String userId;
  final String eventId;
  final bool isRequest;
  final bool showGhost;
  final bool canManage;
  
  const _ParticipantTile({
    required this.userId, 
    required this.eventId,
    this.isRequest = false,
    required this.showGhost,
    this.canManage = false,
  });

  Future<void> _handleRequest(BuildContext context, bool accept) async {
    try {
      final db = FirebaseFirestore.instance;
      if (accept) {
        await db.collection('events').doc(eventId).update({
          'participants': FieldValue.arrayUnion([userId]),
          'pendingParticipants': FieldValue.arrayRemove([userId]),
          'joinedCount': FieldValue.increment(1)
        });
      } else {
        await db.collection('events').doc(eventId).update({
          'pendingParticipants': FieldValue.arrayRemove([userId]),
        });
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(accept ? 'İstek kabul edildi.' : 'İstek reddedildi.'))
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _removeParticipant(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? kSurfaceDark : Colors.white,
        title: Text('Katılımcıyı Çıkar', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text('Bu kullanıcıyı etkinlikten çıkarmak istediğinize emin misiniz?', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('İptal', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Çıkar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'participants': FieldValue.arrayRemove([userId]),
        'joinedCount': FieldValue.increment(-1)
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Katılımcı çıkarıldı.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
    Widget build(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const SizedBox.shrink();
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              leading: const CustomAvatar(),
              title: SizedBox(width: 100, height: 10, child: DecoratedBox(decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[200]))),
            ),
          );
        }

        final user = UserModel.fromFirestore(snapshot.data!);

        // Ghost mode kontrolü
        bool isGhost = user.isGhostMode;
        
        // Eğer kullanıcı hayalet moddaysa ve görüntüleyen kişi yetkili değilse kartı gizle
        if (isGhost && !showGhost) return const SizedBox.shrink();

        bool isPassive = user.isFrozen || user.isDeleted;

        final List<String> badgeIcons = user.badges.map((id) {
          final badge = availableBadges.firstWhere(
            (b) => b['id'] == id,
            orElse: () => {'icon': ''},
          );
          return badge['icon'] as String;
        }).where((icon) => icon.isNotEmpty).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isGhost ? Colors.blueGrey.withValues(alpha: 0.1) : (isPassive ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100]) : (isDark ? kSurfaceDark : Colors.white)),
            borderRadius: BorderRadius.circular(15),
            border: isGhost ? Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Stack(
              children: [
                CustomAvatar(
                  radius: 28,
                  backgroundColor: isGhost ? Colors.blueGrey.withValues(alpha: 0.2) : kPrimaryOrange.withValues(alpha: 0.1),
                  imageUrl: user.profileImage,
                  placeholderIcon: Icons.visibility_off,
                  iconColor: Colors.blueGrey,
                  isPassive: isPassive,
                  badgeIcons: badgeIcons,
                ),
                if (isGhost)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle),
                      child: const Icon(Icons.visibility_off_rounded, size: 12, color: Colors.white),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    user.isDeleted ? 'Silinmiş Kullanıcı' : user.name, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 15,
                      color: isPassive ? (isDark ? Colors.white38 : Colors.grey) : (isDark ? Colors.white : Colors.black),
                      decoration: isPassive ? TextDecoration.lineThrough : null,
                    ), 
                    overflow: TextOverflow.ellipsis
                  )
                ),
                if (user.isFounder && !isPassive) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.stars_rounded, size: 16, color: Colors.amber),
                ],
                if (user.role == 'admin' && !isPassive) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.workspace_premium_rounded, size: 18, color: Colors.blueAccent),
                ] else if (user.role == 'moderator' && !isPassive) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.shield_rounded, size: 16, color: Colors.purpleAccent),
                ],
                if (isGhost)
                  const Text(' (Hayalet)', style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold)),
                if (user.isDeleted)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('(Silindi)', style: TextStyle(fontSize: 11, color: Colors.red.shade300, fontWeight: FontWeight.bold)),
                  )
                else if (user.isFrozen)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text('(Pasif)', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Text(
              user.isDeleted ? 'Hesap silindi.' : user.bio,
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
            ),
            trailing: isRequest 
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                      onPressed: () => _handleRequest(context, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.redAccent),
                      onPressed: () => _handleRequest(context, false),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canManage)
                      IconButton(
                        icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                        onPressed: () => _removeParticipant(context),
                      ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_ios, size: 14, color: kPrimaryOrange),
                    ),
                  ],
                ),
            onTap: isRequest ? null : () {
              if (AuthService().isGuest) {
                GuestGuardDialog.show(context, "Profil görüntüleme");
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(otherUserId: userId),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
