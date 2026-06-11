import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';

class SettingsTab extends StatelessWidget {
  final String currentAppVersion;
  final String? lastIndexError;
  final Function(String url) launchUrl;
  final Function(String key, String value) onEditSetting;
  final Function(String currentRules) onEditGlobalRules;
  final VoidCallback onShowBulkNotification;
  final VoidCallback onPokeInactiveUsers;
  final VoidCallback onShowBulkScraper;
  final VoidCallback onShowBulkEvent;
  final VoidCallback onRunSpeedup;
  final VoidCallback onAutoArchive;
  final VoidCallback onRunMigration;
  final Function(String key) onEditLegalText;

  const SettingsTab({
    super.key,
    required this.currentAppVersion,
    this.lastIndexError,
    required this.launchUrl,
    required this.onEditSetting,
    required this.onEditGlobalRules,
    required this.onShowBulkNotification,
    required this.onPokeInactiveUsers,
    required this.onShowBulkScraper,
    required this.onShowBulkEvent,
    required this.onRunSpeedup,
    required this.onAutoArchive,
    required this.onRunMigration,
    required this.onEditLegalText,
  });

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('app_settings').doc('config').snapshots(),
      builder: (context, snapshot) {
        String? snapshotIndexError;
        if (snapshot.hasError) {
          String errorStr = snapshot.error.toString();
          if (errorStr.contains('https://console.firebase.google.com')) {
            snapshotIndexError = errorStr;
          } else {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Yapılandırma yüklenemedi:\n${snapshot.error}', textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
        }
        
        if (!snapshot.hasData && snapshotIndexError == null) return const Center(child: CircularProgressIndicator());
        var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (snapshotIndexError != null || lastIndexError != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Kritik İndeks Eksik!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sistem ayarlarını görmek veya diğer özellikleri kullanmak için aşağıdaki linke tıklayarak dizini oluşturmalısınız.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final errorText = snapshotIndexError ?? lastIndexError!;
                        final regExp = RegExp(r'(https://console\.firebase\.google\.com/[^\s]+)');
                        final url = regExp.firstMatch(errorText)?.group(0);
                        if (url != null) launchUrl(url);
                      },
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('İndeksi Hemen Oluştur'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                    if (snapshotIndexError != null) ...[
                      const SizedBox(height: 8),
                      Text(snapshotIndexError, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ],
            const Text('Uygulama Genel Ayarları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SwitchListTile(
              title: const Text('Bakım Modu'),
              subtitle: const Text('Sadece adminlerin girişine izin verir', style: TextStyle(fontSize: 11)),
              value: data['maintenanceMode'] == true,
              onChanged: (v) => db.collection('app_settings').doc('config').set({'maintenanceMode': v}, SetOptions(merge: true)),
              activeColor: kPrimaryOrange,
            ),
            ListTile(
              title: const Text('Duyuru Metni'),
              subtitle: Text(data['announcement'] ?? 'Duyuru yok', style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () => onEditSetting('announcement', data['announcement'] ?? ''),
            ),
            ListTile(
              title: const Text('Minimum Sürüm'),
              subtitle: Text(data['minVersion'] ?? '1.0.0'),
              trailing: const Icon(Icons.update, size: 20),
              onTap: () => onEditSetting('minVersion', data['minVersion'] ?? '1.0.0'),
            ),
            ListTile(
              title: const Text('Android Güncelleme Linki'),
              subtitle: Text(data['updateUrlAndroid'] ?? 'Link ayarlanmamış', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.link, size: 20),
              onTap: () => onEditSetting('updateUrlAndroid', data['updateUrlAndroid'] ?? ''),
            ),
            ListTile(
              title: const Text('iOS Güncelleme Linki'),
              subtitle: Text(data['updateUrlIos'] ?? 'Link ayarlanmamış', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.link, size: 20),
              onTap: () => onEditSetting('updateUrlIos', data['updateUrlIos'] ?? ''),
            ),
            const Divider(color: Colors.white10),
            const Text('Sistem Araçları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _toolTile(Icons.notifications_active, 'Toplu Bildirim Gönder', 'Tüm kullanıcılara özel bildirim', onShowBulkNotification, Colors.purpleAccent),
            _toolTile(Icons.timer, 'İnaktifleri Dürt', '3 gündür girmeyenlere hatırlatma', onPokeInactiveUsers, Colors.redAccent),
            _toolTile(Icons.location_city, 'Otomatik Etkinlik Çek', 'etkinlik.io üzerinden 81 ile yükle', onShowBulkScraper, Colors.blueAccent),
            _toolTile(Icons.speed, 'Sistem Hızlandırma', 'Logları temizle ve performansı artır', onRunSpeedup, Colors.greenAccent),
            _toolTile(Icons.auto_delete, 'Eski Etkinlikleri Arşivle', 'Tarihi geçmişleri otomatik taşı', onAutoArchive, Colors.orangeAccent),
            _toolTile(Icons.data_usage, 'Veri Migrasyonu', 'Veritabanı alanlarını standartlaştır', onRunMigration, Colors.blueGrey),
            const Divider(color: Colors.white10),
            const Text('Hukuki ve Kurumsal Metinler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            _legalTile('Topluluk Kuralları', () => onEditGlobalRules('')),
            _legalTile('Gizlilik Sözleşmesi', () => onEditLegalText('privacy_policy')),
            _legalTile('Kullanım Koşulları', () => onEditLegalText('terms_of_use')),
            _legalTile('KVKK Metni', () => onEditLegalText('kvkk')),
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  Widget _toolTile(IconData icon, String title, String sub, VoidCallback onTap, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      onTap: onTap,
    );
  }

  Widget _legalTile(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.edit, size: 18),
      onTap: onTap,
    );
  }
}
