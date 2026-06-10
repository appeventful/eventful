import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/constants.dart';
import '../../models/user_model.dart';

class InternalChatTab extends StatefulWidget {
  final String chatPath;
  final String title;
  final UserModel? me;

  const InternalChatTab({
    super.key,
    required this.chatPath,
    required this.title,
    this.me,
  });

  @override
  State<InternalChatTab> createState() => _InternalChatTabState();
}

class _InternalChatTabState extends State<InternalChatTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    _chatController.clear();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.me == null) return;

    await _db.collection('internal_chats').doc(widget.chatPath).collection('messages').add({
      'senderId': user.uid,
      'senderName': widget.me!.name,
      'senderRole': widget.me!.role == 'city_representative' ? '${widget.me!.responsibleCity} Temsilcisi' : widget.me!.role,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: kSurfaceDark.withValues(alpha: 0.5),
          child: Row(
            children: [
              Icon(widget.chatPath == 'admin_mod' ? Icons.security : Icons.people_outline, color: kPrimaryOrange, size: 20),
              const SizedBox(width: 10),
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('internal_chats').doc(widget.chatPath).collection('messages')
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: kPrimaryOrange));

              final messages = snapshot.data!.docs;

              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final data = messages[index].data() as Map<String, dynamic>;
                  final bool isMe = data['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                  final DateTime? time = (data['createdAt'] as Timestamp?)?.toDate();

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? kPrimaryOrange : Colors.white12,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(isMe ? 12 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe)
                            Text(
                              data['senderName'] ?? 'Bilinmeyen',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kPrimaryOrange),
                            ),
                          Text(
                            data['text'] ?? '',
                            style: TextStyle(color: isMe ? kDeepCharcoal : Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                data['senderRole'] != null ? '[${data['senderRole']}] ' : '',
                                style: TextStyle(fontSize: 8, color: isMe ? kDeepCharcoal.withValues(alpha: 0.6) : Colors.white60),
                              ),
                              if (time != null)
                                Text(
                                  DateFormat('HH:mm').format(time),
                                  style: TextStyle(fontSize: 8, color: isMe ? kDeepCharcoal.withValues(alpha: 0.6) : Colors.white60),
                                ),
                            ],
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
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: const BoxDecoration(
            color: kSurfaceDark,
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Mesaj yazın...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (v) => _sendMessage(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: kPrimaryOrange),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
