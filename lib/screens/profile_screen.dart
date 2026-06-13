import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/score_service.dart';
import '../widgets/custom_avatar.dart';
import '../utils/sharing_templates.dart';
import 'edit_profile_screen.dart';
import 'event_detail_screen.dart';
import 'settings_screen.dart';
import 'friends_list_screen.dart';
import 'feedback_screen.dart';
import 'user_reviews_screen.dart';
import 'chat_screen.dart';
import 'community_detail_screen.dart';
import 'user_communities_screen.dart';
import 'profile_events_screen.dart';
import 'how_to_use_screen.dart';
import '../widgets/full_screen_image.dart';
import '../models/event_model.dart';
import '../widgets/event_card.dart';
import '../models/user_model.dart';
import 'supporter_screen.dart';

import '../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  final String? otherUserId;
  const ProfileScreen({super.key, this.otherUserId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final _authService = AuthService();
  late TabController _tabController;
  
  bool _isFriend = false;
  bool _isBlocked = false;
  bool _iAmBlocked = false;
  bool _isFollowing = false;
  bool _hasPendingRequest = false;
  bool _isCommunityMod = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  String get _targetId => widget.otherUserId ?? _currentUserId ?? '';
  bool get _isMe => widget.otherUserId == null || widget.otherUserId == _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (!_isMe) {
      _loadSocialStatus();
    } else if (_currentUserId != null) {
      ScoreService.instance.checkUserPendingDuties(_currentUserId!);
      ScoreService.instance.checkDailyLogin();
    }
    _checkCommunityModStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkCommunityModStatus() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('communities').where('moderators', arrayContains: _targetId).get();
      if (mounted) setState(() => _isCommunityMod = snap.docs.isNotEmpty);
    } catch (e) {
      debugPrint("Community mod check error: $e");
    }
  }

  void _loadSocialStatus() async {
    final uid = _currentUserId;
    if (uid == null) return;
    
    final db = FirebaseFirestore.instance;
    try {
      var myDoc = await db.collection('users').doc(uid).get();
      if (myDoc.exists) {
        final data = myDoc.data() as Map<String, dynamic>?;
        List friends = data?['friends'] ?? [];
        _isFriend = friends.contains(_targetId);
        List blockedUsers = data?['blockedUsers'] ?? [];
        _isBlocked = blockedUsers.contains(_targetId);
        List sentRequests = data?['sentFriendRequests'] ?? [];
        _hasPendingRequest = sentRequests.contains(_targetId);
        List following = data?['following'] ?? [];
        _isFollowing = following.contains(_targetId);
      }

      var targetDoc = await db.collection('users').doc(_targetId).get();
      if (targetDoc.exists) {
        List targetBlockedUsers = (targetDoc.data() as Map<String, dynamic>?)?['blockedUsers'] ?? [];
        _iAmBlocked = targetBlockedUsers.contains(uid);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Sosyal durum yükleme hatası: $e");
    }
  }

  void _shareProfile(UserModel user) {
    final String shareText = SharingTemplates.profileShare(user.username, user.points);
    final String profileUrl = "https://eventfulapp.org/user/${user.username}";
    
    Share.share(
      '$shareText\n\nProfilimi incele: $profileUrl',
      subject: '@${user.username} Profili',
    );
  }

  void _handleFriendAction() async {
    try {
      if (_isFriend) {
        await _authService.removeFriend(_targetId);
        setState(() => _isFriend = false);
      } else if (_hasPendingRequest) {
        await _authService.cancelFriendRequest(_targetId);
        setState(() => _hasPendingRequest = false);
      } else {
        await _authService.sendFriendRequest(_targetId);
        setState(() => _hasPendingRequest = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _handleFollowAction() async {
    try {
      await _authService.toggleFollow(_targetId, _isFollowing);
      setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _handleBlockAction() async {
    try {
      await _authService.toggleBlock(_targetId, _isBlocked);
      setState(() {
        if (_isBlocked) _isBlocked = false;
        else {
          _isBlocked = true;
          _isFriend = false;
          _isFollowing = false;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  String _calculateHoroscope(DateTime date) {
    int day = date.day;
    int month = date.month;
    if ((month == 3 && day >= 21) || (month == 4 && day <= 19)) return "Koç";
    if ((month == 4 && day >= 20) || (month == 5 && day <= 20)) return "Boğa";
    if ((month == 5 && day >= 21) || (month == 6 && day <= 20)) return "İkizler";
    if ((month == 6 && day >= 21) || (month == 7 && day <= 22)) return "Yengeç";
    if ((month == 7 && day >= 23) || (month == 8 && day <= 22)) return "Aslan";
    if ((month == 8 && day >= 23) || (month == 9 && day <= 22)) return "Başak";
    if ((month == 9 && day >= 23) || (month == 10 && day <= 22)) return "Terazi";
    if ((month == 10 && day >= 23) || (month == 11 && day <= 21)) return "Akrep";
    if ((month == 11 && day >= 22) || (month == 12 && day <= 21)) return "Yay";
    if ((month == 12 && day >= 22) || (month == 1 && day <= 19)) return "Oğlak";
    if ((month == 1 && day >= 20) || (month == 2 && day <= 18)) return "Kova";
    return "Balık";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_targetId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text("Hata: ${snapshot.error}")));
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Kullanıcı bulunamadı")));
        
        final user = UserModel.fromFirestore(snapshot.data!);

        if (_isMe) {
          return _buildProfileScaffold(user, user, true);
        }
        
        return StreamBuilder<UserModel?>(
          stream: _authService.userStream(_currentUserId ?? ''),
          builder: (context, mySnap) {
            if (mySnap.hasError) return Scaffold(body: Center(child: Text("Hata: ${mySnap.error}")));
            if (!mySnap.hasData && _currentUserId != null) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            final me = mySnap.data;
            final bool isAdminViewer = me?.isAdmin ?? false;

            return _buildProfileScaffold(user, me, isAdminViewer);
          }
        );
      },
    );
  }

  Widget _buildProfileScaffold(UserModel user, UserModel? me, bool isAdminViewer) {
    final bool canEdit = _isMe || isAdminViewer;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            stretch: true,
            backgroundColor: kSurfaceDark,
            elevation: 0,
            leading: Navigator.canPop(context) 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () => _shareProfile(user),
              ),
              if (_isMe) 
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white), 
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))
                ),
              if (!_isMe) 
                IconButton(
                  icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent), 
                  onPressed: () => _showReportDialog(user)
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [kPrimaryOrange, Color(0xFFFF7043), kSurfaceDark],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -50,
                    top: -50,
                    child: CircleAvatar(radius: 100, backgroundColor: Colors.white.withOpacity(0.05)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: _buildProfileHeader(user, canEdit, me),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _buildUserBasicInfo(user),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: kPrimaryOrange,
                unselectedLabelColor: Colors.grey,
                indicatorColor: kPrimaryOrange,
                tabs: const [
                  Tab(text: "Hakkında"),
                  Tab(text: "Rozetler"),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildAboutTab(user),
            _buildBadgesTab(user),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(UserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          _buildScoreBoard(user),
          const SizedBox(height: 24),
          if (!_isMe) _buildOtherUserActions(user) else _buildMyProfileActions(user),
          const SizedBox(height: 32),
          _buildRecommendations(user),
          const SizedBox(height: 24),
          _buildUserLinks(user),
          const SizedBox(height: 24),
          if (_isMe) _buildSupporterSection(user),
          if (_isMe) const SizedBox(height: 24),
          _buildRestrictionWarning(user),
          if (_isMe) ...[
            const SizedBox(height: 32),
            _buildBottomActions(),
            const SizedBox(height: 16),
            _buildFooterLinks(),
          ],
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildBadgesTab(UserModel user) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
        childAspectRatio: 0.8,
      ),
      itemCount: availableBadges.length,
      itemBuilder: (context, index) {
        final badge = availableBadges[index];
        final bool isEarned = user.badges.contains(badge['id']);
        
        return GestureDetector(
          onTap: () => _showBadgeDetail(badge, isEarned),
          child: Container(
            decoration: BoxDecoration(
              color: isEarned ? kPrimaryOrange.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEarned ? kPrimaryOrange.withOpacity(0.3) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: isEarned ? 1.0 : 0.2,
                  child: ColorFiltered(
                    colorFilter: isEarned 
                      ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                      : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                    child: Text(badge['icon'], style: const TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  badge['name'], 
                  textAlign: TextAlign.center, 
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold, 
                    color: isEarned ? kPrimaryOrange : Colors.grey
                  )
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(UserModel user, bool canEdit, UserModel? me) {
    final bool isPassive = user.isFrozen || user.isDeleted;
    final String imageUrl = user.getEffectiveImageUrl(isMe: _isMe, viewerIsAdmin: me?.isAdmin ?? false);

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        GestureDetector(
          onTap: () {
            if (imageUrl.isNotEmpty) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => FullScreenImage(imageUrl: imageUrl, heroTag: 'profile_avatar_${user.uid}', name: user.name)));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Hero(
              tag: 'profile_avatar_${user.uid}',
              child: CustomAvatar(
                user: user,
                isMe: _isMe,
                isAdminView: me?.isAdmin ?? false,
                radius: 65,
                backgroundColor: Colors.grey[200],
                isPassive: isPassive,
              ),
            ),
          ),
        ),
        if (canEdit)
          Positioned(
            right: 4,
            bottom: 4,
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(targetUserId: _isMe ? null : user.uid))),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 3),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserBasicInfo(UserModel user) {
    final bool isPassive = user.isFrozen || user.isDeleted;
    
    // Privacy and Value checks
    String age = "";
    if (user.birthDate != null && !user.hideAge) {
      DateTime bd = user.birthDate!.toDate();
      int years = DateTime.now().year - bd.year;
      if (DateTime.now().month < bd.month || (DateTime.now().month == bd.month && DateTime.now().day < bd.day)) years--;
      age = "$years Yaş";
    }

    String genderText = "";
    if (user.gender != null && user.gender!.isNotEmpty && !user.hideGender) {
      if (user.gender == 'male') genderText = "Erkek";
      else if (user.gender == 'female') genderText = "Kadın";
      else if (user.gender == 'other') genderText = "Diğer";
      else genderText = user.gender!; // Fallback
    }

    String location = "";
    if (user.location != null && user.location!.isNotEmpty && !user.hideLocation) {
      location = user.location!;
    }

    List<String> infoParts = [];
    if (age.isNotEmpty) infoParts.add(age);
    if (genderText.isNotEmpty) infoParts.add(genderText);
    if (location.isNotEmpty) infoParts.add(location);
    if (user.birthDate != null && !user.hideHoroscope) infoParts.add(_calculateHoroscope(user.birthDate!.toDate()));

    final String displayInfo = infoParts.join(" • ");

    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          user.name, 
          style: user.getNameStyle(
            context,
            fontSize: 24,
            isBold: true,
          ).copyWith(
            color: isPassive ? Colors.grey : null,
            decoration: isPassive ? TextDecoration.lineThrough : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "@${user.username}", 
          style: TextStyle(
            fontSize: 16, 
            color: kPrimaryOrange.withOpacity(0.9),
            fontWeight: FontWeight.w600,
            decoration: isPassive ? TextDecoration.lineThrough : null,
          )
        ),
        if (displayInfo.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.only(top: 8), 
            child: Text(displayInfo, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14, fontWeight: FontWeight.w500))
          ),
        
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (user.role == 'admin' && !isPassive) _buildBadge("ADMIN", Colors.redAccent),
            if (user.role == 'moderator' && !isPassive) _buildBadge("MODERATÖR", Colors.purpleAccent),
            if (user.role == 'city_representative' && !isPassive) _buildBadge("${user.responsibleCity?.toUpperCase() ?? 'İL'} TEMSİLCİSİ", Colors.greenAccent),
            if (_isCommunityMod && !isPassive) _buildBadge("TOPLULUK REHBERİ", Colors.tealAccent),
            if (user.isDeleted) _buildBadge("SİLİNMİŞ HESAP", Colors.red),
            if (user.isFrozen && !user.isDeleted) _buildBadge("DONDURULMUWS HESAP", Colors.grey),
          ],
        ),
        
        // Instagram Button (Conditional visibility)
        if (user.instagramHandle != null && user.instagramHandle!.isNotEmpty && !user.hideInstagram)
          _buildInstagramButton(user),
        
        if (user.bio.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 10, right: 10), 
            child: Text(
              user.bio, 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 15, height: 1.5, color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8))
            )
          ),
      ],
    );
  }

  Widget _buildSimpleStatBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceDark,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showBadgeDetail(Map<String, dynamic> badge, bool isEarned) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(badge['icon'], style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 16),
            Text(badge['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text(
              isEarned ? "KAZANILDI" : "HENÜZ KAZANILMADI",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isEarned ? Colors.green : Colors.orange),
            ),
            const SizedBox(height: 20),
            Text(badge['description'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                child: const Text("Kapat"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramButton(UserModel user) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 32, right: 32),
      child: InkWell(
        onTap: () => _openInstagram(user),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Text(
                "@${user.instagramHandle}",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              if (_isMe && !user.isInstagramFollowed) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                  child: const Text("+50 Puan", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddInstagramButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 32, right: 32),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text("Instagram Ekle & 50 Puan Kazan!"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.pink,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.pink, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: color.withOpacity(0.4), width: 1)
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildScoreBoard(UserModel user) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreItem("Arkadaş", user.friends.length.toString(), Icons.people_alt_outlined, Colors.blue),
          _buildScoreDivider(),
          _buildScoreItem("Takipçi", user.followers.length.toString(), Icons.group_add_outlined, Colors.purple),
          _buildScoreDivider(),
          _buildScoreItem("Takip", user.following.length.toString(), Icons.person_add_alt_1_outlined, Colors.pinkAccent),
          _buildScoreDivider(),
          _buildScoreItem("Güven", user.trustScore.toStringAsFixed(1), Icons.shield_outlined, Colors.green),
          _buildScoreDivider(),
          _buildScoreItem("Puan", user.points.toString(), Icons.emoji_events_outlined, Colors.amber),
        ],
      ),
    );
  }

  Widget _buildScoreDivider() => Container(height: 30, width: 1, color: Colors.grey.withOpacity(0.2));

  Widget _buildScoreItem(String label, String value, IconData icon, Color color) {
    return GestureDetector(
      onTap: (label == "Arkadaş" || label == "Takipçi" || label == "Takip") 
          ? () => _showList(label == "Arkadaş" ? 'friends' : (label == "Takipçi" ? 'followers' : 'following'))
          : label == "Güven" 
              ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserReviewsScreen(targetUserId: _targetId, targetUserName: '')))
              : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showList(String type) => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsListScreen(userId: _targetId, userName: '', listType: type)));

  Future<void> _openInstagram(UserModel user) async {
    final handle = user.instagramHandle;
    if (handle == null || handle.isEmpty) return;
    
    final cleanHandle = handle.replaceAll('@', '').trim();
    final nativeUrl = Uri.parse("instagram://user?username=$cleanHandle");
    final webUrl = Uri.parse("https://www.instagram.com/$cleanHandle/");
    
    try {
      bool launched = false;
      if (await canLaunchUrl(nativeUrl)) {
        launched = await launchUrl(nativeUrl);
      } else {
        launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }

      if (launched && _isMe && !user.isInstagramFollowed) {
        await ScoreService.instance.updateScore(
          userId: user.uid,
          amount: ScoreService.instagramFollowReward,
          reason: 'Instagram Takip Ödülü',
          relatedId: 'instagram_follow',
        );
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isInstagramFollowed': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Tebrikler! 50 Puan kazandınız.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Instagram açılamadı")));
      }
    }
  }

  Widget _buildOtherUserActions(UserModel user) {
    if (_iAmBlocked) return const Center(child: Text("Bu kullanıcıya ulaşılamıyor", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)));
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
      builder: (context, snapshot) {
        final myData = snapshot.data?.data() as Map<String, dynamic>?;
        final bool isAdmin = (myData?['role'] == 'admin') || (_currentUserId != null && FirebaseAuth.instance.currentUser?.email == 'fatihkull17@gmail.com');

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    onPressed: _handleFriendAction, 
                    label: _isFriend ? 'Arkadaş' : (_hasPendingRequest ? 'Bekliyor' : 'Arkadaş Ekle'), 
                    icon: _isFriend ? Icons.people : Icons.person_add, 
                    color: _isFriend ? Theme.of(context).cardColor : kPrimaryOrange, 
                    textColor: _isFriend ? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black : Colors.white
                  )
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    onPressed: _handleFollowAction, 
                    label: _isFollowing ? 'Takipte' : 'Takip Et', 
                    icon: _isFollowing ? Icons.notifications_active : Icons.notifications_none, 
                    color: _isFollowing ? Theme.of(context).cardColor : kPrimaryOrange.withOpacity(0.1), 
                    textColor: _isFollowing ? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black : kPrimaryOrange
                  )
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: user.uid, receiverName: user.name))), 
                    label: 'Mesaj Gönder', 
                    icon: Icons.chat_bubble_outline_rounded, 
                    color: Colors.blueAccent.withOpacity(0.1), 
                    textColor: Colors.blueAccent
                  )
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: _handleBlockAction, 
                  icon: Icon(_isBlocked ? Icons.block_flipped : Icons.block, color: _isBlocked ? Colors.red : Colors.grey), 
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).cardColor,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  )
                ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 24),
              _buildAdminSection(user),
            ],
          ],
        );
      }
    );
  }

  Widget _buildAdminSection(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Text("YÖNETİCİ ARAÇLARI", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 12),
          _buildAdminActions(user),
        ],
      ),
    );
  }

  Widget _buildAdminActions(UserModel user) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildAdminMiniButton(
          onPressed: () => _showAdminBanDialog(user),
          label: user.isBanned ? 'Yasağı Kaldır' : 'Yasakla',
          icon: Icons.gavel,
          color: Colors.red,
        ),
        _buildAdminMiniButton(
          onPressed: () => _toggleAdminStatus(user, 'isRestricted'),
          label: user.isRestricted ? 'Kısıtlamayı Kaldır' : 'Kısıtla',
          icon: Icons.warning_amber_rounded,
          color: Colors.orange,
        ),
        _buildAdminMiniButton(
          onPressed: () => _showAdminRoleDialog(user),
          label: 'Rolü Değiştir',
          icon: Icons.admin_panel_settings,
          color: Colors.blue,
        ),
        _buildAdminMiniButton(
          onPressed: () => _showAdminTrustScoreDialog(user),
          label: 'Güven Puanı',
          icon: Icons.shield,
          color: Colors.green,
        ),
        _buildAdminMiniButton(
          onPressed: () => _showAdminPointsDialog(user),
          label: 'Puan Ver/Al',
          icon: Icons.stars,
          color: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildAdminMiniButton({required VoidCallback onPressed, required String label, required IconData icon, required Color color}) {
    return ActionChip(
      onPressed: onPressed,
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  void _showAdminBanDialog(UserModel user) {
    if (user.isBanned) {
      _toggleAdminStatus(user, 'isBanned');
      return;
    }
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kullanıcıyı Yasakla"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Yasaklanma Sebebi")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                'isBanned': true,
                'banReason': controller.text,
                'banUntil': Timestamp.fromDate(DateTime.now().add(const Duration(days: 365 * 10))),
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Yasakla"),
          ),
        ],
      ),
    );
  }

  void _showAdminRoleDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text("Rol Değiştir"),
        children: ['user', 'moderator', 'admin'].map((role) => SimpleDialogOption(
          onPressed: () {
            FirebaseFirestore.instance.collection('users').doc(user.uid).update({'role': role});
            Navigator.pop(context);
          },
          child: Text(role.toUpperCase()),
        )).toList(),
      ),
    );
  }

  void _showAdminTrustScoreDialog(UserModel user) {
    final controller = TextEditingController(text: user.trustScore.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Güven Puanını Düzenle"),
        content: TextField(controller: controller, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              double? val = double.tryParse(controller.text);
              if (val != null) {
                FirebaseFirestore.instance.collection('users').doc(user.uid).update({'trustScore': val});
              }
              Navigator.pop(context);
            },
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
  }

  void _showAdminPointsDialog(UserModel user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Puan Ekle/Çıkar"),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Örn: 50 veya -50")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () {
              int? val = int.tryParse(controller.text);
              if (val != null) {
                FirebaseFirestore.instance.collection('users').doc(user.uid).update({'points': FieldValue.increment(val)});
              }
              Navigator.pop(context);
            },
            child: const Text("Uygula"),
          ),
        ],
      ),
    );
  }

  void _toggleAdminStatus(UserModel user, String field) {
    bool current = false;
    if (field == 'isBanned') current = user.isBanned;
    else if (field == 'isRestricted') current = user.isRestricted;
    
    FirebaseFirestore.instance.collection('users').doc(user.uid).update({field: !current});
  }

  Widget _buildMyProfileActions(UserModel user) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())), 
                label: 'Profili Düzenle', 
                icon: Icons.edit_note_rounded, 
                color: kPrimaryOrange.withOpacity(0.1), 
                textColor: kPrimaryOrange
              )
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: _handleLogout, 
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent), 
              style: IconButton.styleFrom(
                backgroundColor: Colors.redAccent.withOpacity(0.1),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              )
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildPointsProgressBar(user),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: _showAccountSettings, 
          icon: const Icon(Icons.shield_outlined, size: 18), 
          label: const Text("Hesap Ayarları"), 
          style: TextButton.styleFrom(foregroundColor: Colors.grey, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
        ),
        const Text(" • ", style: TextStyle(color: Colors.grey)),
        TextButton.icon(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen())), 
          icon: const Icon(Icons.feedback_outlined, size: 18), 
          label: const Text("Geri Bildirim"), 
          style: TextButton.styleFrom(foregroundColor: Colors.grey, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
        ),
      ],
    );
  }

  Widget _buildPointsProgressBar(UserModel user) {
    int points = user.points;
    double progress = (points / 500).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryOrange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hediye Kazanmaya Kalan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('$points / 500', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: kPrimaryOrange)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: kPrimaryOrange.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimaryOrange),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required VoidCallback onPressed, required String label, required IconData icon, required Color color, required Color textColor}) {
    return ElevatedButton.icon(
      onPressed: onPressed, 
      icon: Icon(icon, size: 20), 
      label: Text(label), 
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        foregroundColor: textColor, 
        elevation: 0, 
        padding: const EdgeInsets.symmetric(vertical: 14), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)
      )
    );
  }

  Widget _buildUserLinks(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text("Aktivite & Topluluk", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
        _buildProfileLink(
          icon: Icons.calendar_today_rounded,
          title: "Düzenlediği Etkinlikler",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileEventsScreen(userId: user.uid, userName: user.name, type: 'organized'))),
        ),
        const SizedBox(height: 12),
        _buildProfileLink(
          icon: Icons.task_alt_rounded,
          title: "Katıldığı Etkinlikler",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileEventsScreen(userId: user.uid, userName: user.name, type: 'joined'))),
        ),
        const SizedBox(height: 12),
        _buildProfileLink(
          icon: Icons.groups_2_rounded,
          title: "Üye Olduğu Topluluklar",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserCommunitiesScreen(userId: user.uid, userName: user.name))),
        ),
        if (_isMe) ...[
          const SizedBox(height: 12),
          _buildProfileLink(
            icon: Icons.help_outline_rounded,
            title: "Uygulama Nasıl Kullanılır?",
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HowToUseScreen())),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileLink({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: kPrimaryOrange, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRestrictionWarning(UserModel user) {
    if (!user.isRestricted) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.shade100)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Kısıtlanmış Hesap", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
          const SizedBox(height: 8),
          const Text("Hesabınız kısıtlanmıştır. Kurallara uymadığınız için bazı özellikler devre dışı bırakıldı.", style: TextStyle(fontSize: 13, color: Colors.red)),
          if (_isMe) TextButton(onPressed: () => _showAppealDialog(user), child: const Text("İtiraz Et", style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
        ],
      ),
    );
  }

  Widget _buildRecommendations(UserModel user) {
    if (user.favoriteBooks.isEmpty && user.favoriteMovies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Tavsiyeler", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (user.favoriteBooks.isNotEmpty) _buildRecItem("📚 Favori Kitaplar", user.favoriteBooks.join(", ")),
        if (user.favoriteMovies.isNotEmpty) _buildRecItem("🎬 Favori Filmler", user.favoriteMovies.join(", ")),
      ],
    );
  }

  Widget _buildRecItem(String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)), const SizedBox(height: 4), Text(content, style: const TextStyle(fontSize: 13, height: 1.3))]),
    );
  }

  Widget _buildSupporterSection(UserModel user) {
    final bool isSupporter = user.isSupporter;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.stars, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSupporter ? 'Harika Bir Destekçisin! ❤️' : 'Uygulamayı Destekle',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      isSupporter 
                        ? 'Desteğin sayesinde Eventful büyümeye devam ediyor.' 
                        : 'Özel rozetler kazanmak ve bize katkıda bulunmak ister misin?',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupporterScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange.shade800,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isSupporter ? 'Destek Seviyeni Değiştir' : 'Destekçi Ol ve Rozet Kazan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          children: [
            _buildLink("Gizlilik", "privacy"),
            _buildLink("Kullanım Koşulları", "terms"),
            _buildLink("KVKK", "kvkk"),
          ],
        ),
      ],
    );
  }

  Widget _buildLink(String text, String type) => InkWell(onTap: () => _showLegal(text, type), child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline)));

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showAccountSettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Hesap Ayarları", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(leading: const Icon(Icons.pause_circle_outline, color: Colors.orange), title: const Text("Hesabı Dondur"), subtitle: const Text("Profilin geçici olarak gizlenir."), onTap: () { Navigator.pop(context); _confirmAction("dondur"); }),
            ListTile(leading: const Icon(Icons.delete_forever, color: Colors.red), title: const Text("Hesabı Sil"), subtitle: const Text("Tüm verilerin kalıcı olarak silinir."), onTap: () { Navigator.pop(context); _confirmAction("sil"); }),
          ],
        ),
      ),
    );
  }

  void _confirmAction(String action) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Hesabı ${action == 'sil' ? 'Sil' : 'Dondur'}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: action == 'sil' ? Colors.red.withOpacity(0.05) : Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text(action == 'sil' ? "UYARI: Hesabınız silindiğinde tüm verileriniz kalıcı olarak yok edilir." : "BİLGİ: Hesabınız dondurulduğunda görünmez olur, giriş yaparak açabilirsiniz.", style: TextStyle(fontSize: 12, color: action == 'sil' ? Colors.red : Colors.orange))),
            const SizedBox(height: 16),
            TextField(controller: controller, decoration: const InputDecoration(labelText: "Neden belirtin...", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              
              final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
              final myName = myDoc.data()?['name'] ?? 'Kullanıcı';

              await FirebaseFirestore.instance.collection('reports').add({
                'category': 'account_action',
                'targetId': _currentUserId,
                'targetUserName': myName,
                'action': action,
                'reason': controller.text,
                'reporterId': _currentUserId,
                'reporterName': myName,
                'status': 'pending',
                'timestamp': FieldValue.serverTimestamp()
              });

              if (action == 'sil') await _authService.deleteAccount(reason: controller.text);
              else await _authService.freezeAccount(controller.text);
              if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(backgroundColor: action == 'sil' ? Colors.red : Colors.orange),
            child: const Text("Onayla"),
          ),
        ],
      ),
    );
  }

  void _showLegal(String title, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('app_settings').doc('policies').get(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            return SingleChildScrollView(child: Text((snap.data!.data() as Map?)?[type] ?? "Metin bulunamadı."));
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Kapat"))],
      ),
    );
  }

  void _showReportDialog(UserModel target) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${target.name} Şikayet Et"),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: "Neden?", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(onPressed: () async {
            if (controller.text.isEmpty) return;

            final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
            final myName = myDoc.data()?['name'] ?? 'Kullanıcı';

            await FirebaseFirestore.instance.collection('reports').add({
              'category': 'user_report',
              'targetId': target.uid,
              'targetUserName': target.name,
              'reporterId': _currentUserId,
              'reporterName': myName,
              'reason': controller.text,
              'status': 'pending',
              'timestamp': FieldValue.serverTimestamp()
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şikayet iletildi")));
          }, child: const Text("Gönder")),
        ],
      ),
    );
  }

  void _showAppealDialog(UserModel user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İtiraz Et"),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: "İtirazınızı yazın...", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(onPressed: () async {
            if (controller.text.isEmpty) return;

            final myDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
            final myName = myDoc.data()?['name'] ?? 'Kullanıcı';

            await FirebaseFirestore.instance.collection('reports').add({
              'category': 'appeal',
              'targetId': user.uid,
              'targetUserName': user.name,
              'reporterId': _currentUserId,
              'reporterName': myName,
              'reason': controller.text,
              'status': 'pending',
              'timestamp': FieldValue.serverTimestamp()
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İtiraz iletildi")));
          }, child: const Text("Gönder")),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
