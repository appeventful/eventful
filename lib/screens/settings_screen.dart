import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'feedback_screen.dart';
import '../services/data_portability_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = "1.0.0";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = "${packageInfo.version}+${packageInfo.buildNumber}";
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Hesap Ayarları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Çıkış', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await authService.logout();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Bildirim Ayarları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('Ayarlar yüklenirken bir hata oluştu.')),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              final settings = Map<String, bool>.from(data['notificationSettings'] ?? {
                'new_message': true,
                'friend_request': true,
                'event_approval': true,
                'event_reminder': true,
                'mentions': true,
              });

              return Column(
                children: [
                  if (data['role'] == 'admin' || data['role'] == 'moderator' || data['role'] == 'city_representative') ...[
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Yönetim',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings, color: Colors.red),
                      title: Text(data['role'] == 'city_representative' ? 'İl Temsilcisi Paneli' : 'Yönetim Paneli'),
                      subtitle: const Text('Uygulama yönetimi ve moderasyon araçları'),
                      onTap: () => Navigator.pushNamed(context, '/admin_panel'),
                    ),
                    const Divider(),
                  ],
                  _buildNotificationSwitch(
                    'Yeni Mesajlar',
                    'Birisi size mesaj gönderdiğinde bildirim al',
                    settings['new_message'] ?? true,
                    (val) => _updateNotificationSetting('new_message', val),
                  ),
                  _buildNotificationSwitch(
                    'Arkadaşlık İstekleri',
                    'Yeni bir arkadaşlık isteği aldığınızda bildirim al',
                    settings['friend_request'] ?? true,
                    (val) => _updateNotificationSetting('friend_request', val),
                  ),
                  _buildNotificationSwitch(
                    'Etkinlik Onayları',
                    'Etkinliğiniz onaylandığında veya reddedildiğinde bildirim al',
                    settings['event_approval'] ?? true,
                    (val) => _updateNotificationSetting('event_approval', val),
                  ),
                  _buildNotificationSwitch(
                    'Etkinlik Hatırlatıcıları',
                    'Katıldığınız etkinliklere az zaman kaldığında bildirim al',
                    settings['event_reminder'] ?? true,
                    (val) => _updateNotificationSetting('event_reminder', val),
                  ),
                  _buildNotificationSwitch(
                    'Etiketlemeler (@)',
                    'Bir sohbette sizden bahsedildiğinde bildirim al',
                    settings['mentions'] ?? true,
                    (val) => _updateNotificationSetting('mentions', val),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Görünüm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('Sistem Teması'),
                    subtitle: const Text('Cihaz ayarlarına göre değişir'),
                    value: ThemeMode.system,
                    groupValue: themeProvider.themeMode,
                    activeColor: Colors.orange,
                    onChanged: (val) {
                      if (val != null) themeProvider.toggleTheme(val);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Açık Mod'),
                    value: ThemeMode.light,
                    groupValue: themeProvider.themeMode,
                    activeColor: Colors.orange,
                    onChanged: (val) {
                      if (val != null) themeProvider.toggleTheme(val);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: const Text('Karanlık Mod'),
                    value: ThemeMode.dark,
                    groupValue: themeProvider.themeMode,
                    activeColor: Colors.orange,
                    onChanged: (val) {
                      if (val != null) themeProvider.toggleTheme(val);
                    },
                  ),
                ],
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Uygulama Hakkında',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Geri Bildirim Gönder'),
            subtitle: const Text('Öneri, hata veya şikayetlerinizi bize iletin'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FeedbackScreen()),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Gizlilik ve Veri',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.blue),
            title: const Text('Verilerimi İndir'),
            subtitle: const Text('Tüm verilerinizi JSON formatında dışa aktarın (KVKK)'),
            onTap: () async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator()),
              );
              await DataPortabilityService().downloadUserData();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versiyon'),
            trailing: Text(_version),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthService authService) {
    // ... (mevcut kodlar)
  }

  Widget _buildNotificationSwitch(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.orange,
    );
  }

  Future<void> _updateNotificationSetting(String key, bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'notificationSettings.$key': value,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayarlar güncellenemedi: $e')),
        );
      }
    }
  }
}
