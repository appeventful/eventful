import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../guest_guard_dialog.dart';

class EventJoinSection extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final TextEditingController refCodeController;
  final Function(Map<String, dynamic> event) onRequestReferenceHelp;

  const EventJoinSection({
    super.key,
    required this.eventId,
    required this.event,
    required this.refCodeController,
    required this.onRequestReferenceHelp,
  });

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;

    bool isClosed = event['isClosed'] ?? false;
    int participantsCount = (event['participants'] as List).length;
    int quota = (event['quota'] ?? 0) as int;
    bool isFull = quota > 0 && participantsCount >= quota;
    bool needsApproval = event['isApprovalRequired'] ?? false;

    return FutureBuilder<DocumentSnapshot>(
      future: db.collection('users').doc(currentUser?.uid).get(),
      builder: (context, userSnap) {
        bool isUserRestricted = userSnap.hasData && (userSnap.data!.data() as Map<String, dynamic>?)?['isRestricted'] == true;
        bool hasRefSystem = event['hasReferenceSystem'] == true;
        bool showRefField = hasRefSystem || isUserRestricted;

        if (isClosed) return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Bu etkinlik katılıma kapalıdır.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))));
        if (isFull) return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text('Etkinlik kontenjanı dolu.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))));

        return Column(
          children: [
            if (showRefField) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: refCodeController,
                        decoration: InputDecoration(
                          labelText: isUserRestricted ? 'Referans Kodu (Kısıtlı Hesap)' : 'Referans Kodu (Zorunlu)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          prefixIcon: const Icon(Icons.key_outlined),
                          filled: true,
                          fillColor: Colors.grey[50],
                          helperText: isUserRestricted ? 'Hesabınız kısıtlı olduğu için referans kodu girmelisiniz.' : null,
                        ),
                      ),
                    ),
                    if (isUserRestricted)
                      IconButton(
                        onPressed: () => onRequestReferenceHelp(event),
                        icon: const Icon(Icons.help_outline, color: Colors.orange),
                        tooltip: 'Kod İste',
                      ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () => _joinEvent(context, needsApproval, hasRefSystem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    child: Text(needsApproval ? 'Katılım İsteği Gönder' : 'Etkinliğe Katıl', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                if (!showRefField) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => _showQuickJoinInfo(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Icon(Icons.bolt, color: Colors.orange),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      }
    );
  }

  void _showQuickJoinInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text('Hızlı Katılım Nedir?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Bu etkinlik referans gerektirmiyor. Tek tıkla yerini ayırtabilir ve topluluğa katılabilirsin!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _joinEvent(context, event['isApprovalRequired'] ?? false, false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Şimdi Katıl', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _joinEvent(BuildContext context, bool needsApproval, bool hasRefSystem) async {
    final db = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (AuthService().isGuest) {
      GuestGuardDialog.show(context, "Etkinliğe katılma");
      return;
    }
    bool isAdmin = currentUser?.email == 'fatihkull17@gmail.com';
    
    bool isUserRestricted = false;
    if (!isAdmin) {
      var userDoc = await db.collection('users').doc(currentUser?.uid).get();
      isUserRestricted = userDoc.data()?['isRestricted'] ?? false;
    }

    bool effectivelyNeedsRef = hasRefSystem || isUserRestricted;

    if (effectivelyNeedsRef && refCodeController.text.isEmpty) {
      String message = isUserRestricted 
          ? 'Hesabınız kısıtlı olduğu için herhangi bir etkinliğe katılmak için referans kodu girmelisiniz.' 
          : 'Lütfen referans kodunu giriniz.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    try {
      if (effectivelyNeedsRef) {
        var codeDocs = await db.collection('events').doc(eventId).collection('referenceCodes')
            .where('code', isEqualTo: refCodeController.text)
            .where('isUsed', isEqualTo: false)
            .get();

        if (codeDocs.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçersiz veya kullanılmış referans kodu.')));
          return;
        }

        var codeData = codeDocs.docs.first.data();
        String referrerId = codeData['createdBy'];

        await codeDocs.docs.first.reference.update({
          'isUsed': true,
          'usedBy': currentUser?.uid,
          'usedAt': FieldValue.serverTimestamp(),
        });

        await db.collection('events').doc(eventId).update({
          'referrals': FieldValue.arrayUnion([{
            'user': currentUser?.uid,
            'referrer': referrerId,
            'timestamp': Timestamp.now(),
          }])
        });
      }

      if (needsApproval) {
        await db.collection('events').doc(eventId).update({
          'pendingParticipants': FieldValue.arrayUnion([currentUser?.uid])
        });
      } else {
        final Map<String, dynamic> updates = {
          'participants': FieldValue.arrayUnion([currentUser?.uid])
        };

        // Logic for external events: Make the first human joiner the organizer
        bool isExternal = event['externalSource'] == true;
        String currentCreatorId = event['creatorId'] ?? '';
        bool hasNoHumanCreator = currentCreatorId == 'system' || currentCreatorId.isEmpty;

        if (isExternal && hasNoHumanCreator) {
          final userDoc = await db.collection('users').doc(currentUser?.uid).get();
          final String userName = userDoc.data()?['username'] ?? userDoc.data()?['name'] ?? 'Anonim';
          updates['creatorId'] = currentUser?.uid;
          updates['creatorName'] = userName;
          updates['isApprovalRequired'] = false; // Disable approval once a creator is assigned
        }

        await db.collection('events').doc(eventId).update(updates);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(needsApproval ? 'İsteğiniz gönderildi.' : 'Etkinliğe katıldınız!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }
}
