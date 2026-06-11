import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_wrapper.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.orange.shade50.withValues(alpha: 0.5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: IntroductionScreen(
            pages: [
              PageViewModel(
                title: "Şehrini Keşfetmeye Hazır mısın? ✨",
                body: "Eventful ile çevrendeki gizli kalmış konserlerden, sabah koşularına kadar her şeyi keşfet. Sosyalleşmek hiç bu kadar kolay olmamıştı!",
                image: _buildImage(Icons.explore_rounded, Colors.orange),
                decoration: _getPageDecoration(Colors.orange),
              ),
              PageViewModel(
                title: "Güven Seninle Olsun! 🛡️",
                body: "Sadece gerçek insanlar, gerçek deneyimler! Referans sistemimiz sayesinde topluluk içindeki güvenini artır ve yeni dostluklara yelken aç.",
                image: _buildImage(Icons.verified_user_rounded, Colors.teal),
                decoration: _getPageDecoration(Colors.teal),
              ),
              PageViewModel(
                title: "Kendi Etkinliğini Tasarla 🎨",
                body: "İster bir kitap kulübü kur, ister halı saha maçı organize et. Hayalindeki etkinliği oluştur ve seninle aynı tutkuyu paylaşanları bul!",
                image: _buildImage(Icons.add_circle_outline_rounded, Colors.blueAccent),
                decoration: _getPageDecoration(Colors.blueAccent),
              ),
              PageViewModel(
                title: "Eğlenirken Rozetleri Topla! 🏆",
                body: "Etkinliklere katıldıkça puan kazan, liderlik tablosunda yüksel ve profilini havalı rozetlerle süsle. Şehrin fenomeni olmaya aday mısın?",
                image: _buildImage(Icons.emoji_events_rounded, Colors.amber),
                decoration: _getPageDecoration(Colors.amber),
              ),
              PageViewModel(
                title: "Her Şey Hazır! 🚀",
                body: "Kayıt olduktan sonra profil sayfasındaki 'Uygulama Nasıl Çalışır?' rehberine göz atmayı unutma. Orada sana özel ipuçları sakladık!",
                image: _buildImage(Icons.rocket_launch_rounded, Colors.deepPurple),
                decoration: _getPageDecoration(Colors.deepPurple),
              ),
            ],
            onDone: () => _completeOnboarding(context),
            onSkip: () => _completeOnboarding(context),
            showSkipButton: true,
            skipOrBackFlex: 0,
            nextFlex: 0,
            showBackButton: false,
            skip: const Text("Atla", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 16)),
            next: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ),
            done: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                ],
              ),
              child: const Text("Hadi Başla", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            curve: Curves.fastLinearToSlowEaseIn,
            controlsMargin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            controlsPadding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
            dotsDecorator: const DotsDecorator(
              size: Size(8.0, 8.0),
              color: Color(0xFFD1D1D1),
              activeSize: Size(20.0, 8.0),
              activeColor: Colors.orange,
              activeShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(25.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(IconData icon, Color color) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 40),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 120, color: color),
      ),
    );
  }

  PageDecoration _getPageDecoration(Color titleColor) {
    return PageDecoration(
      titleTextStyle: TextStyle(fontSize: 26.0, fontWeight: FontWeight.bold, color: titleColor, letterSpacing: -0.5),
      bodyTextStyle: TextStyle(fontSize: 17.0, color: Colors.grey.shade800, height: 1.6),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 32),
      pageColor: Colors.transparent,
      imagePadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.only(top: 60, bottom: 24),
    );
  }
}
