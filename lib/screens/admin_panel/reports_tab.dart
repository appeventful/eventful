import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class ReportsTab extends StatefulWidget {
  final UserModel? me;
  final Function(String reportId, Map<String, dynamic> data) onShowReportDetail;
  final Function(String url) launchUrl;
  final String? Function(String error) extractIndexUrl;

  const ReportsTab({
    super.key,
    required this.me,
    required this.onShowReportDetail,
    required this.launchUrl,
    required this.extractIndexUrl,
  });

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _reportStatusFilter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              const Text('Şikayet Raporları', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              DropdownButton<String>(
                value: _reportStatusFilter,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Bekleyenler')),
                  DropdownMenuItem(value: 'resolved', child: Text('Çözülenler')),
                  DropdownMenuItem(value: 'dismissed', child: Text('Reddedilenler')),
                ],
                onChanged: (v) => setState(() => _reportStatusFilter = v!),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('reports')
                .where('status', isEqualTo: _reportStatusFilter)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final errorStr = snapshot.error.toString();
                final indexUrl = widget.extractIndexUrl(errorStr);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning, color: Colors.orange, size: 48),
                      const Text('İndeks Gerekiyor', style: TextStyle(fontWeight: FontWeight.bold)),
                      if (indexUrl != null) 
                        ElevatedButton(onPressed: () => widget.launchUrl(indexUrl), child: const Text('İndeks Oluştur')),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var reports = snapshot.data!.docs.where((doc) {
                if (widget.me?.isCityRepresentative == true && widget.me?.responsibleCity != null) {
                   var data = doc.data() as Map<String, dynamic>;
                   return (data['city'] ?? '').toString().trim().toLowerCase() == widget.me!.responsibleCity!.trim().toLowerCase();
                }
                return true;
              }).toList();

              if (reports.isEmpty) return const Center(child: Text('Rapor bulunamadı.'));

              return ListView.builder(
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  var data = reports[index].data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        (data['category'] == 'event') ? Icons.event : Icons.person,
                        color: Colors.redAccent,
                      ),
                      title: Text(data['reason'] ?? 'Neden yok', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text('ID: ${reports[index].id}', style: const TextStyle(fontSize: 10)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => widget.onShowReportDetail(reports[index].id, data),
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
