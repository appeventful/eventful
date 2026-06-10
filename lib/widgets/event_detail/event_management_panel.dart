import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_avatar.dart';
import '../../screens/attendance_screen.dart';
import '../../utils/constants.dart';

class EventManagementPanel extends StatelessWidget {
  final String eventId;
  final Map<String, dynamic> event;
  final List participants;
  final List pending;
  final DateTime date;
  final bool isPast;
  final VoidCallback onGenerateRefCode;
  final Function(Map<String, dynamic> event) onHandleQRAction;
  final Function(String userId) onApproveUser;
  final Function(String userId) onRejectUser;
  final Function(String userId) onRemoveUser;
  final Function(String userId) onTransferOwnership;

  const EventManagementPanel({
    super.key,
    required this.eventId,
    required this.event,
    required this.participants,
    required this.pending,
    required this.date,
    required this.isPast,
    required this.onGenerateRefCode,
    required this.onHandleQRAction,
    required this.onApproveUser,
    required this.onRejectUser,
    required this.onRemoveUser,
    required this.onTransferOwnership,
  });

  @override
  Widget build(BuildContext context) {
    bool isEventTime = DateTime.now().isAfter(date.subtract(const Duration(minutes: 15)));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: Colors.blue),
              SizedBox(width: 8),
              Text('Yönetim Paneli', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: () => _showParticipantsManagement(context),
            icon: const Icon(Icons.people_outline),
            label: Text('Katılımcıları Yönet (${pending.length + participants.length})'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              if (!isPast)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onGenerateRefCode,
                    icon: const Icon(Icons.qr_code_2_outlined, size: 18),
                    label: const Text('Kod Üret', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      elevation: 0,
                      side: BorderSide(color: Colors.blue.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (!isPast) const SizedBox(width: 8),
              if (isEventTime)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => onHandleQRAction(event),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('QR Kod', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ),
          if (isEventTime) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(eventId: eventId))),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Manuel Yoklama Masası', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showParticipantsManagement(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Katılımcı Yönetimi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  if (pending.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Onay Bekleyenler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                    ),
                    ...pending.map((uid) => _buildUserManagementTile(uid, isPending: true)),
                    const Divider(),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Katılımcılar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                  if (participants.isEmpty) const Center(child: Text('Henüz katılımcı yok.', style: TextStyle(color: Colors.grey))),
                  ...participants.map((uid) => _buildUserManagementTile(uid, isPending: false)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserManagementTile(String userId, {required bool isPending}) {
    final db = FirebaseFirestore.instance;
    final creatorId = event['creatorId'];
    if (userId == creatorId) return const SizedBox.shrink(); // Hide creator from self-management

    return StreamBuilder<DocumentSnapshot>(
      stream: db.collection('users').doc(userId).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();

        final user = UserModel.fromFirestore(snap.data!);
        final bool isPassive = user.isFrozen || user.isDeleted;

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: CustomAvatar(
              radius: 14,
              imageUrl: user.profileImage,
              isPassive: isPassive,
              badgeIcons: user.badges.map((id) {
                final badge = availableBadges.firstWhere(
                  (b) => b['id'] == id,
                  orElse: () => {'icon': ''},
                );
                return badge['icon'] as String;
              }).where((icon) => icon.isNotEmpty).toList(),
            ),
            title: Text(
              user.username.isNotEmpty ? user.username : user.name,
              style: TextStyle(
                fontSize: 13,
                color: isPassive ? Colors.grey : Colors.black,
                decoration: isPassive ? TextDecoration.lineThrough : null,
              )
            ),
            trailing: isPending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20), onPressed: () => onApproveUser(userId), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    IconButton(icon: const Icon(Icons.highlight_off, color: Colors.red, size: 20), onPressed: () => onRejectUser(userId), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
                      onPressed: () => onTransferOwnership(userId),
                      tooltip: 'Organizatörlüğü Devret',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.person_remove_outlined, color: Colors.red, size: 18),
                      onPressed: () => onRemoveUser(userId),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
          ),
        );
      },
    );
  }
}
