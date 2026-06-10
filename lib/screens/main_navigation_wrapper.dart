import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import 'home_screen.dart';
import 'messages_list_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'banned_screen.dart';
import 'community_tab.dart';
import 'city_events_tab.dart';
import '../services/score_service.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  DateTime? _lastQuitTime;
  final ScrollController _homeScrollController = ScrollController();

  late final List<Widget> _screens = [
    HomeScreen(scrollController: _homeScrollController),
    const CommunityTab(),
    const CityEventsTab(),
    const MessagesListScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (AuthService().isGuest) {
      if (index == 3) {
        GuestGuardDialog.show(context, "Mesajlaşma");
        return;
      }
      if (index == 4) {
        GuestGuardDialog.show(context, "Profil yönetimi");
        return;
      }
    }

    if (index == _currentIndex && index == 0) {
      _scrollToTop();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _scrollToTop() {
    if (_homeScrollController.hasClients) {
      _homeScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPendingDuties();
  }

  Future<void> _checkPendingDuties() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.isAnonymous) {
      // Don't block UI
      ScoreService().checkUserPendingDuties(user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Eğer bir alt sayfa (Navigator) açıksa önce onu kapat
        if (context.mounted) {
          final NavigatorState nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
            return;
          }
        }

        // Keşfet'te aşağıdaysak yukarı çık
        if (_currentIndex == 0 && _homeScrollController.hasClients && _homeScrollController.offset > 0) {
          _scrollToTop();
          return;
        }

        // En üstteysek veya başka sekmedeysek 2 kez geri basınca çık
        final now = DateTime.now();
        if (_lastQuitTime == null || now.difference(_lastQuitTime!) > const Duration(seconds: 2)) {
          _lastQuitTime = now;
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Çıkmak için tekrar basın'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }

        // Çıkış yap
        if (context.mounted) {
          SystemChannels.platform.invokeMethod('SystemNavigator.pop');
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        floatingActionButton: _currentIndex != 0 && user != null
          ? Container(
              margin: const EdgeInsets.only(bottom: 5),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, notifSnapshot) {
                  int unreadCount = notifSnapshot.data?.docs.length ?? 0;
                  return FloatingActionButton.small(
                    heroTag: 'notif_fab',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                    ),
                    backgroundColor: Colors.white,
                    elevation: 2,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.notifications_none_rounded, color: Colors.orange, size: 20),
                        if (unreadCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          : null,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white10 
                    : Colors.grey.shade200, 
                width: 0.5
              )
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 55,
              child: Theme(
                data: Theme.of(context).copyWith(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onItemTapped,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: Colors.orange,
                  unselectedItemColor: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey.shade600 
                      : Colors.grey.shade400,
                  selectedFontSize: 11,
                  unselectedFontSize: 11,
                  iconSize: 20,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.explore_outlined),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.explore),
                      ),
                      label: 'Keşfet',
                    ),
                    const BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.groups_outlined),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.groups),
                      ),
                      label: 'Topluluk',
                    ),
                    const BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.location_city_outlined),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.location_city),
                      ),
                      label: 'Şehrin',
                    ),
                    BottomNavigationBarItem(
                      icon: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: user != null 
                          ? StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('chats')
                                  .where('participants', arrayContains: user.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                int unreadChats = 0;
                                if (snapshot.hasData) {
                                  for (var doc in snapshot.data!.docs) {
                                    var data = doc.data() as Map<String, dynamic>;
                                    Map unreadCount = data['unreadCount'] ?? {};
                                    if ((unreadCount[user.uid] ?? 0) > 0) {
                                      unreadChats++;
                                    }
                                  }
                                }

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    const Icon(Icons.chat_bubble_outline),
                                    if (unreadChats > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                                          constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                          child: Text(
                                            unreadChats > 9 ? '9+' : '$unreadChats',
                                            style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      ),
                      activeIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.chat_bubble),
                      ),
                      label: 'Mesajlar',
                    ),
                    const BottomNavigationBarItem(
                      icon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.person_outline),
                      ),
                      activeIcon: Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Icon(Icons.person),
                      ),
                      label: 'Profil',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
