import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/custom_avatar.dart';

class UsersTab extends StatefulWidget {
  final Function(String uid, Map<String, dynamic> data) onShowUserOptions;
  final String initialStatus;
  final Function(String url)? launchUrl;
  final String? Function(String error)? extractIndexUrl;

  const UsersTab({
    super.key,
    required this.onShowUserOptions,
    this.initialStatus = 'Fotoğraf Onayı Bekleyenler',
    this.launchUrl,
    this.extractIndexUrl,
  });

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _userSearchQuery = "";
  late String _userStatusFilter;

  @override
  void initState() {
    super.initState();
    _userStatusFilter = widget.initialStatus;
  }

  @override
  void didUpdateWidget(UsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      setState(() => _userStatusFilter = widget.initialStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Ara (İsim/Email/Username)', 
                    prefixIcon: Icon(Icons.search), 
                    border: OutlineInputBorder()
                  ),
                  onChanged: (v) => setState(() => _userSearchQuery = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _userStatusFilter,
                items: [
                  'Fotoğraf Onayı Bekleyenler', 
                  'E-postası Onaylanmamış', 
                  'Hepsi', 
                  'Çevrimiçi', 
                  'Kısıtlı', 
                  'Kısıtlı (Yakın)', 
                  'Banlı', 
                  'Dondurulmuş', 
                  'Silinmiş'
                ].map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _userStatusFilter = v!),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final errorStr = snapshot.error.toString();
                final indexUrl = widget.extractIndexUrl?.call(errorStr);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 48),
                        const SizedBox(height: 16),
                        const Text('Veri çekme hatası (İndeks gerekiyor olabilir)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (indexUrl != null && widget.launchUrl != null) 
                          ElevatedButton.icon(
                            onPressed: () => widget.launchUrl!(indexUrl), 
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Gerekli İndeksi Oluştur'),
                          )
                        else
                          Text(errorStr, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var users = snapshot.data!.docs.where((d) {
                var data = d.data() as Map<String, dynamic>;
                bool matchesSearch = (data['email'] ?? '').toString().toLowerCase().contains(_userSearchQuery) ||
                                     (data['username'] ?? '').toString().toLowerCase().contains(_userSearchQuery);
                
                bool matchesFilter = true;
                if (_userStatusFilter == 'Fotoğraf Onayı Bekleyenler') {
                  matchesFilter = data['isProfileImageApproved'] == false && data['profileImage'] != null;
                } else if (_userStatusFilter == 'E-postası Onaylanmamış') {
                  matchesFilter = data['emailVerified'] != true;
                } else if (_userStatusFilter == 'Banlı') {
                  matchesFilter = data['isBanned'] == true;
                } else if (_userStatusFilter == 'Kısıtlı') {
                  matchesFilter = data['isRestricted'] == true;
                } else if (_userStatusFilter == 'Dondurulmuş') {
                  matchesFilter = data['isFrozen'] == true;
                } else if (_userStatusFilter == 'Silinmiş') {
                  matchesFilter = data['isDeleted'] == true;
                } else if (_userStatusFilter == 'Kısıtlı (Yakın)') {
                   double trust = (data['trustScore'] ?? 0.0).toDouble();
                   int points = (data['points'] ?? 0).toInt();
                   matchesFilter = (trust < 20.0 || points < 0) && data['isRestricted'] != true && data['isBanned'] != true;
                } else if (_userStatusFilter == 'Çevrimiçi') {
                   var lastLogin = data['lastLogin'] as Timestamp?;
                   matchesFilter = lastLogin != null && lastLogin.toDate().isAfter(DateTime.now().subtract(const Duration(minutes: 5)));
                }

                return matchesSearch && matchesFilter;
              }).toList();

              if (users.isEmpty) {
                return const Center(child: Text('Kullanıcı bulunamadı.'));
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  var user = users[index];
                  var data = user.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CustomAvatar(imageUrl: data['profileImage'], radius: 20),
                    title: Row(
                      children: [
                        Flexible(child: Text(data['username'] ?? 'Adsız', overflow: TextOverflow.ellipsis)),
                        if (data['emailVerified'] == true)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified, color: Colors.blue, size: 14),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['email'] ?? '', style: const TextStyle(fontSize: 12)),
                        if (data['isRestricted'] == true)
                          Text(
                            'Kalan Katılım: ${5 - (data['referenceParticipationCount'] ?? 0)}',
                            style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data['isBanned'] == true) const Icon(Icons.block, color: Colors.red, size: 16),
                        if (data['isRestricted'] == true) const Icon(Icons.gavel, color: Colors.orange, size: 16),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => widget.onShowUserOptions(user.id, data),
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
