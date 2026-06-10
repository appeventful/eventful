import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class StatisticsTab extends StatelessWidget {
  final List<int>? cachedCounts;
  final bool isLoadingStats;
  final String? lastIndexError;
  final VoidCallback onRefresh;
  final Function(String tabKey, String filter) onJumpToTab;
  final Function(String url) launchUrl;
  final String? Function(String error) extractIndexUrl;

  const StatisticsTab({
    super.key,
    required this.cachedCounts,
    required this.isLoadingStats,
    this.lastIndexError,
    required this.onRefresh,
    required this.onJumpToTab,
    required this.launchUrl,
    required this.extractIndexUrl,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (cachedCounts == null && isLoadingStats) 
            const Center(child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ))
          else if (cachedCounts == null)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  if (lastIndexError != null && extractIndexUrl(lastIndexError!) != null) ...[
                    const Text('Bazı istatistikler için indeks gerekiyor.', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => launchUrl(extractIndexUrl(lastIndexError!)!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Gerekli İndeksi Oluştur'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('İstatistikler yüklenemedi.'),
                  TextButton(onPressed: onRefresh, child: const Text('Tekrar Dene')),
                ],
              ),
            )
          else ...[
            const Text('Genel Durum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _statCard('Toplam Kullanıcı', cachedCounts![0], Icons.people, Colors.blue, () => onJumpToTab('users', 'Hepsi')),
                _statCard('Çevrimiçi Üyeler', cachedCounts![8], Icons.online_prediction, Colors.green, () => onJumpToTab('users', 'Çevrimiçi')),
                _statCard('Anlık Misafirler', cachedCounts![13], Icons.person_outline, Colors.orangeAccent, () {}),
                _statCard('Toplam Etkinlik', cachedCounts![1], Icons.event_note, Colors.blueGrey, () => onJumpToTab('events', 'Aktif')),
                _statCard('Aktif Etkinlikler', cachedCounts![11], Icons.event_available, Colors.green, () => onJumpToTab('events', 'Aktif')),
                _statCard('Bekleyen Raporlar', cachedCounts![2], Icons.report, Colors.redAccent, () => onJumpToTab('reports', 'pending')),
                _statCard('Geri Bildirimler', cachedCounts![3], Icons.feedback, Colors.teal, () => onJumpToTab('feedback', 'Hepsi')),
                _statCard('Referans Talepleri', cachedCounts![9], Icons.handshake, Colors.indigoAccent, () => onJumpToTab('references', 'open')),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Hesap Durumları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2,
              children: [
                _statCard('Banlı', cachedCounts![4], Icons.block, Colors.red, () => onJumpToTab('users', 'Banlı')),
                _statCard('Kısıtlı', cachedCounts![5], Icons.gavel, Colors.orange, () => onJumpToTab('users', 'Kısıtlı')),
                _statCard('Dondurulmuş', cachedCounts![6], Icons.ac_unit, Colors.cyan, () => onJumpToTab('users', 'Dondurulmuş')),
                _statCard('Silinmiş', cachedCounts![7], Icons.delete_forever, Colors.blueGrey, () => onJumpToTab('users', 'Silinmiş')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statCard(String label, int count, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Card(
        color: color.withValues(alpha: 0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color),
            Text(
              count == -1 ? 'Hata' : '$count', 
              style: TextStyle(
                fontSize: count == -1 ? 16 : 20, 
                fontWeight: FontWeight.bold, 
                color: count == -1 ? Colors.red : color
              )
            ),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
