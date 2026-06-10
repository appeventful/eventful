import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../chat_screen.dart';

class SupportRequestsTab extends StatelessWidget {
  const SupportRequestsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('support_requests')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('Bekleyen destek talebi yok.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String status = data['status'] ?? 'pending';
            final Timestamp ts = data['timestamp'] ?? Timestamp.now();
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                title: Row(
                  children: [
                    Expanded(child: Text(data['userName'] ?? 'Anonim', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Text(DateFormat('dd.MM HH:mm').format(ts.toDate()), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(data['message'] ?? '', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == 'pending' ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status == 'pending' ? 'Bekliyor' : 'Cevaplandı',
                            style: TextStyle(color: status == 'pending' ? Colors.orange : Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                onTap: () => _showReplyDialog(context, doc.id, data),
                trailing: const Icon(Icons.reply, color: Colors.blue),
              ),
            );
          },
        );
      },
    );
  }

  void _showReplyDialog(BuildContext context, String requestId, Map<String, dynamic> requestData) {
    final TextEditingController replyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Talebi Cevapla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Soru: ${requestData['message']}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: replyController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Mesajınızı buraya yazın...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Not: Cevabınız kullanıcıya direkt mesaj olarak iletilecek ve bir sohbet başlatılacaktır.', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              final reply = replyController.text.trim();
              if (reply.isEmpty) return;
              
              Navigator.pop(context);
              _handleReply(context, requestId, requestData, reply);
            },
            child: const Text('Cevapla & Sohbet Başlat'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleReply(BuildContext context, String requestId, Map<String, dynamic> requestData, String reply) async {
    final userId = requestData['userId'];
    final userName = requestData['userName'];
    
    try {
      // 1. Mark request as replied
      await FirebaseFirestore.instance.collection('support_requests').doc(requestId).update({'status': 'replied'});
      
      // 2. Start chat using ChatService
      final chatService = ChatService();
      await chatService.getOrCreateChat(userId);
      
      // 3. Send the response as the first message in the chat
      await chatService.sendMessage(userId, "Destek Talebiniz Hakkında: $reply");
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cevap gönderildi ve sohbet başlatıldı.')));
        
        // 4. Optionally navigate to the chat
        Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(receiverId: userId, receiverName: userName)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }
}
