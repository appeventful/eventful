import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import '../widgets/home/discover_tab.dart';
import 'create_event_screen.dart';
import 'notifications_screen.dart';
import 'admin_panel_screen.dart';
import 'reference_requests_screen.dart';
import 'search_screen.dart';
import '../services/score_service.dart';
import 'map_explorer_screen.dart';
import 'package:rxdart/rxdart.dart';
import '../utils/platform_helper.dart';

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const HomeScreen({super.key, this.scrollController});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScoreService _scoreService = ScoreService.instance;
  final GlobalKey<DiscoverTabState> _discoverTabKey = GlobalKey<DiscoverTabState>();
  bool _canCreateEvent = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _scoreService.updateLastActive(uid);
      await _scoreService.checkDailyLogin();
      await _scoreService.checkUserPendingDuties(uid);
      final allowed = await _scoreService.canCreateEvent(uid);
      if (!mounted) return;
      setState(() => _canCreateEvent = allowed);
      if (mounted) _checkFounderWelcome(uid);
    }
  }

  void _checkFounderWelcome(String uid) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    if (userDoc.exists) {
      final userData = userDoc.data();
      if (userData == null) return;
      final bool isFounder = userData['isFounder'] ?? false;
      final bool hasSeenWelcome = userData['hasSeenFounderWelcome'] ?? false;

      if (isFounder && !hasSeenWelcome) {
        if (mounted) _showFounderWelcomeDialog(uid);
      }
    }
  }

  void _showFounderWelcomeDialog(String uid) {
    PlatformHelper.showAdaptiveDialog(
      context: context,
      title: 'Kurucu Üye!',
      content: 'Tebrikler! Eventful\'un ilk kullanıcılarından biri olduğunuz için "Kurucu" (Founder) rozetini kazandınız.\n\nBu özel topluluğun bir parçası olduğunuz için teşekkür ederiz.',
      confirmText: 'Harika!',
      onConfirm: () async {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'hasSeenFounderWelcome': true,
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Eventful', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        elevation: 0,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(_auth.currentUser?.uid).snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasError) return const SizedBox.shrink();
              if (!userSnapshot.hasData) return const SizedBox.shrink();
              var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
              String role = userData?['role'] ?? 'user';
              bool isGod = _auth.currentUser?.email == 'fatihkull17@gmail.com';
              
              if (isGod || role == 'moderator') {
                return StreamBuilder<List<QuerySnapshot>>(
                  stream: Rx.combineLatest2(
                    FirebaseFirestore.instance.collection('reports').where('status', isEqualTo: 'pending').snapshots(),
                    FirebaseFirestore.instance.collection('events').where('isApproved', isEqualTo: false).snapshots(),
                    (a, b) => [a, b],
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const SizedBox.shrink();
                    int reportCount = snapshot.data?[0].docs.length ?? 0;
                    int eventCount = snapshot.data?[1].docs.length ?? 0;
                    int totalCount = reportCount + eventCount;

                    return Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.security, color: Colors.redAccent, size: 28),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                          ),
                          tooltip: 'Moderasyon Paneli',
                        ),
                        if (totalCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              child: Text(
                                '$totalCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.handshake_outlined, color: Colors.green, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReferenceRequestsScreen()),
            ),
            tooltip: 'Destek Merkezi',
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_auth.currentUser?.uid)
                .collection('notifications')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const SizedBox.shrink();
              int unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.orange, size: 28),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined, color: Colors.orange, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MapExplorerScreen()),
            ),
            tooltip: 'Harita Görünümü',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.orange, size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            ).then((_) => _discoverTabKey.currentState?.refresh()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DiscoverTab(key: _discoverTabKey, scrollController: widget.scrollController),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (AuthService().isGuest) {
            GuestGuardDialog.show(context, "Yeni etkinlik oluşturma");
            return;
          }
          final isGod = _auth.currentUser?.email == 'fatihkull17@gmail.com';
          if (!_canCreateEvent && !isGod) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Katılım kısıtlamaları nedeniyle yeni etkinlik oluşturamazsınız! Lütfen referanslı etkinliklere katılarak güven kazanın.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          ).then((_) {
            _discoverTabKey.currentState?.refresh();
            _checkStatus();
          });
        },
        backgroundColor: _canCreateEvent ? Colors.orange : Colors.grey,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Yeni', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
