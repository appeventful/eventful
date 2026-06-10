import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';

class AdminLogsTab extends StatelessWidget {
  const AdminLogsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore db = FirebaseFirestore.instance;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: kSurfaceDark,
          child: const Row(
            children: [
              Icon(Icons.history, color: kPrimaryOrange),
              SizedBox(width: 12),
              Text(
                'Yönetici İşlem Kayıtları',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('admin_logs').orderBy('timestamp', descending: true).limit(100).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final logs = snapshot.data!.docs;

              if (logs.isEmpty) {
                return const Center(child: Text('Henüz log kaydı yok.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index].data() as Map<String, dynamic>;
                  final timestamp = log['timestamp'] as Timestamp?;
                  final timeStr = timestamp != null ? DateFormat('dd MMM, HH:mm').format(timestamp.toDate()) : '...';

                  IconData icon;
                  Color color;
                  
                  // Action tiplerine göre ikon ve renk belirleme
                  String action = log['action'] ?? log['actionType'] ?? 'info';
                  
                  switch (action) {
                    case 'ban':
                    case 'device_ban': icon = Icons.block; color = Colors.red; break;
                    case 'unban': icon = Icons.check_circle; color = Colors.green; break;
                    case 'role_change': icon = Icons.security; color = Colors.blue; break;
                    case 'restrict': icon = Icons.gavel; color = Colors.orange; break;
                    case 'unrestrict': icon = Icons.done_all; color = Colors.teal; break;
                    case 'password_change': icon = Icons.lock_reset; color = Colors.amber; break;
                    case 'wipe_data': icon = Icons.delete_forever; color = Colors.purple; break;
                    default: icon = Icons.info_outline; color = Colors.grey;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.1),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          children: [
                            TextSpan(text: log['adminName'] ?? log['adminEmail'] ?? 'Yetkili', style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryOrange)),
                            const TextSpan(text: ' adlı yetkili '),
                            TextSpan(text: log['targetName'] ?? 'bir kullanıcı', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' için işlem yaptı.'),
                          ],
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(log['details'] ?? log['reason'] ?? action.toUpperCase(), style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
