import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import 'login_screen.dart';
import 'main_navigation_wrapper.dart';
import 'profile_setup_screen.dart';
import 'email_verification_screen.dart';
import 'banned_screen.dart';
import '../utils/constants.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isDataSynced = false;
  PackageInfo? _packageInfo;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 4), (timer) {
      _performHeartbeat();
    });
    // İlk kalp atışı 1 saniye sonra (Oturumun netleşmesi için)
    Future.delayed(const Duration(seconds: 1), _performHeartbeat);
  }

  void _performHeartbeat() async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      if (user.isAnonymous) {
        _trackGuestActivity(user.uid);
      } else {
        // Üyeler için hem lastLogin (AuthWrapper'da bir kez) hem de anlık lastActive
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(), // Admin panelindeki sorgu için
        }).catchError((e) => debugPrint("Heartbeat update error: $e"));
      }
    } else {
      // Eğer henüz hiç giriş yoksa, anonim girişi tetikle ve cihaz ID ile geçici izle
      AuthService().signInAnonymously();
      String? deviceId = await AuthService().getDeviceId();
      if (deviceId != null) {
        FirebaseFirestore.instance.collection('active_guests').doc('temp_$deviceId').set({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  @override
  Widget build(BuildContext context) {
    if (_packageInfo == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userProvider = Provider.of<UserProvider>(context);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (userProvider.isLoading) {
      return _buildLoadingScreen("Oturum kontrol ediliyor...");
    }

    // Misafir (Anonim) Kontrolü
    if (firebaseUser != null && firebaseUser.isAnonymous) {
      return const MainNavigationWrapper();
    }

    // Giriş Yapılmamışsa
    if (firebaseUser == null) {
      return const MainNavigationWrapper();
    }

    // Profil Kurulumu Yapılmamışsa
    if (userProvider.user == null || userProvider.user!.email.isEmpty) {
      return const ProfileSetupScreen();
    }

    final userModel = userProvider.user!;

    // Kullanıcı Ban Kontrolü (Adminler muaf)
    if (userModel.isBanned && !userModel.isAdmin && userModel.email != adminEmail) {
      return BannedScreen(
        reason: userModel.banReason ?? "Topluluk kurallarını ihlal ettiniz.",
        until: userModel.banUntil?.toDate(),
      );
    }

    // E-posta Doğrulama Kontrolü (Adminler muaf)
    if (!firebaseUser.emailVerified && !userModel.isAdmin && userModel.email != adminEmail) {
      return const EmailVerificationScreen();
    }

    // Senkronizasyon (lastLogin vb.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncUserData(firebaseUser, userModel);
    });

    // Bakım Modu ve Güncelleme Kontrolü
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('app_settings').doc('config').snapshots(),
      builder: (context, configSnapshot) {
        if (!configSnapshot.hasData || !configSnapshot.data!.exists) {
          return const MainNavigationWrapper();
        }

        var data = configSnapshot.data!.data() as Map<String, dynamic>? ?? {};
        bool isAdmin = userModel.isAdmin;

        String minVersion = data['minVersion'] ?? '1.0.0';
        if (_isUpdateRequired(_packageInfo!.version, minVersion) && !isAdmin) {
          String? updateUrl;
          if (Theme.of(context).platform == TargetPlatform.android) {
            updateUrl = data['updateUrlAndroid'];
          } else if (Theme.of(context).platform == TargetPlatform.iOS) {
            updateUrl = data['updateUrlIos'];
          }
          
          return _UpdateRequiredScreen(
            currentVersion: _packageInfo!.version,
            minVersion: minVersion,
            updateUrl: updateUrl,
          );
        }

        bool isMaintenance = data['maintenanceMode'] == true || data['maintenanceMode'] == 'true';
        String message = data['announcement'] ?? "Uygulamamız şu an bakımdadır.";

        if (isMaintenance && !isAdmin) {
          return _MaintenanceScreen(message: message);
        }

        return const MainNavigationWrapper();
      },
    );
  }

  Widget _buildLoadingScreen(String text) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(text),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            const Text("Veri bağlantısı kurulamadı."),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text("Çıkış Yap ve Tekrar Dene"),
            ),
          ],
        ),
      ),
    );
  }

  void _syncUserData(User user, UserModel userModel) async {
    if (_isDataSynced) return;
    _isDataSynced = true;

    Map<String, dynamic> updates = {};
    
    // Hesabı Otomatik Olarak Çöz (Unfreeze)
    if (userModel.isFrozen) {
      updates['isFrozen'] = false;
      updates['reactivationDate'] = FieldValue.serverTimestamp();
      debugPrint("AuthWrapper: User account reactivated.");
    }

    // Son Girişi Güncelle (Sadece login anında bir kez)
    updates['lastLogin'] = FieldValue.serverTimestamp();

    if (userModel.deviceId == null) {
      String? deviceId = await AuthService().getDeviceId();
      if (deviceId != null) {
        updates['deviceId'] = deviceId;
      }
    }

    if (updates.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updates);
        debugPrint("AuthWrapper: User data synced to Firestore.");
      } catch (e) {
        debugPrint("AuthWrapper Sync Error: $e");
      }
    }
  }

  bool _isUpdateRequired(String current, String min) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> minParts = min.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int m = i < minParts.length ? minParts[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
    } catch (e) {
      debugPrint("Version check error: $e");
    }
    return false;
  }

  void _trackGuestActivity(String uid) {
    FirebaseFirestore.instance.collection('active_guests').doc(uid).set({
      'lastActive': FieldValue.serverTimestamp(),
    });
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  final String currentVersion;
  final String minVersion;
  final String? updateUrl;

  const _UpdateRequiredScreen({
    required this.currentVersion,
    required this.minVersion,
    this.updateUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_alt_rounded, size: 80, color: Colors.orange),
            ),
            const SizedBox(height: 40),
            const Text(
              "GÜNCELLEME VAKTİ!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            Text(
              "Kullanmakta olduğunuz sürüm ($currentVersion) artık desteklenmiyor. En iyi deneyim ve yeni özellikler için lütfen uygulamayı güncelleyin.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.5),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(updateUrl ?? 'https://www.eventfulapp.org');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Şimdi Güncelle", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: Text("Daha Sonra / Çıkış Yap", style: TextStyle(color: Colors.grey.shade500)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceScreen extends StatelessWidget {
  final String message;
  const _MaintenanceScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.orange.shade300, Colors.red.shade400],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_circle_outlined, size: 100, color: Colors.white),
            const SizedBox(height: 30),
            const Text(
              "BİRAZ ARA VERDİK",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 15),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
              ),
              child: const Text("Çıkış Yap"),
            ),
          ],
        ),
      ),
    );
  }
}
