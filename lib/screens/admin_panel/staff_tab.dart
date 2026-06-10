import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_avatar.dart';

class StaffTab extends StatelessWidget {
  final Function(String uid, Map<String, dynamic> data) onShowUserOptions;

  const StaffTab({
    super.key,
    required this.onShowUserOptions,
  });

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
              Icon(Icons.security, color: kPrimaryOrange),
              SizedBox(width: 12),
              Text(
                'Tüm Moderatörler ve İl Temsilcileri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: db.collection('users')
                .where('role', whereIn: ['admin', 'moderator', 'city_representative'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Hata: ${snapshot.error}'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final staff = snapshot.data!.docs;

              if (staff.isEmpty) {
                return const Center(child: Text('Henüz yetkili atanmamış.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: staff.length,
                itemBuilder: (context, index) {
                  final user = staff[index];
                  final data = user.data() as Map<String, dynamic>;
                  final String role = data['role'] ?? 'user';
                  
                  String roleLabel = 'Bilinmeyen';
                  Color roleColor = Colors.grey;
                  
                  if (role == 'admin') {
                    roleLabel = 'Admin';
                    roleColor = Colors.redAccent;
                  } else if (role == 'moderator') {
                    roleLabel = 'Moderatör';
                    roleColor = Colors.blueAccent;
                  } else if (role == 'city_representative') {
                    roleLabel = '${data['responsibleCity'] ?? "İl"} Temsilcisi';
                    roleColor = Colors.greenAccent;
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CustomAvatar(imageUrl: data['profileImage'], radius: 20),
                      title: Text(data['username'] ?? 'Adsız', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['email'] ?? ''),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: roleColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () => onShowUserOptions(user.id, data),
                      ),
                      onTap: () => onShowUserOptions(user.id, data),
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
