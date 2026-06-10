import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/constants.dart';

class HowToUseScreen extends StatefulWidget {
  const HowToUseScreen({super.key});

  @override
  State<HowToUseScreen> createState() => _HowToUseScreenState();
}

class _HowToUseScreenState extends State<HowToUseScreen> {
  final TextEditingController _questionController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _submitQuestion() async {
    final message = _questionController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data();

      await FirebaseFirestore.instance.collection('support_requests').add({
        'userId': user.uid,
        'userName': userData?['name'] ?? userData?['username'] ?? 'Anonim',
        'userEmail': user.email ?? '',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        _questionController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sorunuz başarıyla iletildi. Admin ekibimiz en kısa sürede dönüş yapacaktır.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIntroCard(isDarkMode),
                  const SizedBox(height: 32),
                  _buildSectionHeader('🚀 Başlangıç Rehberi', 'Uygulamanın temel işleyişi', isDarkMode),
                  _buildTimelineItem(
                    step: '01',
                    title: 'Profilini Güçlendir',
                    content: 'Tamamlanmış bir profil, topluluk içindeki güvenilirliğini artırır. Instagram hesabını bağla, hobilerini ekle ve gerçek bir profil fotoğrafı kullan.',
                    icon: Icons.person_add_rounded,
                  ),
                  _buildTimelineItem(
                    step: '02',
                    title: 'Etkinlikleri Keşfet',
                    content: 'Ana sayfadaki harita ve liste görünümü ile şehrindeki etkinlikleri tara. Kategorilere göre filtreleyerek sana en uygun grubu bul.',
                    icon: Icons.map_outlined,
                  ),
                  _buildTimelineItem(
                    step: '03',
                    title: 'Katıl veya Oluştur',
                    content: 'Mevcut bir etkinliğe dahil ol veya kendi planını yap. Kendi etkinliğini oluştururken detaylı açıklama yazmak daha kaliteli katılımcılar çeker.',
                    icon: Icons.add_task_rounded,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader('⚖️ Güven ve İtibar', 'Puanlama sisteminin detayları', isDarkMode),
                  _buildFeatureGrid(isDarkMode),
                  const SizedBox(height: 32),
                  _buildSectionHeader('🛡️ Kurallar ve Etik', 'Topluluk standartlarımız', isDarkMode),
                  _buildRulesCard(isDarkMode),
                  const SizedBox(height: 40),
                  _buildSupportSection(isDarkMode),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: kPrimaryOrange,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          'Nasıl Çalışır?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [kPrimaryOrange, Color(0xFFFF8A65)],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: Icon(Icons.help_outline, size: 200, color: Colors.white.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isDarkMode ? kPrimaryOrange.withOpacity(0.1) : const Color(0xFFFFF3E0),
            radius: 25,
            child: const Icon(Icons.auto_awesome, color: kPrimaryOrange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Eventful, gerçek hayatta sosyalleşmeyi kolaylaştıran güven odaklı bir topluluktur.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: isDarkMode ? Colors.white : const Color(0xFF2D3436),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDarkMode ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String step,
    required String title,
    required String content,
    required IconData icon,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: kPrimaryOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: Container(
                  width: 2,
                  color: kPrimaryOrange.withOpacity(0.2),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: kPrimaryOrange),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF2D3436),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(bool isDarkMode) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _buildFeatureCard(
          'QR Yoklama',
          'Etkinlikte QR kod okutmak, katılımınızı tesciller ve puan kazandırır.',
          Icons.qr_code_scanner,
          Colors.blue,
          isDarkMode,
        ),
        _buildFeatureCard(
          'Güven Puanı',
          'Dakiklik ve olumlu geri dönüşler puanınızı artırır, ayrıcalık sağlar.',
          Icons.security_rounded,
          Colors.green,
          isDarkMode,
        ),
        _buildFeatureCard(
          'Referanslar',
          'Yeni üyelere referans olmak hem sorumluluk hem prestij getirir.',
          Icons.handshake_rounded,
          Colors.orange,
          isDarkMode,
        ),
        _buildFeatureCard(
          'Rozetler',
          'Aktivitene göre Efsanevi veya Sosyal Kelebek gibi ünvanlar kazanırsın.',
          Icons.workspace_premium_rounded,
          Colors.purple,
          isDarkMode,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(String title, String desc, IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(isDarkMode ? 0.2 : 0.1)),
        boxShadow: isDarkMode ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDarkMode ? Colors.white : const Color(0xFF2D3436),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesCard(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFF2D3436),
        borderRadius: BorderRadius.circular(24),
        border: isDarkMode ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
      ),
      child: Column(
        children: [
          _buildRuleItem('Saygı ve Nezaket', 'Tüm katılımcılara karşı saygılı olun.', Icons.favorite_border, isDarkMode),
          Divider(color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white10),
          _buildRuleItem('Dakiklik', 'Etkinlik saatlerine sadık kalın.', Icons.access_time, isDarkMode),
          Divider(color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white10),
          _buildRuleItem('Güvenlik', 'Şüpheli durumları mutlaka bildirin.', Icons.gpp_maybe_outlined, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String title, String desc, IconData icon, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: isDarkMode ? Colors.grey.shade400 : Colors.white70, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade400 : Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        gradient: isDarkMode ? null : LinearGradient(
          colors: [Colors.white, Colors.orange.shade50.withOpacity(0.3)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kPrimaryOrange.withOpacity(isDarkMode ? 0.2 : 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contact_support_rounded, color: kPrimaryOrange),
              const SizedBox(width: 12),
              Text(
                'Bir Sorum Var',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : const Color(0xFF2D3436),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _questionController,
            maxLines: 4,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Size nasıl yardımcı olabiliriz?',
              hintStyle: TextStyle(color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
              fillColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: isDarkMode ? Colors.white12 : Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: kPrimaryOrange),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSending ? null : _submitQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSending 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Admin Ekibine Gönder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
