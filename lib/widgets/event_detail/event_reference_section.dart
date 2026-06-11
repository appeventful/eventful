import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_avatar.dart';
import '../../screens/profile_screen.dart';
import '../../utils/constants.dart';

class EventReferenceSection extends StatelessWidget {
  final String eventId;
  final bool isCreator;
  final Function(Map<String, dynamic> request, String requestId) onProvideReference;
  final VoidCallback onConfirmGenerateRefCode;

  const EventReferenceSection({
    super.key,
    required this.eventId,
    required this.isCreator,
    required this.onProvideReference,
    required this.onConfirmGenerateRefCode,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: db.collection('reference_requests')
              .where('eventId', isEqualTo: eventId)
              .where('status', isEqualTo: 'open')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.handshake_outlined, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('Referans Bekleyenler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
                const SizedBox(height: 12),
                ...snapshot.data!.docs.map((doc) {
                  var request = doc.data() as Map<String, dynamic>;
                  if (request['userId'] == currentUser?.uid) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: request['userId']))),
                              child: FutureBuilder<DocumentSnapshot>(
                                future: db.collection('users').doc(request['userId']).get(),
                                builder: (context, userSnap) {
                                  List<String> badgeIcons = [];
                                  if (userSnap.hasData && userSnap.data!.exists) {
                                    final user = UserModel.fromFirestore(userSnap.data!);
                                    badgeIcons = user.badges.map((id) {
                                      final badge = availableBadges.firstWhere(
                                        (b) => b['id'] == id,
                                        orElse: () => {'icon': ''},
                                      );
                                      return badge['icon'] as String;
                                    }).where((icon) => icon.isNotEmpty).toList();
                                  }

                                  return Row(
                                    children: [
                                      CustomAvatar(
                                        radius: 16,
                                        imageUrl: request['userImage'],
                                        badgeIcons: badgeIcons,
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            request['userName'] ?? 'Kullanıcı',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          if (request['username'] != null && request['username'] != '')
                                            Text(
                                              '@${request['username']}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            ),
                                        ],
                                      ),
                                    ],
                                  );
                                }
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () => onProvideReference(request, doc.id),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                minimumSize: const Size(0, 32),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Referans Ol', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        if (request['reason'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            request['reason'],
                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.key_outlined, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Referans Sistemi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: onConfirmGenerateRefCode,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni Kod'),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: db.collection('events').doc(eventId).collection('referenceCodes')
                    .where('createdBy', isEqualTo: currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('Henüz referans kodunuz yok.', style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic));
                  }
                  return Column(
                    children: snapshot.data!.docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      bool isUsed = data['isUsed'] ?? false;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            SelectableText(data['code'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isUsed ? TextDecoration.lineThrough : null)),
                            const SizedBox(width: 8),
                            if (isUsed)
                              const Text('(Kullanıldı)', style: TextStyle(fontSize: 10, color: Colors.green))
                            else
                              IconButton(
                                icon: const Icon(Icons.copy, size: 16, color: Colors.blue),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: data['code']));
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı!'), duration: Duration(seconds: 1)));
                                },
                              ),
                            const Spacer(),
                            if (!isUsed)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => doc.reference.delete(),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
