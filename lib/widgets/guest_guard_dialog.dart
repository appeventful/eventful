import 'package:flutter/material.dart';
import '../screens/login_screen.dart';

class GuestGuardDialog extends StatelessWidget {
  final String featureName;
  const GuestGuardDialog({super.key, required this.featureName});

  static void show(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => GuestGuardDialog(featureName: featureName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Column(
        children: [
          Icon(Icons.lock_person_rounded, color: Colors.orange, size: 48),
          SizedBox(height: 16),
          Text('Üye Olmanız Gerekiyor', textAlign: TextAlign.center),
        ],
      ),
      content: Text(
        '$featureName özelliğini kullanabilmek için bir hesap oluşturmanız veya giriş yapmanız gerekmektedir.',
        textAlign: TextAlign.center,
      ),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginScreen())
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Şimdi Kayıt Ol / Giriş Yap', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Daha Sonra', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ],
    );
  }
}
