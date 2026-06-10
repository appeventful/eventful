import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_wrapper.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isEmailVerified = false;
  bool _canResendEmail = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!_isEmailVerified) {
      _sendVerificationEmail();
      _timer = Timer.periodic(const Duration(seconds: 10), (_) => _checkEmailVerified());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && user.emailVerified) {
        await user.getIdToken(true); // Verileri zorla yenile
        if (mounted) {
          setState(() => _isEmailVerified = true);
        }
        _timer?.cancel();
      }
    } catch (e) {
      debugPrint("Email verification check error: $e");
      // rate-limit durumunda timer'ı durdurma, sadece hatayı yut
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      setState(() => _canResendEmail = false);
      await Future.delayed(const Duration(seconds: 10));
      if (mounted) setState(() => _canResendEmail = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _contactSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'eventful@eventfulapp.org',
      queryParameters: {
        'subject': 'E-posta Doğrulama Sorunu',
        'body': 'Merhaba, e-posta doğrulama adımında sorun yaşıyorum.\nE-posta Adresim: ${FirebaseAuth.instance.currentUser?.email}'
      },
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEmailVerified) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 20),
              const Text('Doğrulama Başarılı!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()), (route) => false),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                child: const Text('Uygulamaya Başla'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('E-postanı Doğrula'), actions: [
        IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.email_outlined, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              '${FirebaseAuth.instance.currentUser?.email}\nadresine bir bağlantı gönderdik.', 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lütfen gereksiz (spam) kutunuzu kontrol etmeyi unutmayın.',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _canResendEmail ? _sendVerificationEmail : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_canResendEmail ? 'Doğrulama Linkini Tekrar Gönder' : 'Biraz Bekleyin...'),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Hala sorun mu yaşıyorsunuz?',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showDirectFeedbackDialog,
                icon: const Icon(Icons.support_agent),
                label: const Text('Sorun Bildir'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _contactSupport,
              child: const Text('Destek ekibine e-posta gönder', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDirectFeedbackDialog() {
    final controller = TextEditingController(text: "E-posta doğrulama linki ulaşmadı veya hata alıyorum.");
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Sorun Bildir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Doğrulama süreciyle ilgili yaşadığınız sorunu adminlerimize iletebilirsiniz.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                enabled: !isSending,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Mesajınız...',
                ),
              ),
              if (isSending)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(color: Colors.orange),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: isSending ? null : () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                setDialogState(() => isSending = true);

                try {
                  // Kullanıcı dökümanından ismi al
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final String name = userDoc.data()?['name'] ?? 'İsimsiz Kullanıcı';
                  final String email = user.email ?? 'E-posta yok';

                  // Geri bildirimi kaydet
                  await FirebaseFirestore.instance.collection('feedback').add({
                    'userId': user.uid,
                    'userName': name,
                    'userEmail': email,
                    'type': 'bug',
                    'message': '[E-POSTA DOĞRULAMA SORUNU]\nKullanıcı: $name\nE-posta: $email\n\nMesaj: ${controller.text.trim()}',
                    'status': 'pending',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sorununuz iletildi. En kısa sürede incelenecektir.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSending = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(isSending ? 'Gönderiliyor...' : 'Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
