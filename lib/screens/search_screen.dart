import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import '../widgets/custom_avatar.dart';
import '../services/chat_service.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'event_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Ara (Kullanıcı veya Etkinlik)',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Theme.of(context).hintColor),
          ),
          onChanged: (val) {
            setState(() => _searchQuery = val.trim().toLowerCase());
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Kullanıcılar'),
            Tab(text: 'Etkinlikler'),
          ],
        ),
        elevation: 1,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUserSearch(),
          _buildEventSearch(),
        ],
      ),
    );
  }

  Widget _buildUserSearch() {
    if (_searchQuery.isEmpty) {
      return const Center(child: Text('Aramak istediğiniz kişinin adını veya kullanıcı adını yazın.'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Kullanıcı bulunamadı.'));

        var filteredUsers = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = (data['name'] ?? "").toString().toLowerCase();
          String username = (data['username'] ?? "").toString().toLowerCase();
          String email = (data['email'] ?? "").toString().toLowerCase();
          String query = _searchQuery.startsWith('@') ? _searchQuery.substring(1) : _searchQuery;
          return name.contains(query) || username.contains(query) || email.contains(query);
        }).toList();

        if (filteredUsers.isEmpty) return const Center(child: Text('Kullanıcı bulunamadı.'));

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = UserModel.fromFirestore(filteredUsers[index]);
            final String uid = filteredUsers[index].id;
            if (uid == FirebaseAuth.instance.currentUser?.uid) return const SizedBox.shrink();

            return ListTile(
              leading: CustomAvatar(
                imageUrl: user.profileImage,
                isPassive: user.isFrozen || user.isDeleted,
              ),
              title: Text(user.name, style: TextStyle(decoration: (user.isFrozen || user.isDeleted) ? TextDecoration.lineThrough : null)),
              subtitle: Text(user.username.isNotEmpty ? '@${user.username}' : user.email),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (AuthService().isGuest) {
                  GuestGuardDialog.show(context, "Profil görüntüleme");
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(otherUserId: uid)));
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEventSearch() {
    if (_searchQuery.isEmpty) {
      return const Center(child: Text('Aramak istediğiniz etkinliğin adını veya açıklamasını yazın.'));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events')
          .where('isApproved', isEqualTo: true)
          .where('isArchived', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Etkinlik bulunamadı.'));

        var filteredEvents = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String title = (data['title'] ?? "").toString().toLowerCase();
          String desc = (data['description'] ?? "").toString().toLowerCase();
          String city = (data['city'] ?? "").toString().toLowerCase();
          return title.contains(_searchQuery) || desc.contains(_searchQuery) || city.contains(_searchQuery);
        }).toList();

        if (filteredEvents.isEmpty) return const Center(child: Text('Etkinlik bulunamadı.'));

        return ListView.builder(
          itemCount: filteredEvents.length,
          itemBuilder: (context, index) {
            var data = filteredEvents[index].data() as Map<String, dynamic>;
            String id = filteredEvents[index].id;
            final rawDate = data['eventDate'];
            DateTime date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();

            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                    ? Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.event))
                    : const Icon(Icons.event, size: 50),
              ),
              title: Text(data['title'] ?? 'Başlıksız', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${data['city'] ?? ''} - ${DateFormat('dd MMM, HH:mm', 'tr_TR').format(date)}"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: id))),
            );
          },
        );
      },
    );
  }
}
