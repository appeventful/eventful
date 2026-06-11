import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/custom_avatar.dart';
import '../services/score_service.dart';
import '../models/user_model.dart';

class AttendanceScreen extends StatefulWidget {
  final String eventId;
  const AttendanceScreen({super.key, required this.eventId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _checkDuty();
    super.dispose();
  }

  void _checkDuty() async {
    final ScoreService scoreService = ScoreService.instance;
    try {
      await scoreService.checkOrganizerAttendanceDuty(widget.eventId);
    } catch (e) {
      debugPrint("Error checking duty: $e");
    }
  }

  void _showQRCode(String secret) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yoklama QR Kodu', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Katılımcıların telefonlarından bu kodu okutarak yoklama vermelerini sağlayabilirsiniz.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                data: secret,
                version: QrVersions.auto,
                size: 240.0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katılım Kontrolü'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _db.collection('events').doc(widget.eventId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.exists) {
                final String secret = snapshot.data!.id; // Using eventId as secret for now
                return IconButton(
                  icon: const Icon(Icons.qr_code_rounded, color: Colors.orange),
                  onPressed: () => _showQRCode(secret),
                  tooltip: 'QR Kod Göster',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          TextButton(
            onPressed: _confirmFinishAttendance,
            child: const Text('Tamamla', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.data() == null) return const Center(child: CircularProgressIndicator());
          
          var eventData = snapshot.data!.data() as Map<String, dynamic>;
          String creatorId = eventData['creatorId'] ?? '';
          List allParticipants = eventData['participants'] ?? [];
          
          // Filter out the creator from the list
          List participants = allParticipants.where((uid) => uid != creatorId).toList();

          List attendedList = eventData['attendanceYes'] ?? [];
          List absentList = eventData['attendanceNo'] ?? [];
          List referrals = eventData['referrals'] ?? [];

          if (participants.isEmpty) {
            return const Center(child: Text('Henüz katılımcı yok.'));
          }

          return ListView.builder(
            itemCount: participants.length,
            itemBuilder: (context, index) {
              String userId = participants[index];
              bool hasAttended = attendedList.contains(userId);
              bool hasAbsent = absentList.contains(userId);
              
              // Check if user joined via referral
              var referral = referrals.cast<Map<String, dynamic>>().firstWhere(
                (r) => r['user'] == userId,
                orElse: () => {},
              );
              bool hasReferrer = referral.isNotEmpty;

              return FutureBuilder<DocumentSnapshot>(
                future: _db.collection('users').doc(userId).get(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData || userSnap.data?.data() == null) return const ListTile(title: Text('Yükleniyor...'));
                  final user = UserModel.fromFirestore(userSnap.data!);

                  return ListTile(
                    leading: CustomAvatar(
                      imageUrl: user.profileImage,
                      isPassive: user.isPassive,
                    ),
                    title: Row(
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            color: user.isPassive ? Colors.grey : Colors.black,
                            decoration: user.isPassive ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (hasReferrer) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: const Text(
                              'Referanslı',
                              style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: hasAttended 
                        ? const Text('Katıldı ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                        : hasAbsent 
                            ? const Text('Gelmedi ❌', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                            : const Text('Bekleniyor...'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ATTENDED BUTTON
                        IconButton(
                          icon: Icon(hasAttended ? Icons.check_circle : Icons.check_circle_outline),
                          color: hasAttended ? Colors.green : Colors.grey,
                          onPressed: () => _markAttendance(userId, user.name, 'attendanceYes'),
                        ),
                        // ABSENT BUTTON
                        IconButton(
                          icon: Icon(hasAbsent ? Icons.cancel : Icons.cancel_outlined),
                          color: hasAbsent ? Colors.red : Colors.grey,
                          onPressed: () => _markAttendance(userId, user.name, 'attendanceNo'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _markAttendance(String userId, String userName, String status) async {
    final docRef = _db.collection('events').doc(widget.eventId);
    
    try {
      // 1. Update lists in Firestore
      if (status == 'attendanceYes') {
        await docRef.update({
          'attendanceYes': FieldValue.arrayUnion([userId]),
          'attendanceNo': FieldValue.arrayRemove([userId]),
        });
      } else {
        await docRef.update({
          'attendanceNo': FieldValue.arrayUnion([userId]),
          'attendanceYes': FieldValue.arrayRemove([userId]),
        });
      }

      // 2. Process points immediately for better UX
      await ScoreService.instance.processAttendanceScores(widget.eventId, userId, status);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$userName ${status == 'attendanceYes' ? 'katıldı' : 'gelmedi'} olarak işaretlendi.'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _confirmFinishAttendance() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yoklamayı Tamamla'),
        content: const Text('Tüm katılımcıları işaretlediyseniz yoklamayı sonlandırabilirsiniz. Bu işlemden sonra değişiklik yapılamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await ScoreService.instance.checkOrganizerAttendanceDuty(widget.eventId);
              if (mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Exit screen
              }
            },
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );
  }
}
