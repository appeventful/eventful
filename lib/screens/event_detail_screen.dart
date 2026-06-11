import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/user_model.dart';
import '../widgets/custom_avatar.dart';
import '../widgets/shimmer_effect.dart';
import 'profile_screen.dart';
import 'edit_event_screen.dart';
import 'participants_list_screen.dart';
import '../services/rating_service.dart';
import '../services/score_service.dart';
import '../services/score_service.dart';
import '../services/comment_service.dart';
import '../utils/sharing_templates.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../utils/constants.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'qr_scanner_screen.dart';
import 'dart:math';

// Extracted Widgets
import '../widgets/event_detail/event_comments_section.dart';
import '../widgets/event_detail/event_management_panel.dart';
import '../widgets/event_detail/event_rating_section.dart';
import '../widgets/event_detail/event_photos_section.dart';
import '../widgets/event_detail/event_join_section.dart';
import '../widgets/event_detail/event_reference_section.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  final String? initialCode;
  const EventDetailScreen({super.key, required this.eventId, this.initialCode});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  final CommentService _commentService = CommentService();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _refCodeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _chatKey = GlobalKey();
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showSuggestions = false;
  String? _replyToId;
  String? _replyToName;
  String? _editingCommentId;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _refCodeController.text = widget.initialCode!;
    }
    _commentController.addListener(_onCommentChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    _refCodeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _shareEvent(Map<String, dynamic> event) {
    final String title = event['title'] ?? 'Etkinlik';
    final String eventUrl = "https://eventfulapp.org/event/${widget.eventId}";
    final String shareText = SharingTemplates.eventForInstagramStory(event);
    
    Share.share(
      '$shareText\n\nDetaylar: $eventUrl',
      subject: title,
    );
  }

  void _requestReferenceHelp(Map<String, dynamic> event) async {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yardım Talebi Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Diğer katılımcıların size referans olabilmesi için kısa bir açıklama yazın.', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Neden katılmak istiyorsunuz?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir neden belirtin.')));
                return;
              }
              
              Navigator.pop(context);
              
              try {
                // Check if already requested
                var existing = await db.collection('reference_requests')
                    .where('userId', isEqualTo: currentUser?.uid)
                    .where('eventId', isEqualTo: widget.eventId)
                    .where('status', isEqualTo: 'open')
                    .get();
                
                if (existing.docs.isNotEmpty) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaten bu etkinlik için açık bir talebiniz bulunuyor.')));
                  return;
                }

                var userDoc = await db.collection('users').doc(currentUser?.uid).get();
                var user = UserModel.fromFirestore(userDoc);

                var rawEventDate = event['eventDate'];
                Timestamp? eventTimestamp;
                if (rawEventDate is Timestamp) {
                  eventTimestamp = rawEventDate;
                } else if (rawEventDate is String) {
                  DateTime? dt = DateTime.tryParse(rawEventDate);
                  if (dt != null) eventTimestamp = Timestamp.fromDate(dt);
                }

                await db.collection('reference_requests').add({
                  'userId': user.uid,
                  'userName': user.name,
                  'username': user.username,
                  'userImage': user.profileImage,
                  'eventId': widget.eventId,
                  'eventTitle': event['title'],
                  'eventDate': eventTimestamp,
                  'reason': reasonController.text.trim(),
                  'status': 'open',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Talebiniz Yardımlaşma Merkezi\'ne gönderildi!'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  void _onCommentChanged() {
    String text = _commentController.text;
    int cursorPosition = _commentController.selection.baseOffset;

    if (cursorPosition > 0) {
      String textBeforeCursor = text.substring(0, cursorPosition);
      int lastAtSign = textBeforeCursor.lastIndexOf('@');

      if (lastAtSign != -1 && (lastAtSign == 0 || textBeforeCursor[lastAtSign - 1] == ' ')) {
        String query = textBeforeCursor.substring(lastAtSign + 1).toLowerCase();
        _updateSuggestions(query);
      } else {
        if (_showSuggestions) {
          setState(() => _showSuggestions = false);
        }
      }
    } else {
      if (_showSuggestions) {
        setState(() => _showSuggestions = false);
      }
    }
  }

  void _updateSuggestions(String query) async {
    try {
      var eventDoc = await db.collection('events').doc(widget.eventId).get();
      if (!eventDoc.exists) return;
      
      List participantsUids = eventDoc.data()?['participants'] ?? [];
      String creatorId = eventDoc.data()?['creatorId'] ?? '';
      if (!participantsUids.contains(creatorId)) {
        participantsUids.add(creatorId);
      }

      // Filter by name if query is not empty
      List<Map<String, dynamic>> suggestions = [];
      
      // Add "herkes" option for admins/mods/creators
      bool isAdmin = currentUser?.email == 'fatihkull17@gmail.com';
      var userDoc = await db.collection('users').doc(currentUser?.uid).get();
      bool isModerator = userDoc.exists && userDoc.data()?['role'] == 'moderator';
      bool isCreator = creatorId == currentUser?.uid;

      if (isAdmin || isModerator || isCreator) {
        if ('herkes'.contains(query) || query.isEmpty) {
          suggestions.add({'name': 'herkes', 'uid': 'all', 'isSpecial': true});
        }
      }

      // Fetch participants details
      for (String uid in participantsUids) {
        var uDoc = await db.collection('users').doc(uid).get();
        if (uDoc.exists) {
          String name = uDoc.data()?['username'] ?? uDoc.data()?['name'] ?? '';
          if (name.toLowerCase().contains(query) && uid != currentUser?.uid) {
            suggestions.add({'name': name, 'uid': uid, 'isSpecial': false});
          }
        }
      }

      if (mounted) {
        setState(() {
          _mentionSuggestions = suggestions;
          _showSuggestions = suggestions.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error updating suggestions: $e");
    }
  }

  void _selectMention(Map<String, dynamic> suggestion) {
    String text = _commentController.text;
    int cursorPosition = _commentController.selection.baseOffset;
    int lastAtSign = text.substring(0, cursorPosition).lastIndexOf('@');

    String newText = text.replaceRange(lastAtSign, cursorPosition, '@${suggestion['name']} ');
    _commentController.text = newText;
    _commentController.selection = TextSelection.fromPosition(TextSelection.fromPosition(TextPosition(offset: lastAtSign + (suggestion['name'] as String).length + 2)).extent);
    
    setState(() => _showSuggestions = false);
  }

  void _openMap(String? address, String? locationName) async {
    final query = address ?? locationName;
    if (query == null || query.isEmpty) return;
    
    final encodedQuery = Uri.encodeComponent(query);
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedQuery';
    final appleMapsUrl = 'https://maps.apple.com/?q=$encodedQuery';

    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(Uri.parse(appleMapsUrl))) {
      await launchUrl(Uri.parse(appleMapsUrl), mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harita uygulaması açılamadı.')));
    }
  }

  Widget _buildMiniMap(double lat, double lng, String title) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15,
          ),
          markers: {
            Marker(
              markerId: const MarkerId('event_location'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(title: title),
            ),
          },
          liteModeEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onTap: (_) => _openMapInApp(lat, lng, title),
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return Scaffold(
      body: ShimmerEffect(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSkeletonBox(height: 300, width: double.infinity, radius: 0),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildSkeletonBox(height: 25, width: 80, radius: 20),
                        const Spacer(),
                        _buildSkeletonBox(height: 25, width: 120, radius: 10),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSkeletonBox(height: 35, width: 250, radius: 8),
                    const SizedBox(height: 12),
                    _buildSkeletonBox(height: 20, width: 200, radius: 4),
                    const SizedBox(height: 24),
                    _buildSkeletonBox(height: 180, width: double.infinity, radius: 16),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildSkeletonBox(height: 44, width: 44, radius: 22),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSkeletonBox(height: 15, width: 120, radius: 4),
                            const SizedBox(height: 4),
                            _buildSkeletonBox(height: 10, width: 80, radius: 4),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildSkeletonBox(height: 25, width: 150, radius: 4),
                    const SizedBox(height: 12),
                    _buildSkeletonBox(height: 100, width: double.infinity, radius: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonBox({required double height, required double width, double radius = 12}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  void _openMapInApp(double lat, double lng, String title) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('events').doc(widget.eventId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return _buildSkeletonLoading();
        }
        
        if (snapshot.hasError) {
          debugPrint('Firestore Stream Error: ${snapshot.error}');
          return Scaffold(body: Center(child: Text('Bir bağlantı hatası oluştu: ${snapshot.error}')));
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Etkinlik bulunamadı veya silinmiş.')));
        }
        
        var event = snapshot.data!.data() as Map<String, dynamic>;
        List participants = event['participants'] ?? [];
        List pending = event['pendingParticipants'] ?? [];
        bool isCreator = event['creatorId'] == currentUser?.uid;
        bool isJoined = participants.contains(currentUser?.uid);
        bool isPending = pending.contains(currentUser?.uid);
        final rawDate = event['eventDate'];
        DateTime date;
        if (rawDate is Timestamp) {
          date = rawDate.toDate();
        } else if (rawDate is String) {
          date = DateTime.tryParse(rawDate) ?? DateTime.now();
        } else {
          date = DateTime.now();
        }
        bool canSeeComments = isJoined || isCreator;
        bool isChatReadOnly = event['isChatReadOnly'] ?? false;
        bool isAdmin = currentUser?.email == 'fatihkull17@gmail.com';
        bool hasStaffPrivileges = isAdmin || isCreator;
        
        // Etkinliğin gerçekten bitip bitmediğini kontrol et (Saat + 3 saat süre)
        bool isPast = date.add(const Duration(hours: 3)).isBefore(DateTime.now());
        bool isChatLocked = DateTime.now().isAfter(date.add(const Duration(hours: 24)));

        // Düzenleme Süresi Kuralları
        Duration timeUntilEvent = date.difference(DateTime.now());
        bool canEditBasedOnTime = false;
        
        if (isAdmin || (event['role'] == 'moderator')) {
          // Admin ve Moderatörler 30 dakikaya kadar düzenleyebilir
          canEditBasedOnTime = timeUntilEvent.inMinutes > 30;
        } else {
          // Normal kullanıcılar (Düzenleyici) 2 saate kadar düzenleyebilir
          canEditBasedOnTime = timeUntilEvent.inHours > 2;
        }

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: (event['imageUrl'] != null && 
                                  event['imageUrl'].toString().isNotEmpty && 
                                  event['imageUrl'].toString() != "null")
                            ? event['imageUrl'] 
                            : 'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=800',
                        fit: BoxFit.cover,
                        memCacheWidth: 800, // RAM kullanımını optimize et
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.error),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                          ),
                        ),
                      ),
                      if (isPast)
                        Positioned(
                          top: 100,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'BU ETKİNLİK BİTTİ',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  if (!AuthService().isGuest)
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () => _shareEvent(event),
                    ),
                  if (hasStaffPrivileges && canEditBasedOnTime)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EditEventScreen(eventId: widget.eventId, eventData: event))),
                    ),
                  if (hasStaffPrivileges)
                    IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _confirmDelete),
                  if (!hasStaffPrivileges)
                    IconButton(
                      icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.white),
                      onPressed: () => _showEventReportDialog(event),
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildCategoryBadge(event['category']),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month, size: 14, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  AuthService().isGuest 
                                    ? 'Görmek için üye ol' 
                                    : DateFormat('dd MMM, HH:mm', 'tr_TR').format(date), 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(event['title'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _openMap(event['address'], event['locationName']),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.location_on, size: 18, color: Colors.orange),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event['address'] ?? event['locationName'] ?? 'Konum belirtilmedi',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, decoration: TextDecoration.underline),
                                  ),
                                  Text('Etkinlik Yeri (Haritada Gör)', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (event['latitude'] != null && event['longitude'] != null) ...[
                        _buildMiniMap(event['latitude'], event['longitude'], event['title']),
                        const SizedBox(height: 24),
                      ],
                      Row(
                        children: [
                          FutureBuilder<DocumentSnapshot>(
                            future: db.collection('users').doc(event['creatorId']).get(),
                            builder: (context, userSnap) {
                              if (!userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();

                              final user = UserModel.fromFirestore(userSnap.data!);
                              final bool isPassive = user.isFrozen || user.isDeleted;

                              return GestureDetector(
                                onTap: () {
                                  if (AuthService().isGuest) {
                                    GuestGuardDialog.show(context, "Profil görüntüleme");
                                    return;
                                  }
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(otherUserId: event['creatorId'])));
                                },
                                child: Row(
                                  children: [
                                    CustomAvatar(
                                      radius: 22,
                                      imageUrl: user.profileImage,
                                      isPassive: isPassive,
                                      badgeIcons: user.badges.map((id) {
                                        final badge = availableBadges.firstWhere(
                                          (b) => b['id'] == id,
                                          orElse: () => {'icon': ''},
                                        );
                                        return badge['icon'] as String;
                                      }).where((icon) => icon.isNotEmpty).toList(),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              user.isDeleted ? 'Silinmiş Kullanıcı' : user.name, 
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 16,
                                                color: isPassive ? Colors.grey : Theme.of(context).textTheme.titleMedium?.color,
                                                decoration: isPassive ? TextDecoration.lineThrough : null,
                                              )
                                            ),
                                            if (user.isDeleted)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 6),
                                                child: Text('(Silindi)', style: TextStyle(fontSize: 10, color: Colors.red.shade300, fontWeight: FontWeight.bold)),
                                              )
                                            else if (user.isFrozen)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 6),
                                                child: Text('(Pasif)', style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        const Text('Organizatör', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text('Etkinlik Hakkında', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        event['description'],
                        style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5),
                      ),
                      if ((event['externalSource'] == true || event['externalLink'] != null) && (event['link'] ?? event['externalLink']) != null && (event['link'] ?? event['externalLink']).toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final url = Uri.parse(event['link'] ?? event['externalLink']);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Orijinal Kaynağa Git'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                      if (event['requirements'] != null && event['requirements'].toString().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Katılım Şartı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red)),
                                    Text(event['requirements'], style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodyMedium?.color)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      _buildEventStats(event),
                      const SizedBox(height: 30),
                    _buildPublicParticipantsList(participants),
                    const SizedBox(height: 30),

                    if ((isJoined || isCreator) && !isPast) ...[
                        EventReferenceSection(
                          eventId: widget.eventId,
                          isCreator: isCreator,
                          onProvideReference: _provideReferenceToUser,
                          onConfirmGenerateRefCode: _confirmGenerateRefCode,
                        ),
                        const SizedBox(height: 30),
                      ],

                      if (isCreator) ...[
                        EventManagementPanel(
                          eventId: widget.eventId,
                          event: event,
                          participants: participants,
                          pending: pending,
                          date: date,
                          isPast: isPast,
                          onGenerateRefCode: _confirmGenerateRefCode,
                          onHandleQRAction: _handleQRAction,
                          onApproveUser: _approveUser,
                          onRejectUser: _rejectUser,
                          onRemoveUser: _removeUser,
                          onTransferOwnership: _transferOwnership,
                        ),
                        const SizedBox(height: 30),
                      ],

                      if ((isJoined || isCreator)) ...[
                        EventPhotosSection(
                          eventId: widget.eventId,
                          event: event,
                          canModerate: hasStaffPrivileges,
                          onUploadPhoto: _uploadPhoto,
                          onViewPhoto: _viewPhoto,
                        ),
                        const SizedBox(height: 30),
                      ],

                      if ((isJoined || isCreator)) ...[
                        EventRatingSection(
                          eventId: widget.eventId,
                          event: event,
                          participants: participants,
                          onShowRatingDialog: _showRatingDialog,
                          onShowEventRatingDialog: _showEventRatingDialog,
                        ),
                        const SizedBox(height: 30),
                      ],

                      if (!isCreator && !isPast) ...[
                        if (isJoined) ...[
                          ElevatedButton(
                            onPressed: _leaveEvent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red,
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Etkinlikten Ayrıl', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ]
                        else if (isPending)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade100)),
                            child: Column(
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.hourglass_empty, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text('Katılım isteği onay bekliyor', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextButton(onPressed: _cancelJoinRequest, child: const Text('İsteği İptal Et', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          )
                        else
                          EventJoinSection(
                            eventId: widget.eventId,
                            event: event,
                            refCodeController: _refCodeController,
                            onRequestReferenceHelp: _requestReferenceHelp,
                          ),
                        if (isJoined && !isCreator && !isPast) ...[
                          const SizedBox(height: 12),
                          if (DateTime.now().isAfter(date.subtract(const Duration(hours: 1))))
                            ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => QRScannerScreen(
                                  eventId: widget.eventId,
                                  correctSecret: event['qrCodeSecret'] ?? widget.eventId,
                                ))
                              ),
                              icon: const Icon(Icons.qr_code_scanner),
                              label: const Text('QR Yoklama Okut (Puan Kazan)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                        ],
                        const SizedBox(height: 30),
                      ],

                      Row(
                        key: _chatKey,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('Etkinlik Sohbeti', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Icon(Icons.chat_bubble_outline, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (canSeeComments) ...[
                        _buildPinnedMessage(event),
                        if (isChatLocked)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Icon(Icons.lock_clock_outlined, size: 16, color: Theme.of(context).hintColor),
                                const SizedBox(width: 8),
                                Expanded(child: Text('Bu sohbet etkinlik bitiminden 24 saat geçtiği için kapanmıştır.', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor))),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (canSeeComments)
                StreamBuilder<QuerySnapshot>(
                  stream: db.collection('events').doc(widget.eventId).collection('comments').orderBy('timestamp', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    return EventCommentsSection(
                      eventId: widget.eventId,
                      eventData: event,
                      hasStaff: hasStaffPrivileges,
                      isCreatorUser: isCreator,
                      snapshot: snapshot,
                      onShowCommentOptions: _showCommentOptions,
                      onToggleReaction: _toggleReaction,
                      onShowReactionDetails: _showReactionDetails,
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (!canSeeComments)
                        Container(
                          padding: const EdgeInsets.all(30),
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.lock_outline, size: 40, color: Theme.of(context).hintColor.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text('Sohbeti görmek için bu etkinliğe katılmalısınız.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      if (event['externalSource'] == true) ...[
                        const Divider(),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Veri kaynağı: ',
                                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500, fontSize: 10),
                                ),
                                CachedNetworkImage(
                                  imageUrl: 'https://etkinlik.io/images/logo.png',
                                  height: 10,
                                  memCacheHeight: 40,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : null,
                                  errorWidget: (c, e, s) => Text(
                                    'etkinlik.io',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 150),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomSheet: canSeeComments && !isChatReadOnly && !isChatLocked ? _buildCommentInputArea() : null,
        );
      },
    );
  }

  Widget _buildCategoryBadge(String? category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(category ?? 'Genel', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildEventStats(Map<String, dynamic> event) {
    int current = (event['participants'] as List).length;
    int quota = event['quota'] ?? 0;
    String participantsStr = quota > 0 ? '$current / $quota' : '$current';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.people_alt_outlined, participantsStr, 'Katılımcı'),
          _buildStatItem(Icons.star_outline, (event['rating'] ?? 0.0).toStringAsFixed(1), 'Puan'),
          _buildStatItem(Icons.comment_outlined, (event['commentCount'] ?? 0).toString(), 'Mesaj'),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.orange, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }


  Widget _buildPinnedMessage(Map<String, dynamic> eventData) {
    String? pinnedId = eventData['pinnedCommentId'];
    if (pinnedId == null) return const SizedBox.shrink();

    return FutureBuilder<DocumentSnapshot>(
      future: db.collection('events').doc(widget.eventId).collection('comments').doc(pinnedId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        var comment = snapshot.data!.data() as Map<String, dynamic>;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.push_pin, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text(
                    'SABİTLENMİŞ MESAJ - ${comment['userName'] ?? 'Anonim'}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(comment['text'] ?? '', style: const TextStyle(fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  void _toggleReaction(String commentId, String emoji, Map<String, dynamic> allReactions) async {
    await _commentService.toggleReaction(
      eventId: widget.eventId,
      commentId: commentId,
      emoji: emoji,
      allReactions: allReactions,
    );
  }

  void _showReactionDetails(String emoji, List uids) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Text('$emoji Reaksiyonu Verenler', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (uids.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text('Henüz kimse bu reaksiyonu vermedi.'),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: uids.length,
                  itemBuilder: (context, index) {
                    String uid = uids[index];
                    return StreamBuilder<DocumentSnapshot>(
                      stream: db.collection('users').doc(uid).snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                        final user = UserModel.fromFirestore(snapshot.data!);
                        final bool isPassive = user.isFrozen || user.isDeleted;

                        return ListTile(
                          leading: CustomAvatar(
                            radius: 18,
                            imageUrl: user.profileImage,
                            isPassive: isPassive,
                          ),
                          title: Text(
                            user.username.isNotEmpty ? '@${user.username}' : user.name,
                            style: TextStyle(
                              decoration: isPassive ? TextDecoration.lineThrough : null,
                              color: isPassive ? Colors.grey : Colors.black,
                            ),
                          ),
                          subtitle: user.username.isNotEmpty ? Text(user.name, style: const TextStyle(fontSize: 12)) : null,
                          onTap: () {
                            if (AuthService().isGuest) {
                              GuestGuardDialog.show(context, "Profil görüntüleme");
                              return;
                            }
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: uid)));
                          },
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInputArea() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kSurfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToId != null || _editingCommentId != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Colors.orange.withValues(alpha: isDark ? 0.1 : 0.05),
                child: Row(
                  children: [
                    Icon(_editingCommentId != null ? Icons.edit : Icons.reply, size: 14, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _editingCommentId != null ? 'Mesajı düzenliyorsun...' : '$_replyToName kişisine yanıt veriliyor...',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_editingCommentId != null) _commentController.clear();
                          _replyToId = null;
                          _replyToName = null;
                          _editingCommentId = null;
                        });
                      },
                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            if (_showSuggestions)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: isDark ? kSurfaceDark : Colors.white,
                  border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.grey[100]!)),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (context, index) {
                    var sug = _mentionSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: sug['isSpecial'] == true
                        ? const CircleAvatar(radius: 14, backgroundColor: Colors.orange, child: Icon(Icons.group, size: 14, color: Colors.white))
                        : const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 14)),
                      title: Text(sug['name'], style: const TextStyle(fontSize: 13)),
                      onTap: () => _selectMention(sug),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentController,
                        maxLines: 3,
                        minLines: 1,
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: 'Bir mesaj yazın...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendComment,
                      padding: const EdgeInsets.all(10),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    String text = _commentController.text.trim();
    _commentController.clear();
    String? editingId = _editingCommentId;
    String? replyingId = _replyToId;

    setState(() {
      _showSuggestions = false;
      _editingCommentId = null;
      _replyToId = null;
      _replyToName = null;
    });

    try {
      await _commentService.sendComment(
        eventId: widget.eventId,
        text: text,
        replyToId: replyingId,
        editingCommentId: editingId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  void _showCommentOptions(String commentId, Map<String, dynamic> comment, bool canDeleteAny, bool isMine, Map<String, dynamic> eventData, bool hasStaff) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🔥'].map((emoji) {
                  return IconButton(
                    icon: Text(emoji, style: const TextStyle(fontSize: 24)),
                    onPressed: () {
                      Navigator.pop(context);
                      _toggleReaction(commentId, emoji, comment['reactions'] ?? {});
                    },
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Yanıtla'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _replyToId = commentId;
                  _replyToName = comment['userName'];
                  _editingCommentId = null;
                });
              },
            ),
            if (!isMine)
              ListTile(
                leading: const Icon(Icons.report_outlined, color: Colors.orange),
                title: const Text('Yorumu Bildir', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  _showCommentReportDialog(commentId, comment);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Düzenle'),
                onTap: () {
                  var rawTs = comment['timestamp'];
                  DateTime? commentDate;
                  if (rawTs is Timestamp) {
                    commentDate = rawTs.toDate();
                  } else if (rawTs is String) {
                    commentDate = DateTime.tryParse(rawTs);
                  }

                  if (commentDate != null) {
                    if (DateTime.now().difference(commentDate).inMinutes > 15 && !hasStaff) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Düzenleme süresi (15 dk) doldu.')));
                      Navigator.pop(context);
                      return;
                    }
                  }
                  Navigator.pop(context);
                  setState(() {
                    _editingCommentId = commentId;
                    _commentController.text = comment['text'] ?? '';
                    _replyToId = null;
                  });
                },
              ),
            if (hasStaff && eventData['pinnedCommentId'] != commentId)
              ListTile(
                leading: const Icon(Icons.push_pin),
                title: const Text('Sabitle'),
                onTap: () async {
                  Navigator.pop(context);
                  await _commentService.pinComment(widget.eventId, commentId);
                },
              ),
            if (hasStaff && eventData['pinnedCommentId'] == commentId)
              ListTile(
                leading: const Icon(Icons.push_pin_outlined),
                title: const Text('Sabitlemeyi Kaldır'),
                onTap: () async {
                  Navigator.pop(context);
                  await _commentService.pinComment(widget.eventId, null);
                },
              ),
            if (isMine || canDeleteAny)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Sil', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  if (!canDeleteAny) {
                    var rawTs = comment['timestamp'];
                    DateTime? commentDate;
                    if (rawTs is Timestamp) {
                      commentDate = rawTs.toDate();
                    } else if (rawTs is String) {
                      commentDate = DateTime.tryParse(rawTs);
                    }

                    if (commentDate != null) {
                      if (DateTime.now().difference(commentDate).inMinutes > 15) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silme süresi (15 dk) doldu.')));
                        Navigator.pop(context);
                        return;
                      }
                    }
                  }

                  await _commentService.deleteComment(widget.eventId, commentId, pinnedCommentId: eventData['pinnedCommentId']);

                  if (!mounted) return;
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _leaveEvent() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinlikten Ayrıl'),
        content: const Text('Bu etkinlikten ayrılmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              await db.collection('events').doc(widget.eventId).update({
                'participants': FieldValue.arrayRemove([currentUser?.uid])
              });
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlikten ayrıldınız.')));
            },
            child: const Text('Ayrıl', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _cancelJoinRequest() async {
    await db.collection('events').doc(widget.eventId).update({
      'pendingParticipants': FieldValue.arrayRemove([currentUser?.uid])
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Katılım isteği iptal edildi.')));
  }

  Widget _buildPublicParticipantsList(List uids) {
    if (uids.isEmpty) return const SizedBox.shrink();
    int count = uids.length;
    int displayCount = min(5, count);
    List displayUids = uids.sublist(0, displayCount);

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantsListScreen(eventId: widget.eventId))),
      child: Row(
        children: [
          SizedBox(
            width: (displayCount * 24.0) + 12,
            height: 36,
            child: Stack(
              children: List.generate(displayCount, (index) {
                return Positioned(
                  left: index * 20.0,
                  child: FutureBuilder<DocumentSnapshot>(
                    future: db.collection('users').doc(displayUids[index]).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) return const CircleAvatar(radius: 16, backgroundColor: Colors.grey);
                      final user = UserModel.fromFirestore(snapshot.data!);
                      return Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: CustomAvatar(radius: 16, imageUrl: user.profileImage, isPassive: user.isFrozen || user.isDeleted),
                      );
                    },
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text('$count kişi katılıyor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
          const Spacer(),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
        ],
      ),
    );
  }

  void _approveUser(String userId) async {
    await db.collection('events').doc(widget.eventId).update({
      'pendingParticipants': FieldValue.arrayRemove([userId]),
      'participants': FieldValue.arrayUnion([userId])
    });
  }

  void _rejectUser(String userId) async {
    await db.collection('events').doc(widget.eventId).update({
      'pendingParticipants': FieldValue.arrayRemove([userId])
    });
  }

  void _removeUser(String userId) async {
    await db.collection('events').doc(widget.eventId).update({
      'participants': FieldValue.arrayRemove([userId])
    });
  }

  void _transferOwnership(String newOwnerId) async {
    final userDoc = await db.collection('users').doc(newOwnerId).get();
    if (!userDoc.exists) return;
    final userName = userDoc.data()?['username'] ?? userDoc.data()?['name'] ?? 'Anonim';

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organizatörlüğü Devret'),
        content: Text('Etkinlik yönetimini $userName kullanıcısına devretmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close management panel
              
              try {
                await db.collection('events').doc(widget.eventId).update({
                  'creatorId': newOwnerId,
                  'creatorName': userName,
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Organizatörlük $userName kullanıcısına devredildi.')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: const Text('Devret'),
          ),
        ],
      ),
    );
  }

  void _showQRCodeDialog(String secret) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yoklama QR Kodu', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Katılımcılara bu kodu okutarak yoklamayı saniyeler içinde tamamlayabilirsiniz.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: secret,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.orange),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 20),
            const Text('KOD: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
            Text(secret, style: const TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Future<void> _handleQRAction(Map<String, dynamic> eventData) async {
    final String? existingSecret = eventData['qrCodeSecret'];

    if (existingSecret != null) {
      _showQRCodeDialog(existingSecret);
    } else {
      final String newSecret = 'EVT-${widget.eventId.substring(0, 4)}-${Random().nextInt(9999).toString().padLeft(4, '0')}';
      await db.collection('events').doc(widget.eventId).update({'qrCodeSecret': newSecret});
      _showQRCodeDialog(newSecret);
    }
  }

  void _confirmGenerateRefCode() async {
    final userDoc = await db.collection('users').doc(currentUser?.uid).get();
    if (!mounted) return;
    final userData = userDoc.data();
    final isRestricted = userData?['isRestricted'] ?? false;

    if (isRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kısıtlı hesaplar referans kodu oluşturamaz.'), backgroundColor: Colors.red),
      );
      return;
    }

    final eventDoc = await db.collection('events').doc(widget.eventId).get();
    if (!mounted) return;
    final eventData = eventDoc.data();
    final List referrals = eventData?['referrals'] ?? [];

    bool joinedViaReference = referrals.any((r) => r['user'] == currentUser?.uid);
    if (joinedViaReference) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu etkinliğe referans ile katıldığınız için başkasına referans olamazsınız.'), backgroundColor: Colors.red),
      );
      return;
    }

    var codes = await db.collection('events').doc(widget.eventId).collection('referenceCodes')
        .where('createdBy', isEqualTo: currentUser?.uid)
        .get();

    if (!mounted) return;
    if (codes.docs.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimum 2 referans kodu oluşturma limitine ulaştınız.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Referans Kodu Oluştur'),
        content: const Text('Bu kodu paylaşarak başkalarının etkinliğe katılmasını sağlayabilirsiniz. Unutmayın, en fazla 2 kod üretebilirsiniz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _generateRefCode(); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _provideReferenceToUser(Map<String, dynamic> request, String requestId) async {
    final userDoc = await db.collection('users').doc(currentUser?.uid).get();
    if (!mounted) return;
    final userData = userDoc.data();
    if (userData?['isRestricted'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kısıtlı hesaplar referans olamaz.'), backgroundColor: Colors.red));
      return;
    }

    final eventDoc = await db.collection('events').doc(widget.eventId).get();
    if (!mounted) return;
    final eventData = eventDoc.data();
    final List referrals = eventData?['referrals'] ?? [];
    if (referrals.any((r) => r['user'] == currentUser?.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu etkinliğe referans ile katıldığınız için başkasına referans olamazsınız.'), backgroundColor: Colors.red));
      return;
    }

    final codes = await db.collection('events').doc(widget.eventId).collection('referenceCodes')
        .where('createdBy', isEqualTo: currentUser?.uid)
        .get();

    if (!mounted) return;
    if (codes.docs.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimum 2 referans kodu oluşturma limitine ulaştınız.'), backgroundColor: Colors.red),
      );
      return;
    }

    String code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    WriteBatch batch = db.batch();

    DocumentReference codeRef = db.collection('events').doc(widget.eventId).collection('referenceCodes').doc();
    batch.set(codeRef, {
      'code': code,
      'createdBy': currentUser?.uid,
      'usedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
      'isUsed': false,
    });

    batch.update(db.collection('reference_requests').doc(requestId), {
      'status': 'fulfilled',
      'fulfilledBy': currentUser?.uid,
    });

    DocumentReference notifyRef = db.collection('users').doc(request['userId']).collection('notifications').doc();
    batch.set(notifyRef, {
      'type': 'reference_code_received',
      'recipientId': request['userId'],
      'senderId': currentUser?.uid,
      'senderName': currentUser?.displayName ?? 'Bir kullanıcı',
      'content': '${request['eventTitle']} etkinliği için referans kodunuz: $code',
      'code': code,
      'eventId': widget.eventId,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Referans Gönderildi'),
          content: Text('Kodunuz ($code) kullanıcıya iletildi.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
        ),
      );
    }
  }


  void _generateRefCode() async {
    String code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    await db.collection('events').doc(widget.eventId).collection('referenceCodes').add({
      'code': code,
      'createdBy': currentUser?.uid,
      'isUsed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    _showCodeDialog(code);
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kod Oluşturuldu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu kodu kopyalayıp paylaşabilirsiniz:'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(code, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20, color: Colors.blue),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı!'), duration: Duration(seconds: 1)));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showRatingDialog(String targetUid, String eventTitle) {
    double selectedRating = 5.0;
    final TextEditingController ratingCommentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Puan Ver', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu katılımcı hakkında ne düşünüyorsun?', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) => selectedRating = rating,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ratingCommentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Yorumun (isteğe bağlı)',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              try {
                showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

                await RatingService().submitRating(
                  eventId: widget.eventId,
                  fromId: currentUser!.uid,
                  toId: targetUid,
                  score: selectedRating,
                  comment: ratingCommentController.text.trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context); // Remove loading
                  Navigator.pop(context); // Remove rating dialog

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanınız başarıyla iletildi!'), backgroundColor: Colors.green));
                  setState(() {});
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Gönder', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEventRatingDialog(double rating) {
    final TextEditingController eventRatingCommentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Etkinlik Yorumu', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Puanınız: $rating', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 16),
            TextField(
              controller: eventRatingCommentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Etkinlik hakkındaki düşüncelerin...',
                hintStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              try {
                showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

                await RatingService().submitEventRating(
                  eventId: widget.eventId,
                  userId: currentUser!.uid,
                  score: rating,
                  comment: eventRatingCommentController.text.trim(),
                );

                if (mounted) {
                  Navigator.pop(context); // Remove loading
                  Navigator.pop(context); // Remove dialog
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik puanınız kaydedildi!'), backgroundColor: Colors.green));
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: ${e.toString()}'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinliği Sil'),
        content: const Text('Bu etkinliği silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await db.collection('events').doc(widget.eventId).delete();
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showEventReportDialog(Map<String, dynamic> event) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinliği Bildir'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Bildirme sebebi...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;

              final myDoc = await db.collection('users').doc(currentUser?.uid).get();
              if (!mounted) return;
              final myName = myDoc.data()?['name'] ?? 'Kullanıcı';

              await db.collection('reports').add({
                'category': 'event',
                'targetId': widget.eventId,
                'targetContent': event['title'],
                'targetUserId': event['creatorId'],
                'reason': reason,
                'reporterId': currentUser?.uid,
                'reporterName': myName,
                'city': event['city'], 
                'status': 'pending',
                'timestamp': FieldValue.serverTimestamp(),
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik bildirildi.')));
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  void _showCommentReportDialog(String commentId, Map<String, dynamic> comment) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorumu Bildir'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Bildirme sebebi...'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;

              await _commentService.reportComment(
                eventId: widget.eventId,
                commentId: commentId,
                commentText: comment['text'] ?? '',
                commentUserId: comment['userId'] ?? '',
                commentUserName: comment['userName'] ?? 'Anonim',
                reason: reason,
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yorum bildirildi.')));
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  void _uploadPhoto(Map<String, dynamic> event) async {
    final rawDate = event['eventDate'];
    DateTime date;
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    if (DateTime.now().isBefore(date)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fotoğraf yükleme özelliği etkinlik saatinden sonra açılacaktır.'),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    List attendedList = event['attendanceYes'] ?? [];
    if (!attendedList.contains(currentUser?.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sadece etkinliğe katılımı onaylanan (yoklamada var işaretlenen) kişiler fotoğraf yükleyebilir.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile == null) return;

    var userPhotos = await db.collection('events').doc(widget.eventId).collection('photos')
        .where('userId', isEqualTo: currentUser?.uid)
        .get();

    if (!mounted) return;
    if (userPhotos.docs.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Her katılımcı en fazla 2 fotoğraf paylaşabilir.')));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final file = await pickedFile.readAsBytes();
      final storageRef = FirebaseStorage.instance.ref().child('event_photos/${widget.eventId}/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putData(file);
      final url = await storageRef.getDownloadURL();

      if (!mounted) return;

      await db.collection('events').doc(widget.eventId).collection('photos').add({
        'url': url,
        'userId': currentUser?.uid,
        'userName': currentUser?.displayName ?? 'Anonim',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf yüklendi, moderatör onayından sonra görünecektir.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yükleme hatası: $e')));
      }
    }
  }

  void _viewPhoto(Map<String, dynamic> photo, String photoId, bool canModerate) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: photo['url'],
                    memCacheWidth: 1200, 
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                  ),
                ),
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      onPressed: () async {
                        final url = Uri.parse(photo['url']);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      },
                      tooltip: 'İndir',
                    ),
                  ),
                ),
                if (canModerate)
                  Positioned(
                    top: 10, left: 10,
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        onPressed: () => _confirmDeletePhoto(photoId, photo['url']),
                        tooltip: 'Fotoğrafı Sil',
                      ),
                    ),
                  ),
              ],
            ),
            if (canModerate && photo['status'] == 'pending') ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _moderatePhoto(photoId, 'approved', photo['userId']);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Onayla'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _moderatePhoto(photoId, 'rejected', photo['userId']);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Reddet'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePhoto(String photoId, String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fotoğrafı Sil'),
        content: const Text('Bu fotoğrafı kalıcı olarak silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close photo viewer
              await _deletePhoto(photoId, photoUrl);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePhoto(String photoId, String photoUrl) async {
    try {
      await db.collection('events').doc(widget.eventId).collection('photos').doc(photoId).delete();
      await FirebaseStorage.instance.refFromURL(photoUrl).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf silindi.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
    }
  }

  void _moderatePhoto(String photoId, String status, String? uploaderUid) async {
    await db.collection('events').doc(widget.eventId).collection('photos').doc(photoId).update({'status': status});
    
    if (status == 'approved' && uploaderUid != null) {
      await ScoreService.instance.updateScore(
        userId: uploaderUid,
        amount: ScoreService.photoShareReward,
        reason: 'Fotoğraf Paylaşım Ödülü',
        relatedId: photoId,
      );
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status == 'approved' ? 'Fotoğraf onaylandı.' : 'Fotoğraf reddedildi.')));
  }
}

