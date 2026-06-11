import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../widgets/custom_avatar.dart';
import '../services/notification_service.dart';
import '../services/score_service.dart';
import '../services/social_service.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../widgets/social_share_card.dart';
import '../utils/constants.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import 'event_detail_screen.dart';
import 'profile_screen.dart';
import '../services/event_scraper_service.dart';
import '../utils/city_centers.dart';
import '../utils/sharing_templates.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import '../services/admin_log_service.dart';

// Yeni Sekme Bileşenleri
import 'admin_panel/statistics_tab.dart';
import 'admin_panel/users_tab.dart';
import 'admin_panel/events_tab.dart';
import 'admin_panel/communities_tab.dart';
import 'admin_panel/social_media_tab.dart';
import 'admin_panel/reports_tab.dart';
import 'admin_panel/notifications_tab.dart';
import 'admin_panel/feedback_tab.dart';
import 'admin_panel/settings_tab.dart';
import 'admin_panel/staff_tab.dart';
import 'admin_panel/admin_logs_tab.dart';
import 'admin_panel/internal_chat_tab.dart';
import 'admin_panel/support_requests_tab.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SocialService _socialService = SocialService();
  final AdminLogService _logService = AdminLogService();
  late TabController _tabController;
  
  String _userStatusFilter = 'Fotoğraf Onayı Bekleyenler';
  String _eventStatusFilter = 'Onay Bekleyenler';
  String _currentAppVersion = "2.3.2+17";

  UserModel? _me;
  bool _isMeLoading = true;

  bool get isAdmin => _me?.isAdmin ?? (FirebaseAuth.instance.currentUser?.email == adminEmail);

  List<int>? _cachedCounts;
  bool _isLoadingStats = false;
  int _activeTabIndex = 0;
  String? _lastIndexError;

  final List<String> _cities = cities;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadCurrentVersion();
    _refreshStats();
  }

  Future<void> _loadMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _me = UserModel.fromFirestore(doc);
            _isMeLoading = false;
            
            int len;
            if (_me?.isCityRepresentative == true && !isAdmin) {
              len = 6;
            } else if (_me?.isModerator == true && !isAdmin) {
              len = 11;
            } else {
              len = isAdmin ? 15 : 12;
            }

            _tabController = TabController(length: len, vsync: this);
            _tabController.addListener(() {
              if (!_tabController.indexIsChanging) {
                setState(() => _activeTabIndex = _tabController.index);
              }
            });
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isMeLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentAppVersion = "${packageInfo.version}+${packageInfo.buildNumber}";
      });
    }
  }

  Future<void> _refreshStats() async {
    if (_isLoadingStats) return;
    setState(() => _isLoadingStats = true);
    try {
      final counts = await _getStatisticsCounts();
      if (mounted) {
        setState(() {
          _cachedCounts = counts;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<List<int>> _getStatisticsCounts() async {
    Future<int> safeCount(Query query) {
      return query.count().get().then((v) => (v.count ?? 0).toInt()).catchError((e) {
        String errorStr = e.toString();
        if (errorStr.contains('https://console.firebase.google.com')) _lastIndexError = errorStr;
        return -1; 
      });
    }

    Query usersQ = _db.collection('users');
    Query eventsQ = _db.collection('events');
    Query reportsQ = _db.collection('reports').where('status', isEqualTo: 'pending');
    Query feedbackQ = _db.collection('feedback');
    Query bannedQ = _db.collection('users').where('isBanned', isEqualTo: true);
    Query restrictedQ = _db.collection('users').where('isRestricted', isEqualTo: true);
    Query frozenQ = _db.collection('users').where('isFrozen', isEqualTo: true);
    Query deletedQ = _db.collection('users').where('isDeleted', isEqualTo: true);

    if (_me?.isCityRepresentative == true && _me?.responsibleCity != null) {
      eventsQ = eventsQ.where('city', isEqualTo: _me!.responsibleCity);
      reportsQ = reportsQ.where('city', isEqualTo: _me!.responsibleCity);
      feedbackQ = feedbackQ.where('city', isEqualTo: _me!.responsibleCity);
    }

    return Future.wait([
      safeCount(usersQ), // 0
      safeCount(eventsQ), // 1
      safeCount(reportsQ), // 2
      safeCount(feedbackQ), // 3
      safeCount(bannedQ), // 4
      safeCount(restrictedQ), // 5
      safeCount(frozenQ), // 6
      safeCount(deletedQ), // 7
      safeCount(_db.collection('users').where('lastLogin', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 5))))), // 8
      safeCount(_db.collection('reference_requests').where('status', isEqualTo: 'open')), // 9
      safeCount(_db.collection('push_notifications').where('status', isEqualTo: 'pending')), // 10
      safeCount(eventsQ.where('isArchived', isEqualTo: false).where('isApproved', isEqualTo: true)), // 11
      safeCount(eventsQ.where('isArchived', isEqualTo: true)), // 12
      safeCount(_db.collection('active_guests').where('lastActive', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: 5))))), // 13
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isMeLoading) {
      return const Scaffold(
        backgroundColor: kDeepCharcoal,
        body: Center(child: CircularProgressIndicator(color: kPrimaryOrange)),
      );
    }

    final bool isCityRep = _me?.isCityRepresentative ?? false;

    List<Tab> tabs = [];
    List<Widget> tabViews = [];

    if (isCityRep && !isAdmin) {
      tabs = const [Tab(text: 'İstatistik'), Tab(text: 'Personel Sohbet'), Tab(text: 'Destek Talepleri'), Tab(text: 'Etkinlikler'), Tab(text: 'Raporlar'), Tab(text: 'Geri Bildirim')];
      tabViews = [
        _buildStatsTab(),
        InternalChatTab(chatPath: 'staff_all', title: 'Personel Sohbeti', me: _me),
        const SupportRequestsTab(),
        _buildEventsTab(),
        _buildReportsTab(),
        _buildFeedbackTab(),
      ];
    } else if (_me?.isModerator == true && !isAdmin) {
      tabs = const [Tab(text: 'İstatistik'), Tab(text: 'Personel Sohbet'), Tab(text: 'Yönetim Sohbet'), Tab(text: 'Destek Talepleri'), Tab(text: 'Kullanıcılar'), Tab(text: 'Referanslar'), Tab(text: 'Etkinlikler'), Tab(text: 'Topluluklar'), Tab(text: 'Raporlar'), Tab(text: 'Bildirimler'), Tab(text: 'Geri Bildirim')];
      tabViews = [
        _buildStatsTab(),
        InternalChatTab(chatPath: 'staff_all', title: 'Personel Sohbeti', me: _me),
        InternalChatTab(chatPath: 'admin_mod', title: 'Yönetim Sohbeti', me: _me),
        const SupportRequestsTab(),
        _buildUsersTab(),
        _buildReferenceRequests(),
        _buildEventsTab(),
        _buildCommunitiesTab(),
        _buildReportsTab(),
        _buildNotificationsTab(),
        _buildFeedbackTab(),
      ];
    } else {
      tabs = [
        const Tab(text: 'İstatistik'),
        const Tab(text: 'Personel Sohbet'),
        const Tab(text: 'Yönetim Sohbet'),
        const Tab(text: 'Destek Talepleri'),
        if (isAdmin) const Tab(text: 'Yetkili Yönetimi'),
        if (isAdmin) const Tab(text: 'Yönetim Logları'),
        const Tab(text: 'Kullanıcılar'),
        const Tab(text: 'Referanslar'),
        const Tab(text: 'Etkinlikler'),
        const Tab(text: 'Topluluklar'),
        const Tab(text: 'Sosyal Medya'),
        const Tab(text: 'Raporlar'),
        const Tab(text: 'Bildirimler'),
        const Tab(text: 'Geri Bildirim'),
        if (isAdmin) const Tab(text: 'Sistem Ayarları'),
      ];
      tabViews = [
        _buildStatsTab(),
        InternalChatTab(chatPath: 'staff_all', title: 'Personel Sohbeti', me: _me),
        InternalChatTab(chatPath: 'admin_mod', title: 'Yönetim Sohbeti', me: _me),
        const SupportRequestsTab(),
        if (isAdmin) StaffTab(onShowUserOptions: _showUserOptions),
        if (isAdmin) const AdminLogsTab(),
        _buildUsersTab(),
        _buildReferenceRequests(),
        _buildEventsTab(),
        _buildCommunitiesTab(),
        _buildSocialMediaTab(),
        _buildReportsTab(),
        _buildNotificationsTab(),
        _buildFeedbackTab(),
        if (isAdmin) _buildSettingsTab(),
      ];
    }

    int communityTabIndex = -1;
    if (isAdmin) communityTabIndex = 9;
    else if (_me?.isModerator == true) communityTabIndex = 7;

    return Scaffold(
      backgroundColor: kDeepCharcoal,
      appBar: AppBar(
        title: Text(isCityRep && !isAdmin ? 'İl Temsilcisi Paneli' : 'Yönetim Paneli', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: kSurfaceDark,
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: kPrimaryOrange),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: tabs.length > 4,
          labelColor: kPrimaryOrange,
          unselectedLabelColor: Colors.white60,
          indicatorColor: kPrimaryOrange,
          tabs: tabs,
        ),
      ),
      body: Theme(
        data: Theme.of(context).copyWith(brightness: Brightness.dark, scaffoldBackgroundColor: kDeepCharcoal),
        child: TabBarView(controller: _tabController, children: tabViews),
      ),
      floatingActionButton: (_activeTabIndex == communityTabIndex && communityTabIndex != -1)
          ? FloatingActionButton(onPressed: _showAddCommunityDialog, backgroundColor: kPrimaryOrange, child: const Icon(Icons.add, color: kDeepCharcoal))
          : null,
      bottomNavigationBar: _lastIndexError != null ? Container(
        color: Colors.orange.shade800,
        padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_fix_high, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'İNDEKS LİNKİ AKTİFLEŞTİRİLDİ!',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Aşağıdaki butona basarak o uzun linkteki işlemi otomatik olarak başlatabilirsiniz.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  final url = _extractIndexUrl(_lastIndexError!);
                  if (url != null) _launchUrl(url);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('İNDEKSİ ŞİMDİ OLUŞTUR (TIKLA)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.orange.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ) : null,
    );
  }

  // --- SEKMELERE ÖZEL BUILDERLAR (Callbackleri bağlamak için) ---
  
  Widget _buildStatsTab() => StatisticsTab(
    cachedCounts: _cachedCounts, 
    isLoadingStats: _isLoadingStats, 
    lastIndexError: _lastIndexError,
    onRefresh: _refreshStats, 
    onJumpToTab: _jumpToTab, 
    launchUrl: _launchUrl, 
    extractIndexUrl: _extractIndexUrl
  );

  Widget _buildUsersTab() => UsersTab(
    onShowUserOptions: _showUserOptions, 
    initialStatus: _userStatusFilter,
    launchUrl: _launchUrl,
    extractIndexUrl: _extractIndexUrl,
  );

  Widget _buildEventsTab() => EventsTab(
    me: _me, 
    isAdmin: isAdmin, 
    onShowEventOptions: _showEventOptions, 
    initialFilter: _eventStatusFilter,
    launchUrl: _launchUrl,
    extractIndexUrl: _extractIndexUrl,
  );

  Widget _buildCommunitiesTab() => CommunitiesTab(
    onShowCommunityMembersDialog: _showCommunityMembersDialog, 
    onShowEditCommunityDialog: _showEditCommunityDialog, 
    onDeleteCommunity: _deleteCommunity,
    launchUrl: _launchUrl,
    extractIndexUrl: _extractIndexUrl,
  );

  Widget _buildSocialMediaTab() => SocialMediaTab(
    onShowWeeklySummary: _showWeeklySummaryGeneratorDialog, 
    onShowDailyAgenda: _showDailyAgendaGeneratorDialog, 
    onShowSocialKit: _showEventSocialKitGeneratorDialog, 
    onShowSchedulePost: _showSchedulePostDialog
  );

  Widget _buildReportsTab() => ReportsTab(me: _me, onShowReportDetail: _showReportDetailDialog, launchUrl: _launchUrl, extractIndexUrl: _extractIndexUrl);

  Widget _buildNotificationsTab() => NotificationsTab(onClearAll: _clearAllNotifications);

  Widget _buildFeedbackTab() => FeedbackTab(me: _me, onDelete: _confirmDelete);

  Widget _buildSettingsTab() => SettingsTab(
    currentAppVersion: _currentAppVersion, 
    lastIndexError: _lastIndexError,
    launchUrl: _launchUrl,
    onEditSetting: _editSetting, 
    onEditGlobalRules: _editGlobalCommunityRules, 
    onShowBulkNotification: _showBulkNotificationDialog, 
    onPokeInactiveUsers: _pokeInactiveUsers, 
    onShowBulkScraper: _showBulkScraperDialog, 
    onShowBulkEvent: _showBulkEventDialog, 
    onRunSpeedup: _runSystemSpeedup, 
    onAutoArchive: _autoArchivePastEvents, 
    onRunMigration: _runDateMigration, 
    onEditLegalText: _editLegalText
  );

  // --- NAVİGASYON ---
  void _jumpToTab(String tabKey, String filterValue) {
    int index = -1;
    final bool isCityRep = _me?.isCityRepresentative ?? false;
    final bool isMod = _me?.isModerator ?? false;

    if (isCityRep && !isAdmin) {
      if (tabKey == 'support') index = 2;
      if (tabKey == 'events') index = 3;
      if (tabKey == 'reports') index = 4;
      if (tabKey == 'feedback') index = 5;
    } else if (isMod && !isAdmin) {
      if (tabKey == 'support') index = 3;
      if (tabKey == 'users') index = 4;
      if (tabKey == 'references') index = 5;
      if (tabKey == 'events') index = 6;
      if (tabKey == 'communities') index = 7;
      if (tabKey == 'reports') index = 8;
      if (tabKey == 'notifications') index = 9;
      if (tabKey == 'feedback') index = 10;
    } else {
      if (tabKey == 'support') index = 3;
      if (tabKey == 'users') index = 6;
      if (tabKey == 'references') index = 7;
      if (tabKey == 'events') index = 8;
      if (tabKey == 'communities') index = 9;
      if (tabKey == 'social_media') index = 10;
      if (tabKey == 'reports') index = 11;
      if (tabKey == 'notifications') index = 12;
      if (tabKey == 'feedback') index = 13;
      if (tabKey == 'settings') index = 14;
    }

    if (index != -1) {
      setState(() {
        _activeTabIndex = index;
        if (tabKey == 'users') _userStatusFilter = filterValue;
        if (tabKey == 'events') _eventStatusFilter = filterValue;
      });
      _tabController.animateTo(index);
    }
  }

  // --- DİYALOGLAR VE MODAL İŞLEMLER ---
  // (Burada kalan 1500 satır kadar diyalog ve işlem mantığı kodu yer alacak)
  // [Geliştirici Notu: Dosya boyutu limitleri nedeniyle geri kalan fonksiyonları korudum]

  void _showUserOptions(String uid, Map<String, dynamic> data) {
    final String targetRole = data['role'] ?? 'user';
    final bool targetIsSuperior = targetRole == 'admin' || targetRole == 'moderator';
    final bool canManageTarget = isAdmin || !targetIsSuperior;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: kSurfaceDark, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: ListView(
            controller: scrollController,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CustomAvatar(imageUrl: data['profileImage'], radius: 30),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['name'] ?? 'Adsız', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('@${data['username'] ?? ''}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.blue),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: uid)));
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.photo_library, color: data['isProfileImageApproved'] == true ? Colors.grey : Colors.green),
                title: Text(data['isProfileImageApproved'] == true ? 'Profil Fotoğrafı Onayını Kaldır' : 'Profil Fotoğrafını Onayla'),
                onTap: () async {
                   bool newValue = !(data['isProfileImageApproved'] ?? false);
                   await _db.collection('users').doc(uid).update({'isProfileImageApproved': newValue});
                   if (newValue) {
                     await ScoreService.instance.updateScore(userId: uid, amount: ScoreService.photoShareReward, reason: 'Profil Onaylandı', relatedId: 'photo_$uid');
                   }
                   if (!context.mounted) return;
                   Navigator.pop(context);
                },
              ),
              if (isAdmin) ListTile(
                leading: Icon(Icons.verified_user, color: data['emailVerified'] == true ? Colors.grey : Colors.blue),
                title: const Text('E-postayı El İle Onayla'),
                onTap: () async {
                   await FirebaseFunctions.instance.httpsCallable('adminVerifyUserEmail').call({'uid': uid});
                   if (!context.mounted) return;
                   Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_reset, color: Colors.orange),
                title: const Text('Şifreyi Değiştir'),
                onTap: () { Navigator.pop(context); _showChangePasswordDialog(uid, data['username'] ?? 'Kullanıcı'); },
              ),
              ListTile(
                leading: const Icon(Icons.security, color: Colors.blue),
                title: const Text('Rolü ve Yetkileri Yönet'),
                enabled: canManageTarget,
                onTap: () { Navigator.pop(context); _showRoleChangeDialog(uid, data); },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.green),
                title: Text('Güven Puanı: ${data['trustScore'] ?? 0.0}'),
                subtitle: const Text('Düzenlemek için tıkla'),
                onTap: () { Navigator.pop(context); _showUpdateValueDialog(uid, 'trustScore', data['trustScore'] ?? 0.0, true); },
              ),
              ListTile(
                leading: const Icon(Icons.stars, color: Colors.amber),
                title: Text('Etkinlik Puanı: ${data['points'] ?? 0}'),
                subtitle: const Text('Düzenlemek için tıkla'),
                onTap: () { Navigator.pop(context); _showUpdateValueDialog(uid, 'points', data['points'] ?? 0, false); },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.gavel, color: data['isRestricted'] == true ? Colors.grey : Colors.orange),
                title: Text(data['isRestricted'] == true ? 'Kısıtlamayı Kaldır' : 'Kısıtla (Referans Şartı)'),
                subtitle: data['isRestricted'] == true ? Text('Kalan: ${5 - (data['referenceParticipationCount'] ?? 0)} etkinlik') : null,
                onTap: () async {
                  bool newS = !(data['isRestricted'] ?? false);
                  await _db.collection('users').doc(uid).update({
                    'isRestricted': newS,
                    'referenceParticipationCount': 0,
                  });
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.ac_unit, color: data['isFrozen'] == true ? Colors.green : Colors.cyan),
                title: Text(data['isFrozen'] == true ? 'Hesabı Aktifleştir' : 'Hesabı Dondur'),
                onTap: () async {
                  bool newS = !(data['isFrozen'] ?? false);
                  await _db.collection('users').doc(uid).update({'isFrozen': newS});
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.block, color: data['isBanned'] == true ? Colors.green : Colors.red),
                title: Text(data['isBanned'] == true ? 'Yasağı Kaldır' : 'Kullanıcıyı Yasakla'),
                enabled: canManageTarget && data['email'] != adminEmail,
                onTap: () async {
                  if (data['email'] == adminEmail) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sistem yöneticisi yasaklanamaz!')));
                    Navigator.pop(context);
                    return;
                  }
                  bool currentBanned = data['isBanned'] ?? false;
                  if (currentBanned) {
                    await _db.collection('users').doc(uid).update({'isBanned': false, 'banReason': null, 'banUntil': null});
                    await _logService.logAction(actionType: 'unban', targetId: uid, targetName: data['username'] ?? 'Adsız');
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } else {
                    Navigator.pop(context);
                    _showBanUserDialog(uid, data['username'] ?? 'Kullanıcı');
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.restore_from_trash, color: data['isDeleted'] == true ? Colors.green : Colors.grey),
                title: Text(data['isDeleted'] == true ? 'Silinmiş İşaretini Kaldır' : 'Silinmiş Olarak İşaretle'),
                onTap: () async {
                  bool newS = !(data['isDeleted'] ?? false);
                  await _db.collection('users').doc(uid).update({'isDeleted': newS});
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.badge, color: Colors.purple),
                title: const Text('Rozetleri Yönet'),
                onTap: () { Navigator.pop(context); _showManageBadgesDialog(uid, List<String>.from(data['badges'] ?? [])); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Verileri Tamamen Sil (Wipe)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(context); _showWipeDataConfirmation(uid, data['username'] ?? 'Kullanıcı'); },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- (Kalan Tüm Yardımcı Metotlar: _showEventOptions, _showReportDetailDialog, _wipeUserData vb.) ---
  // (Daha önce yazdığımız tüm mantıksal fonksiyonlar burada devam eder...)

  void _showBanUserDialog(String uid, String username) {
    final reasonC = TextEditingController();
    int days = 7;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: Text('$username - Yasakla'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: reasonC, decoration: const InputDecoration(labelText: 'Yasaklama Nedeni')),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: days,
                decoration: const InputDecoration(labelText: 'Süre'),
                items: [
                  const DropdownMenuItem(value: 1, child: Text('1 Gün')),
                  const DropdownMenuItem(value: 3, child: Text('3 Gün')),
                  const DropdownMenuItem(value: 7, child: Text('1 Hafta')),
                  const DropdownMenuItem(value: 30, child: Text('1 Ay')),
                  const DropdownMenuItem(value: 365, child: Text('1 Yıl')),
                  const DropdownMenuItem(value: 9999, child: Text('Süresiz')),
                ],
                onChanged: (v) => setS(() => days = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                DateTime? until = days == 9999 ? null : DateTime.now().add(Duration(days: days));
                await _db.collection('users').doc(uid).update({
                  'isBanned': true,
                  'banReason': reasonC.text.trim(),
                  'banUntil': until != null ? Timestamp.fromDate(until) : null,
                });
                await _logService.logAction(actionType: 'ban', targetId: uid, targetName: username);
                if (!context.mounted) return;
                Navigator.pop(context);
              }, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('YASAKLA')
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateValueDialog(String uid, String field, dynamic currentValue, bool isDouble) {
    final controller = TextEditingController(text: currentValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Değer Güncelle: $field'),
        content: TextField(
          controller: controller, 
          keyboardType: TextInputType.numberWithOptions(decimal: isDouble),
          decoration: InputDecoration(labelText: 'Yeni Değer ($currentValue)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              dynamic val = isDouble ? (double.tryParse(controller.text) ?? 0.0) : (int.tryParse(controller.text) ?? 0);
              await _db.collection('users').doc(uid).update({field: val});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _showManageBadgesDialog(String uid, List<String> currentBadges) {
    List<String> tempBadges = List.from(currentBadges);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('Rozetleri Yönet'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableBadges.length,
              itemBuilder: (context, index) {
                final badge = availableBadges[index];
                final String id = badge['id'];
                final bool has = tempBadges.contains(id);
                return CheckboxListTile(
                  title: Text('${badge['icon']} ${badge['name']}'),
                  subtitle: Text(badge['description'] ?? '', style: const TextStyle(fontSize: 10)),
                  value: has,
                  onChanged: (val) {
                    setS(() {
                      if (val == true) tempBadges.add(id);
                      else tempBadges.remove(id);
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: () async {
                await _db.collection('users').doc(uid).update({'badges': tempBadges});
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _wipeUserData(String uid) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('adminWipeUserData').call({'uid': uid});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.data['message'] ?? 'Temizlendi'), backgroundColor: Colors.green));
        _refreshStats();
      }
    } catch (e) {
      if (mounted) { 
        Navigator.pop(context); 
        _showErrorSnackBar(e);
      }
    }
  }

  void _showChangePasswordDialog(String uid, String username) {
    final passC = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text('$username - Şifre Değiştir'),
      content: TextField(controller: passC, decoration: const InputDecoration(labelText: 'Yeni Şifre'), obscureText: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(onPressed: () async {
          await FirebaseFunctions.instance.httpsCallable('adminChangeUserPassword').call({'uid': uid, 'newPassword': passC.text});
          Navigator.pop(context);
        }, child: const Text('Güncelle')),
      ],
    ));
  }

  void _showWipeDataConfirmation(String uid, String username) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("DİKKAT: Verileri Tamamen Sil"),
      content: Text("'$username' kullanıcısının tüm verileri silinecektir. Emin misiniz?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
        ElevatedButton(onPressed: () { Navigator.pop(context); _wipeUserData(uid); }, child: const Text("SİL")),
      ],
    ));
  }

  void _showRoleChangeDialog(String uid, Map<String, dynamic> data) {
    String currentRole = data['role'] ?? 'user';
    String? selectedCity = data['responsibleCity'];
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setS) => AlertDialog(
      title: const Text('Rol Yönetimi'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: currentRole,
          items: ['user', 'moderator', 'city_representative', 'admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (v) => setS(() => currentRole = v!),
        ),
        if (currentRole == 'city_representative') DropdownButtonFormField<String>(
          value: selectedCity, items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setS(() => selectedCity = v),
        )
      ]),
      actions: [
        ElevatedButton(onPressed: () async {
          await _db.collection('users').doc(uid).update({'role': currentRole, 'responsibleCity': selectedCity});
          Navigator.pop(context);
        }, child: const Text('Kaydet'))
      ],
    )));
  }

  void _showEventOptions(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(data['title'] ?? 'Etkinlik İşlemleri', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ListTile(
            leading: Icon(Icons.check_circle, color: (data['isApproved'] ?? false) ? Colors.grey : Colors.green),
            title: Text((data['isApproved'] ?? false) ? 'Onayı Kaldır' : 'Onayla'),
            onTap: () async {
              await _db.collection('events').doc(id).update({'isApproved': !(data['isApproved'] ?? false)});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.push_pin, color: (data['isPinned'] ?? false) ? Colors.blue : Colors.grey),
            title: Text((data['isPinned'] ?? false) ? 'Sabitlemeyi Kaldır' : 'Başa Sabitle'),
            onTap: () async {
              await _db.collection('events').doc(id).update({'isPinned': !(data['isPinned'] ?? false)});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.star, color: (data['isFeatured'] ?? false) ? Colors.amber : Colors.grey),
            title: Text((data['isFeatured'] ?? false) ? 'Öne Çıkarmayı Kaldır' : 'Öne Çıkar (Haftanın Fotoğrafları)'),
            onTap: () async {
              await _db.collection('events').doc(id).update({'isFeatured': !(data['isFeatured'] ?? false)});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(Icons.archive, color: (data['isArchived'] ?? false) ? Colors.green : Colors.orange),
            title: Text((data['isArchived'] ?? false) ? 'Arşivden Çıkar' : 'Arşivle'),
            onTap: () async {
              await _db.collection('events').doc(id).update({'isArchived': !(data['isArchived'] ?? false)});
              if (!context.mounted) return;
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility, color: Colors.teal),
            title: const Text('Etkinliği Görüntüle'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: id)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Tamamen Sil'),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete('events', id);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showReportDetailDialog(String reportId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kSurfaceDark,
        title: const Text('Rapor Detayı'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori: ${data['category'] ?? 'Bilinmiyor'}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Neden: ${data['reason'] ?? 'Belirtilmemiş'}'),
            const SizedBox(height: 8),
            Text('Bildiren: ${data['reporterName'] ?? 'Anonim'} (ID: ${data['reporterId'] ?? ''})'),
            const SizedBox(height: 16),
            const Text('İşlemler:', style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryOrange)),
            const SizedBox(height: 8),
            if (data['category'] == 'user' || data['category'] == 'comment') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: data['targetUserId'])));
                },
                child: const Text('Hedef Kullanıcı Profilini Gör'),
              ),
            ],
            if (data['category'] == 'event') ...[
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: data['targetId'])));
                },
                child: const Text('Hedef Etkinliği Gör'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _db.collection('reports').doc(reportId).update({'status': 'dismissed'}).then((_) => Navigator.pop(context)),
            child: const Text('Reddet', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => _db.collection('reports').doc(reportId).update({'status': 'resolved'}).then((_) => Navigator.pop(context)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Çözüldü Olarak İşaretle'),
          ),
        ],
      ),
    );
  }

  void _showAddCommunityDialog() {
    final nameC = TextEditingController();
    final descC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Topluluk Ekle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Topluluk Adı')),
            TextField(controller: descC, decoration: const InputDecoration(labelText: 'Açıklama')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (nameC.text.isEmpty) return;
              await _db.collection('communities').add({
                'name': nameC.text,
                'description': descC.text,
                'members': [],
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showCommunityMembersDialog(String id, Map<String, dynamic> data) {
    List members = data['members'] ?? [];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${data['name']} - Üyeler (${members.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: members.isEmpty 
            ? const Text('Üye yok.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: _db.collection('users').doc(members[index]).get(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      var u = snap.data!.data() as Map<String, dynamic>?;
                      return ListTile(
                        leading: CustomAvatar(imageUrl: u?['profileImage'], radius: 15),
                        title: Text(u?['username'] ?? 'Adsız'),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () async {
                            await _db.collection('communities').doc(id).update({
                              'members': FieldValue.arrayRemove([members[index]])
                            });
                            Navigator.pop(context);
                          },
                        ),
                      );
                    }
                  );
                },
              ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
      ),
    );
  }

  void _showEditCommunityDialog(String id, Map<String, dynamic> data) {
    final nameC = TextEditingController(text: data['name']);
    final descC = TextEditingController(text: data['description']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Topluluğu Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Topluluk Adı')),
            TextField(controller: descC, decoration: const InputDecoration(labelText: 'Açıklama')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('communities').doc(id).update({
                'name': nameC.text,
                'description': descC.text,
              });
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _deleteCommunity(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Topluluğu Sil'),
        content: Text("'$name' topluluğunu silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('communities').doc(id).delete();
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SİL'),
          ),
        ],
      ),
    );
  }
  void _showWeeklySummaryGeneratorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Haftalık Özet Kartı'),
        content: const Text('Bu hafta gerçekleşecek en popüler etkinliklerden oluşan bir Instagram kartı oluşturulsun mu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final events = await _socialService.getEventsForWeeklySummary();
              if (mounted) _showSocialSharePreview('weekly_summary', events);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showDailyAgendaGeneratorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Günlük Ajanda Kartı'),
        content: const Text('Bugünün etkinliklerinden oluşan bir ajanda kartı oluşturulsun mu?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final events = await _socialService.getEventsForDailyAgenda();
              if (mounted) _showSocialSharePreview('daily_agenda', events);
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  void _showEventSocialKitGeneratorDialog() {
    // This usually needs an event selection first
    _jumpToTab('events', 'Aktif');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen paylaşmak istediğiniz etkinliği seçin.')));
  }

  void _showSocialSharePreview(String type, List<Map<String, dynamic>> items) {
    // SocialShareCard needs to be updated to handle multi-item summaries
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu özellik henüz hazır değil.')));
  }

  void _showSchedulePostDialog({Map<String, dynamic>? photoData, String? photoId}) {
     final captionC = TextEditingController(text: photoData != null ? 'Haftanın fotoğrafı! 📸\n\n${photoData['title']}' : '');
     DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));
     
     showDialog(
       context: context,
       builder: (context) => StatefulBuilder(
         builder: (context, setS) => AlertDialog(
           title: const Text('Instagram Gönderisi Planla'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               if (photoData != null) Container(height: 100, width: double.infinity, decoration: BoxDecoration(image: DecorationImage(image: NetworkImage(photoData['imageUrl']), fit: BoxFit.cover))),
               TextField(controller: captionC, maxLines: 3, decoration: const InputDecoration(labelText: 'Açıklama')),
               const SizedBox(height: 10),
               ListTile(
                 title: Text(DateFormat('dd.MM HH:mm').format(selectedDate)),
                 trailing: const Icon(Icons.calendar_today),
                 onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                    if (d != null) {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDate));
                      if (t != null) {
                        setS(() => selectedDate = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                      }
                    }
                 },
               ),
             ],
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
             ElevatedButton(
               onPressed: () async {
                 await _socialService.schedulePost(
                   type: photoData != null ? 'photo' : 'event',
                   targetId: photoId ?? 'manual',
                   scheduleDate: selectedDate,
                   platform: 'instagram',
                   caption: captionC.text,
                 );
                 Navigator.pop(context);
               },
               child: const Text('Planla'),
             ),
           ],
         ),
       ),
     );
  }
  void _clearAllNotifications() {
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Tüm Kayıtları Sil'),
         content: const Text('Tüm bildirim geçmişi silinecektir. Emin misiniz?'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
           ElevatedButton(
             onPressed: () async {
               final batch = _db.batch();
               final docs = await _db.collection('push_notifications').get();
               for (var d in docs.docs) { batch.delete(d.reference); }
               await batch.commit();
               Navigator.pop(context);
             },
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             child: const Text('SİL'),
           ),
         ],
       ),
     );
  }

  void _confirmDelete(String col, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Öğeyi Sil'),
        content: const Text('Bu işlem geri alınamaz. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await _db.collection(col).doc(id).delete();
              Navigator.pop(context);
              _refreshStats();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SİL'),
          ),
        ],
      ),
    );
  }

  void _editSetting(String k, String v) {
    final c = TextEditingController(text: v);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ayar Düzenle: $k'),
        content: TextField(controller: c, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(onPressed: () async {
            await _db.collection('app_settings').doc('config').set({k: c.text}, SetOptions(merge: true));
            Navigator.pop(context);
          }, child: const Text('Kaydet')),
        ],
      ),
    );
  }

  void _editGlobalCommunityRules(String dummy) async {
     final doc = await _db.collection('app_settings').doc('legal').get();
     final currentRules = doc.exists ? (doc.data() as Map<String, dynamic>)['community_rules'] ?? '' : '';
     
     if (!mounted) return;
     final c = TextEditingController(text: currentRules);
     
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: const Text('Topluluk Kurallarını Düzenle'),
         content: TextField(
           controller: c, 
           maxLines: 12, 
           decoration: const InputDecoration(
             border: OutlineInputBorder(),
             hintText: 'Kuralları buraya yazın...'
           )
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
           ElevatedButton(onPressed: () async {
             await _db.collection('app_settings').doc('legal').set({'community_rules': c.text}, SetOptions(merge: true));
             Navigator.pop(context);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kurallar güncellendi.')));
           }, child: const Text('Kaydet')),
         ],
       ),
     );
  }

  void _showBulkNotificationDialog() {
    final titleC = TextEditingController();
    final bodyC = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu Bildirim Gönder'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleC, decoration: const InputDecoration(labelText: 'Başlık')),
            const SizedBox(height: 8),
            TextField(controller: bodyC, decoration: const InputDecoration(labelText: 'Mesaj İçeriği')),
            const SizedBox(height: 12),
            const Text(
              'Not: Bu bildirim tüm kayıtlı kullanıcılara (all_users topic) gönderilecektir.',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (titleC.text.isEmpty || bodyC.text.isEmpty) return;
              await _db.collection('push_notifications').add({
                'to': '/topics/all_users',
                'notification': {'title': titleC.text, 'body': bodyC.text},
                'status': 'pending',
                'createdAt': FieldValue.serverTimestamp(),
                'fcmVersion': 'v1',
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toplu bildirim sıraya alındı.')));
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  void _pokeInactiveUsers() async {
     showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
     try {
       // Inactive defined as last login > 3 days ago
       final now = DateTime.now();
       final threeDaysAgo = now.subtract(const Duration(days: 3));
       
       final users = await _db.collection('users')
           .where('lastLogin', isLessThan: Timestamp.fromDate(threeDaysAgo))
           .limit(100) // Batch of 100
           .get();

       if (users.docs.isEmpty) {
         if (mounted) Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dürtülecek inaktif kullanıcı bulunamadı.')));
         return;
       }

       int count = 0;
       for (var doc in users.docs) {
         final data = doc.data();
         final token = data['fcmToken'];
         if (token != null) {
           await _db.collection('push_notifications').add({
             'to': token,
             'notification': {
               'title': 'Seni Özledik! 👋',
               'body': 'Uygulamadaki yeni etkinliklere göz atmak ister misin?',
             },
             'status': 'pending',
             'createdAt': FieldValue.serverTimestamp(),
             'fcmVersion': 'v1',
           });
           count++;
         }
       }

       if (mounted) {
         Navigator.pop(context);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count kullanıcıya hatırlatma gönderildi.')));
       }
     } catch (e) {
       if (mounted) {
         Navigator.pop(context);
         _showErrorSnackBar(e);
       }
     }
  }

  void _showBulkScraperDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Etkinlik Aktarıcı Seçenekleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ListTile(
            leading: const Icon(Icons.public, color: Colors.blueAccent),
            title: const Text('Tüm Şehirlerden 1 Etkinlik Çek'),
            subtitle: const Text('81 ilin her birinden rastgele 1 etkinlik yükler.'),
            onTap: () async {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('81 il için tarama başlatıldı...')));
              await EventScraperService.scrapeOneFromEveryCity();
              _refreshStats();
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_city, color: Colors.orangeAccent),
            title: const Text('Seçili Şehirlerden 5 Etkinlik Çek'),
            subtitle: const Text('İstediğiniz illerden beşer adet etkinlik yükler.'),
            onTap: () {
              Navigator.pop(context);
              _showMultiCityScraperDialog();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showMultiCityScraperDialog() {
    List<String> selectedCities = [];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setS) => AlertDialog(
          title: const Text('Şehir Seçimi'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cities.length,
              itemBuilder: (context, index) {
                final city = cities[index];
                final isSelected = selectedCities.contains(city);
                return CheckboxListTile(
                  title: Text(city),
                  value: isSelected,
                  onChanged: (v) {
                    setS(() {
                      if (v == true) selectedCities.add(city);
                      else selectedCities.remove(city);
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
            ElevatedButton(
              onPressed: selectedCities.isEmpty ? null : () async {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${selectedCities.length} şehir için tarama başlatıldı...')));
                await EventScraperService.scrapeFiveFromSelectedCities(selectedCities);
                _refreshStats();
              },
              child: const Text('Başlat'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkEventDialog() { /* Opsiyonel: Daha sonra eklenebilir */ }

  void _runSystemSpeedup() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      // 1. Delete sent notifications older than 7 days
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final oldNotifications = await _db.collection('push_notifications')
          .where('status', isEqualTo: 'sent')
          .where('sentAt', isLessThan: Timestamp.fromDate(weekAgo))
          .get();
      
      final batch = _db.batch();
      for (var d in oldNotifications.docs) {
        batch.delete(d.reference);
      }
      
      // 2. Clear old admin logs (optional)
      // ...
      
      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sistem temizliği (Eski bildirimler) tamamlandı.')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar(e);
      }
    }
  }

  void _autoArchivePastEvents() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final now = Timestamp.now();
      final expiredEvents = await _db.collection("events")
          .where("eventDate", isLessThan: now)
          .where("isArchived", isEqualTo: false)
          .get();

      if (expiredEvents.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Arşivlenecek etkinlik bulunamadı.")));
        return;
      }

      final batch = _db.batch();
      for (var doc in expiredEvents.docs) {
        batch.update(doc.reference, { 'isArchived': true });
      }

      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${expiredEvents.size} etkinlik arşivlendi.")));
        _refreshStats();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar(e);
      }
    }
  }

  void _runDateMigration() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      // Migrate String dates to Timestamps in events if any
      final events = await _db.collection('events').get();
      final batch = _db.batch();
      int count = 0;

      for (var doc in events.docs) {
        final data = doc.data();
        if (data['eventDate'] is String) {
          DateTime? dt = DateTime.tryParse(data['eventDate']);
          if (dt != null) {
            batch.update(doc.reference, {'eventDate': Timestamp.fromDate(dt)});
            count++;
          }
        }
      }

      await batch.commit();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count etkinlik tarihi güncellendi.')));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar(e);
      }
    }
  }

  void _editLegalText(String key) {
    _db.collection('app_settings').doc('legal').get().then((doc) {
       final current = doc.exists ? (doc.data() as Map<String, dynamic>)[key] ?? '' : '';
       final c = TextEditingController(text: current);
       showDialog(
         context: context,
         builder: (context) => AlertDialog(
           title: Text('Düzenle: $key'),
           content: TextField(controller: c, maxLines: 15, decoration: const InputDecoration(border: OutlineInputBorder())),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
             ElevatedButton(onPressed: () async {
               await _db.collection('app_settings').doc('legal').set({key: c.text}, SetOptions(merge: true));
               Navigator.pop(context);
             }, child: const Text('Kaydet')),
           ],
         ),
       );
    });
  }

  String? _extractIndexUrl(String error) {
    final regExp = RegExp(r'(https://console\.firebase\.google\.com/[^\s]+)');
    return regExp.firstMatch(error)?.group(0);
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bağlantı açılamadı: $urlString')),
        );
      }
    }
  }

  void _showErrorSnackBar(Object error) {
    if (!mounted) return;
    final String errorStr = error.toString();
    final String? indexUrl = _extractIndexUrl(errorStr);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Hata: $errorStr', style: const TextStyle(fontSize: 12)),
        backgroundColor: Colors.red.shade900,
        duration: const Duration(seconds: 10),
        action: indexUrl != null ? SnackBarAction(
          label: 'İNDEKS OLUŞTUR',
          textColor: Colors.white,
          onPressed: () => _launchUrl(indexUrl),
        ) : null,
      ),
    );
  }

  Widget _errorWidget(Object? error) {
    final errorStr = error.toString();
    final url = _extractIndexUrl(errorStr);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Veri çekilemedi (İndeks hatası olabilir)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            if (url != null)
              ElevatedButton.icon(
                onPressed: () => _launchUrl(url),
                icon: const Icon(Icons.open_in_new),
                label: const Text('İNDEKSİ OLUŞTUR'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              )
            else
              Text(errorStr, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('reference_requests').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _errorWidget(snapshot.error);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('Henüz referans talebi yok.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String status = data['status'] ?? 'open';
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CustomAvatar(imageUrl: data['userImage'], radius: 20),
                title: Text(data['userName'] ?? 'Adsız'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Etkinlik: ${data['eventTitle'] ?? ''}'),
                    Text('Neden: ${data['reason'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Durum: ${status == 'open' ? 'Açık' : 'Tamamlandı'}', style: TextStyle(color: status == 'open' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: status == 'open' 
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _db.collection('reference_requests').doc(doc.id).delete(),
                    )
                  : const Icon(Icons.check_circle, color: Colors.blue),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: data['eventId']))),
              ),
            );
          },
        );
      },
    );
  }
}
