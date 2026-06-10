import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import '../services/notification_service.dart';
import '../widgets/custom_avatar.dart';
import 'event_detail_screen.dart';
import 'profile_screen.dart';
import '../models/user_model.dart';

class ReferenceRequestsScreen extends StatelessWidget {
  const ReferenceRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (AuthService().isGuest) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Yardımlaşma Merkezi', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handshake_outlined, size: 80, color: Colors.orange),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Yardımlaşma Merkezi\'ne Hoş Geldin!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Buradaki talepleri görmek veya yeni bir talep oluşturmak için üye olman gerekiyor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => GuestGuardDialog.show(context, "Yardımlaşma Merkezi'ni kullanma"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Üye Ol / Giriş Yap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yardımlaşma Merkezi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reference_requests')
            .where('status', isEqualTo: 'open')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Veriler yüklenirken bir hata oluştu.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hata: ${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Rebuild to retry
                        (context as Element).markNeedsBuild();
                      },
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Client side filtering for eventDate and sorting
          final now = DateTime.now();
          var docs = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            var eventDateData = data['eventDate'] ?? data['date'];
            DateTime eventDate;
            if (eventDateData is Timestamp) {
              eventDate = eventDateData.toDate();
            } else if (eventDateData is String) {
              eventDate = DateTime.tryParse(eventDateData) ?? DateTime.now();
            } else {
              return false;
            }
            return eventDate.isAfter(now);
          }).toList();

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.handshake_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('Şu anda aktif yardım talebi bulunmuyor.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          docs.sort((a, b) {
            var aTimeData = (a.data() as Map<String, dynamic>)['timestamp'];
            var bTimeData = (b.data() as Map<String, dynamic>)['timestamp'];
            
            DateTime aTime;
            if (aTimeData is Timestamp) {
              aTime = aTimeData.toDate();
            } else if (aTimeData is String) {
              aTime = DateTime.tryParse(aTimeData) ?? DateTime.now();
            } else {
              aTime = DateTime.now();
            }

            DateTime bTime;
            if (bTimeData is Timestamp) {
              bTime = bTimeData.toDate();
            } else if (bTimeData is String) {
              bTime = DateTime.tryParse(bTimeData) ?? DateTime.now();
            } else {
              bTime = DateTime.now();
            }
            
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var request = docs[index].data() as Map<String, dynamic>;
              var requestId = docs[index].id;
              return _buildRequestCard(context, request, requestId);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request, String requestId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(request['userId']).get(),
      builder: (context, userSnap) {
        UserModel? user;
        if (userSnap.hasData && userSnap.data!.exists) {
          user = UserModel.fromFirestore(userSnap.data!);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (AuthService().isGuest) {
                          GuestGuardDialog.show(context, "Profil görüntüleme");
                          return;
                        }
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: request['userId'])));
                      },
                      child: CustomAvatar(
                        radius: 20,
                        imageUrl: user?.profileImage ?? request['userImage'],
                        isPassive: user?.isPassive ?? false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? request['userName'] ?? 'Kullanıcı',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: (user?.isPassive ?? false) ? Colors.grey : Colors.black,
                              decoration: (user?.isPassive ?? false) ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text('Etkinlik: ${request['eventTitle']}', style: TextStyle(color: Colors.orange.shade700, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text('Neden referans olmalısınız?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(request['reason'] ?? '', style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: request['eventId']))),
                      child: const Text('Etkinliği Gör'),
                    ),
                    ElevatedButton(
                      onPressed: () => _handleProvideReference(context, request, requestId),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: const Text('Referans Ol'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleProvideReference(BuildContext context, Map<String, dynamic> request, String requestId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == request['userId']) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kendi talebinize referans olamazsınız.')));
      return;
    }

    // 1. Check if user is participating in this event
    final eventDoc = await FirebaseFirestore.instance.collection('events').doc(request['eventId']).get();
    final participants = List.from(eventDoc.data()?['participants'] ?? []);
    
    if (!participants.contains(currentUser.uid)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sadece katıldığınız etkinlikler için referans olabilirsiniz.')));
      return;
    }

    // 2. Check 2-code limit for this event
    final existingCodes = await FirebaseFirestore.instance
        .collection('events')
        .doc(request['eventId'])
        .collection('referenceCodes')
        .where('createdBy', isEqualTo: currentUser.uid)
        .get();

    if (existingCodes.docs.length >= 2) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Limit Doldu'),
            content: const Text('Bu etkinlik için maksimum 2 referans kodu limitine ulaştınız. Yeni kod üretmek için etkinlik detay sayfasından kullanılmamış kodlarınızı iptal etmelisiniz.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam')),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: request['eventId'])));
                },
                child: const Text('Etkinliğe Git'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Generate and send code
    String code = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    
    WriteBatch batch = FirebaseFirestore.instance.batch();
    
    // 1. Add code
    DocumentReference codeRef = FirebaseFirestore.instance
        .collection('events')
        .doc(request['eventId'])
        .collection('referenceCodes')
        .doc();
    
    batch.set(codeRef, {
      'code': code,
      'createdBy': currentUser.uid,
      'usedBy': null,
      'createdAt': FieldValue.serverTimestamp(),
      'isUsed': false,
    });

    // 2. Close request
    batch.update(FirebaseFirestore.instance.collection('reference_requests').doc(requestId), {
      'status': 'fulfilled',
      'fulfilledBy': currentUser.uid,
    });

    // 3. Send notification via NotificationService to trigger FCM V1
    await NotificationService.sendNotification(
      recipientId: request['userId'],
      title: 'Referans Kodun Geldi! 🤝',
      body: '"${request['eventTitle']}" etkinliği için aradığın referans kodu: $code',
      data: {
        'type': 'reference_code_received',
        'code': code,
        'eventId': request['eventId'],
        'senderId': currentUser.uid,
      },
    );

    await batch.commit();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Teşekkürler!'),
          content: Text('Referans kodunuz ($code) kullanıcıya gönderildi. Artık bu etkinliğe katılabilir.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tamam'))],
        ),
      );
    }
  }
}
