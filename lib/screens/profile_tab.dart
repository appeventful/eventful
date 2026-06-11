import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/score_service.dart';
import '../widgets/custom_avatar.dart';
import 'settings_screen.dart';
import 'friends_list_screen.dart';
import 'feedback_screen.dart';
import 'policy_detail_screen.dart';
import 'user_reviews_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_panel_screen.dart';
import '../widgets/full_screen_image.dart';
import '../models/event_model.dart';
import '../widgets/event_card.dart';
import '../utils/constants.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _authService = AuthService();
  final _storageService = StorageService();
  String _activeTab = 'organized';
  bool _isUploading = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      ScoreService.instance.checkUserPendingDuties(_currentUserId!);
      ScoreService.instance.checkDailyLogin();
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

  Future<void> _launchInstagram(UserModel user) async {
    final handle = user.instagramHandle;
    if (handle == null || handle.isEmpty) return;

    final nativeUrl = Uri.parse("instagram://user?username=$handle");
    final webUrl = Uri.parse("https://www.instagram.com/$handle");
    
    try {
      bool launched = false;
      if (await canLaunchUrl(nativeUrl)) {
        launched = await launchUrl(nativeUrl);
      } else {
        launched = await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }

      if (launched && !user.isInstagramFollowed) {
        await ScoreService.instance.updateScore(
          userId: user.uid,
          amount: ScoreService.instagramFollowReward,
          reason: 'Instagram Takip Ödülü',
          relatedId: 'instagram_follow',
        );
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isInstagramFollowed': true,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Instagram açılamadı")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(_currentUserId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return const Scaffold(body: Center(child: Text("Kullanıcı bulunamadı")));
        
        final user = UserModel.fromFirestore(snapshot.data!);
        
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: const Text('Profilim', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _showLogoutDialog,
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const SizedBox(height: 10),
              _buildProfileHeader(user),
              const SizedBox(height: 16),
              _buildUserBasicInfo(user),
              const SizedBox(height: 24),
              _buildPointsProgressBar(user),
              const SizedBox(height: 24),
              _buildScoreBoard(user),
              const SizedBox(height: 24),
              if (user.isStaff) ...[
                _buildStaffPanelAction(user),
                const SizedBox(height: 24),
              ],
              _buildMyProfileActions(user),
              const SizedBox(height: 24),
              _buildRestrictionWarning(user),
              _buildRecommendations(user),
              const SizedBox(height: 24),
              _buildEventsTabs(user),
              const SizedBox(height: 20),
              _buildFooterLinks(),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    final String finalImageUrl = user.getEffectiveImageUrl(isMe: true);

    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          GestureDetector(
            onTap: () {
              if (finalImageUrl.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenImage(
                      imageUrl: finalImageUrl,
                      heroTag: 'profile_avatar_${user.uid}',
                      name: user.name,
                    ),
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.orange.withAlpha(51), width: 3)),
              child: _isUploading 
                ? const SizedBox(width: 120, height: 120, child: Center(child: CircularProgressIndicator()))
                : Hero(
                    tag: 'profile_avatar_${user.uid}',
                    child: CustomAvatar(
                      user: user,
                      isMe: true,
                      radius: 60,
                      backgroundColor: Colors.orange.withAlpha(26),
                      isPassive: user.isPassive,
                    ),
                  ),
            ),
          ),
          GestureDetector(
            onTap: () => _showImageSourceSelector(user),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceSelector(UserModel user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("Profil Fotoğrafı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galeriden Seç"),
              onTap: () {
                Navigator.pop(context);
                _handleImageUpload(user, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Kamera ile Çek"),
              onTap: () {
                Navigator.pop(context);
                _handleImageUpload(user, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.face),
              title: const Text("Karakter Ayarlarını Aç"),
              onTap: () {
                Navigator.pop(context);
                _showEditSheet(user);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageUpload(UserModel user, ImageSource source) async {
    final File? image = await _storageService.pickImage(source);
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final String? downloadUrl = await _storageService.uploadProfilePhoto(user.uid, image);
      if (downloadUrl != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'profileImage': downloadUrl,
          'useCharacterImage': false,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil fotoğrafı güncellendi")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Yükleme hatası: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildUserBasicInfo(UserModel user) {
    String ageHoroscope = "";
    if (user.birthDate != null) {
      DateTime bd = user.birthDate!.toDate();
      int age = DateTime.now().year - bd.year;
      if (DateTime.now().month < bd.month || (DateTime.now().month == bd.month && DateTime.now().day < bd.day)) age--;
      List<String> parts = [];
      if (!user.hideAge) parts.add("$age Yaş");
      if (!user.hideHoroscope) parts.add(_calculateHoroscope(bd));
      ageHoroscope = parts.join(" • ");
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: user.isPassive ? Colors.grey : Theme.of(context).textTheme.bodyLarge?.color,
                decoration: user.isPassive ? TextDecoration.lineThrough : null,
              ),
            ),
            if (user.isFounder) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Colors.amber, size: 20)),
          ],
        ),
        Text(
          "@${user.username}",
          style: TextStyle(
            color: user.isPassive ? Theme.of(context).textTheme.bodySmall?.color?.withAlpha(128) : Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 14,
            decoration: user.isPassive ? TextDecoration.lineThrough : null,
          ),
        ),
        if (user.instagramHandle != null && user.instagramHandle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InkWell(
              onTap: () => _launchInstagram(user),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCAF45)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "@${user.instagramHandle}",
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    if (!user.isInstagramFollowed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text("+50 Puan", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text("Instagram Ekle & 50 Puan Kazan!"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.pink,
                side: const BorderSide(color: Colors.pink),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
        if (ageHoroscope.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(ageHoroscope, style: TextStyle(color: user.isPassive ? Colors.grey : Colors.orange, fontWeight: FontWeight.w500, fontSize: 13))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (user.isFrozen) _buildBadge("DONDURULMUŞ HESAP", Colors.blueGrey),
            if (user.isDeleted) _buildBadge("SİLİNMİŞ HESAP", Colors.red),
            if (user.role == 'admin') _buildBadge("ADMIN", Colors.red),
            if (user.role == 'moderator') _buildBadge("MODERATÖR", Colors.purple),
            if (user.role == 'city_representative') _buildBadge("${user.responsibleCity ?? "İL"} TEMSİLCİSİ", Colors.teal),
          ],
        ),
        if (user.bio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(user.bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.4, color: user.isPassive ? Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(128) : Theme.of(context).textTheme.bodyMedium?.color))),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.5))),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPointsProgressBar(UserModel user) {
    int points = user.points;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Ödüle Kalan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('$points / 500 Puan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (points / 500).clamp(0.0, 1.0),
            backgroundColor: Theme.of(context).dividerColor.withAlpha(26),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreBoard(UserModel user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildScoreItem("Arkadaş", user.friends.length.toString(), Icons.people_outline, Colors.blue, onTap: () => _showList('friends')),
        _buildScoreItem("Güven", user.trustScore.toStringAsFixed(1), Icons.shield_outlined, Colors.green, showStar: true, onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => UserReviewsScreen(targetUserId: user.uid, targetUserName: user.name)));
        }),
        _buildScoreItem("Puan", user.points.toString(), Icons.emoji_events, Colors.orange),
      ],
    );
  }

  Widget _buildScoreItem(String label, String value, IconData icon, Color color, {VoidCallback? onTap, bool showStar = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange)),
              if (showStar) const Icon(Icons.star, color: Colors.amber, size: 18),
            ],
          ),
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)),
          if (onTap != null) Text('Detaylar >', style: TextStyle(fontSize: 10, color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(128))),
        ],
      ),
    );
  }

  void _showList(String type) => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsListScreen(userId: _currentUserId!, userName: '', listType: type)));

  Widget _buildStaffPanelAction(UserModel user) {
    String panelTitle = "Yönetim Paneli";
    IconData panelIcon = Icons.admin_panel_settings;
    Color panelColor = Colors.red;

    if (user.isCityRepresentative) {
      panelTitle = "İl Temsilcisi Paneli";
      panelIcon = Icons.location_city;
      panelColor = Colors.teal;
    } else if (user.role == 'moderator') {
      panelTitle = "Moderatör Paneli";
      panelIcon = Icons.security;
      panelColor = Colors.purple;
    }

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [panelColor, panelColor.withValues(alpha: 0.7)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: panelColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Row(
          children: [
            Icon(panelIcon, color: Colors.white, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    panelTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Sistemi yönetmek için buraya dokunun",
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMyProfileActions(UserModel user) {
    return Row(
      children: [
        _buildActionButton(
          label: 'Düzenlenen',
          count: 'organized',
          isActive: _activeTab == 'organized',
          onTap: () => setState(() => _activeTab = 'organized'),
          userId: user.uid,
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          label: 'Katılınan',
          count: 'joined',
          isActive: _activeTab == 'joined',
          onTap: () => setState(() => _activeTab = 'joined'),
          userId: user.uid,
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          label: 'Rozetler',
          count: 'badges',
          isActive: _activeTab == 'badges',
          onTap: () => setState(() => _activeTab = 'badges'),
          userId: user.uid,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required String count,
    required bool isActive,
    required VoidCallback onTap,
    required String userId,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.orange : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(15),
            border: !isActive ? Border.all(color: Theme.of(context).dividerColor.withAlpha(26)) : null,
            boxShadow: isActive ? [BoxShadow(color: Colors.orange.withAlpha(77), blurRadius: 8, offset: const Offset(0, 4))] : null,
          ),
          child: Column(
            children: [
              if (count == 'badges')
                Icon(Icons.badge, color: isActive ? Colors.white : Colors.orange, size: 20)
              else
                StreamBuilder<QuerySnapshot>(
                  stream: count == 'organized'
                      ? FirebaseFirestore.instance.collection('events').where('creatorId', isEqualTo: userId).snapshots()
                      : FirebaseFirestore.instance.collection('events').where('participants', arrayContains: userId).snapshots(),
                  builder: (context, snap) {
                    int val = 0;
                    if (count == 'organized') {
                      val = snap.data?.docs.length ?? 0;
                    } else {
                      val = (snap.data?.docs ?? []).where((d) => (d.data() as Map)['creatorId'] != userId).length;
                    }
                    return Text(
                      val.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color?.withAlpha(180),
                      ),
                    );
                  },
                ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isActive ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictionWarning(UserModel user) {
    if (!user.isRestricted) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.red.withAlpha(26), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.red.withAlpha(51))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text("Kısıtlanmış Hesap", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
          const SizedBox(height: 8),
          const Text("Hesabınız kısıtlanmıştır. Kurallara uymadığınız için bazı özellikler devre dışı bırakıldı.", style: TextStyle(fontSize: 13, color: Colors.red)),
          TextButton(onPressed: () => _showAppealDialog(user), child: const Text("İtiraz Et", style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline))),
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
      decoration: BoxDecoration(color: Colors.orange.withAlpha(26), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)), const SizedBox(height: 4), Text(content, style: const TextStyle(fontSize: 13, height: 1.3))]),
    );
  }

  Widget _buildEventsTabs(UserModel user) {
    if (_activeTab == 'badges') {
      return _buildBadgesTab(user);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_activeTab == 'organized' ? "Düzenlediğim Etkinlikler" : "Katıldığım Etkinlikler", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: _activeTab == 'organized' 
            ? FirebaseFirestore.instance.collection('events').where('creatorId', isEqualTo: user.uid).snapshots()
            : FirebaseFirestore.instance.collection('events').where('participants', arrayContains: user.uid).snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            var docs = snap.data!.docs;
            if (_activeTab == 'organized') {
              docs = docs.where((d) => (d.data() as Map)['creatorId'] == user.uid).toList();
            } else {
              docs = docs.where((d) => (d.data() as Map)['creatorId'] != user.uid).toList();
            }
            if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(30), child: Center(child: Text("Henüz bir etkinlik yok.", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(128)))));
            
            // Convert to models and sort by date (newest first)
            final events = docs.map((doc) => EventModel.fromFirestore(doc)).toList();
            // Pre-sorting outside of the builder's main loop if possible, but here it's already done per rebuild.
            events.sort((a, b) => b.eventDate.compareTo(a.eventDate));

            return ListView.builder(
              shrinkWrap: true, 
              physics: const NeverScrollableScrollPhysics(), 
              itemCount: events.length, 
              // Optimization: Added itemExtent for better scroll performance if elements have fixed height
              // but since EventCard might vary slightly (unlikely here but good to keep in mind), 
              // we'll stick to basic builder for now. 
              itemBuilder: (context, i) => EventCard(key: ValueKey(events[i].id), event: events[i]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBadgesTab(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Rozetlerim", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: availableBadges.length,
          itemBuilder: (context, index) {
            final badge = availableBadges[index];
            final bool isEarned = user.badges.contains(badge['id']);
            
            return GestureDetector(
              onTap: () => _showBadgeDetail(badge, isEarned),
              child: Container(
                decoration: BoxDecoration(
                  color: isEarned ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isEarned ? Colors.orange.withOpacity(0.3) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ColorFiltered(
                      colorFilter: isEarned 
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                        : const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                      child: Text(badge['icon'], style: const TextStyle(fontSize: 32)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      badge['name'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isEarned ? Colors.orange : Colors.grey,
                      ),
                    ),
                    if (!isEarned)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showBadgeDetail(Map<String, dynamic> badge, bool isEarned) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(badge['icon'], style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 16),
            Text(
              badge['name'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isEarned ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isEarned ? "KAZANILDI" : "HENÜZ KAZANILMADI",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isEarned ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              badge['description'] ?? 'Bu rozet için açıklama bulunamadı.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Kapat"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        Center(child: Text('Kurumsal & Yasal', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.bold))),
        const SizedBox(height: 10),
        _buildLegalItem(Icons.description_outlined, 'Kullanım Koşulları', 'terms'),
        _buildLegalItem(Icons.privacy_tip_outlined, 'Gizlilik Politikası', 'privacy'),
        _buildLegalItem(Icons.gavel_outlined, 'KVKK Aydınlatma Metni', 'kvkk'),
        _buildLegalItem(Icons.feedback_outlined, 'Geri Bildirim Gönder', 'feedback'),
        const Divider(height: 40),
        _buildDangerZone(),
      ],
    );
  }

  Widget _buildLegalItem(IconData icon, String title, String type) {
    return ListTile(
      leading: Icon(icon, color: Colors.orange, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      contentPadding: EdgeInsets.zero,
      onTap: () {
        if (type == 'feedback') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PolicyDetailScreen(title: title, policyType: type)));
        }
      },
    );
  }

  Widget _buildDangerZone() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(onPressed: () => _confirmAction("dondur"), child: const Text('Hesabı Dondur', style: TextStyle(color: Colors.orange))),
        Text(" • ", style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(128))),
        TextButton(onPressed: () => _confirmAction("sil"), child: const Text('Hesabı Sil', style: TextStyle(color: Colors.red))),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumunuzu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          TextButton(onPressed: () {
            _authService.logout();
            Navigator.pop(context);
          }, child: const Text('Çıkış', style: TextStyle(color: Colors.red))),
        ],
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
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: action == 'sil' ? Colors.red.withAlpha(26) : Colors.orange.withAlpha(26), borderRadius: BorderRadius.circular(8)), child: Text(action == 'sil' ? "UYARI: Hesabınız silindiğinde tüm verileriniz kalıcı olarak yok edilir." : "BİLGİ: Hesabınız dondurulduğunda görünmez olur, giriş yaparak açabilirsiniz.", style: TextStyle(fontSize: 12, color: action == 'sil' ? Colors.red.shade900 : Colors.orange.shade900))),
            const SizedBox(height: 16),
            TextField(controller: controller, decoration: const InputDecoration(labelText: "Neden belirtin...", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              await FirebaseFirestore.instance.collection('reports').add({'category': 'account_action', 'action': action, 'reason': controller.text, 'userId': _currentUserId, 'timestamp': FieldValue.serverTimestamp()});
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

  void _showEditSheet(UserModel user) {
    final name = TextEditingController(text: user.name);
    final username = TextEditingController(text: user.username);
    final phone = TextEditingController(text: user.phone);
    final bio = TextEditingController(text: user.bio);
    final books = TextEditingController(text: user.favoriteBooks.join(", "));
    final movies = TextEditingController(text: user.favoriteMovies.join(", "));
    bool hAge = user.hideAge;
    bool hHoro = user.hideHoroscope;
    bool uChar = user.useCharacterImage;
    String gen = user.gender ?? 'male';
    if (gen != 'male' && gen != 'female' && gen != 'other') {
      gen = 'other';
    }
    String cImg = user.characterImage ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Profili Düzenle", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: name, decoration: const InputDecoration(labelText: "Ad Soyad", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: username, decoration: const InputDecoration(labelText: "Kullanıcı Adı", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: phone, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: bio, maxLines: 2, decoration: const InputDecoration(labelText: "Biyografi", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: books, decoration: const InputDecoration(labelText: "Tavsiye Kitaplar (Virgül ile ayırın)", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: movies, decoration: const InputDecoration(labelText: "Tavsiye Filmler (Virgül ile ayırın)", border: OutlineInputBorder())),
                const SizedBox(height: 12),
                SwitchListTile(title: const Text("Yaşımı Gizle"), value: hAge, onChanged: (v) => setS(() => hAge = v)),
                SwitchListTile(title: const Text("Burcumu Gizle"), value: hHoro, onChanged: (v) => setS(() => hHoro = v)),
                const Divider(),
                const Text("Karakter Resmi (Karikatür)", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: gen,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text("Erkek")),
                    DropdownMenuItem(value: 'female', child: Text("Kadın")),
                    DropdownMenuItem(value: 'other', child: Text("Diğer")),
                  ],
                  onChanged: (v) => setS(() => gen = v!),
                ),
                SwitchListTile(title: const Text("Karakter Resmi Kullan"), value: uChar, onChanged: (v) => setS(() => uChar = v)),
                if (uChar) TextButton.icon(onPressed: () { 
                  final r = DateTime.now().millisecond; 
                  // Cinsiyete göre farklı tipte avatarlar oluşturmak için seed kısmını düzenledik
                  String avatarType = gen == 'male' ? 'male' : (gen == 'female' ? 'female' : 'human');
                  setS(() => cImg = "https://api.dicebear.com/7.x/avataaars/png?seed=$avatarType$r"); 
                }, icon: const Icon(Icons.refresh), label: const Text("Resmi Değiştir")),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'name': name.text.trim(),
                    'username': username.text.trim(),
                    'phone': phone.text.trim(),
                    'bio': bio.text.trim(),
                    'favoriteBooks': books.text.split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    'favoriteMovies': movies.text.split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    'hideAge': hAge, 'hideHoroscope': hHoro, 'gender': gen, 'useCharacterImage': uChar, 'characterImage': cImg,
                  });
                  Navigator.pop(context);
                }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), child: const Text("Kaydet"))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
            await FirebaseFirestore.instance.collection('reports').add({'category': 'appeal', 'targetId': user.uid, 'reason': controller.text, 'status': 'pending', 'timestamp': FieldValue.serverTimestamp()});
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("İtiraz iletildi")));
          }, child: const Text("Gönder")),
        ],
      ),
    );
  }
}
