import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_avatar.dart';

class FeedbackTab extends StatefulWidget {
  final UserModel? me;
  final Function(String collection, String id) onDelete;

  const FeedbackTab({super.key, required this.me, required this.onDelete});

  @override
  State<FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<FeedbackTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _filter = 'Hepsi';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: DropdownButtonFormField<String>(
            value: _filter,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Filtrele'),
            items: const [
              DropdownMenuItem(value: 'Hepsi', child: Text('🌍 Tüm Geri Bildirimler')),
              DropdownMenuItem(value: 'bug', child: Text('🐞 Hata Bildirimleri')),
              DropdownMenuItem(value: 'suggestion', child: Text('💡 Öneriler')),
              DropdownMenuItem(value: 'other', child: Text('📁 Diğer')),
            ],
            onChanged: (v) => setState(() => _filter = v!),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('feedback').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var docs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                if (widget.me?.isCityRepresentative == true && widget.me?.responsibleCity != null) {
                   if ((data['city'] ?? '').toString().toLowerCase() != widget.me!.responsibleCity!.toLowerCase()) return false;
                }
                if (_filter == 'Hepsi') return true;
                return data['type'] == _filter;
              }).toList();

              if (docs.isEmpty) return const Center(child: Text('Geri bildirim bulunamadı.'));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(data['userName'] ?? 'Anonim', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => widget.onDelete('feedback', docs[index].id)),
                            ],
                          ),
                          Text(data['message'] ?? '', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 8),
                          Text(
                            data['timestamp'] != null ? DateFormat('dd.MM HH:mm').format((data['timestamp'] as Timestamp).toDate()) : '',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
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
