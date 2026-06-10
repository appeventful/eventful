import 'package:flutter/material.dart';

const Color kPrimaryOrange = Color(0xFFFFAB40);
const Color kDeepCharcoal = Color(0xFF121212);
const Color kSurfaceDark = Color(0xFF1E1E1E);

const List<String> categories = [
  'Buluşma', 'Sohbet', 'Konser', 'Oyun', 'Kamp', 'Yürüyüş', 'Spor', 'Teknoloji', 'Eğitim', 'Genel', 'Diğer'
];

const List<String> cities = [
  'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
];

const String adminEmail = 'eventful@eventfulapp.org';
const String adminPhone = '905327499938';

const String defaultCommunityRules = '''Saygı ve Nezaket: Diğer üyelere karşı saygılı olun; hakaret, küfür veya ayrımcı söylemler yasaktır.

Spam Yasağı: Reklam, alakasız link paylaşımı ve üst üste mesaj gönderimi yapmayın.

Gizlilik: Diğer kullanıcıların kişisel bilgilerini paylaşmayın ve güvenliğiniz için kendi hassas verilerinizi saklı tutun.

Konu Dışı Mesajlar: Sohbetleri grup amacına uygun tutmaya özen gösterin.''';

const String defaultTermsOfUse = '''Uygulama Kullanım Koşulları:
1. Uygulamayı kullanarak bu koşulları kabul etmiş sayılırsınız.
2. Oluşturulan etkinliklerden kullanıcıların kendileri sorumludur.
3. Topluluk kurallarına aykırı davranışlar hesabınızın kısıtlanmasına neden olabilir.
4. Diğer kullanıcıları rahatsız edici paylaşımlar yapmak yasaktır.''';

const String defaultPrivacyPolicy = '''Gizlilik Politikası:
1. Kişisel verileriniz sadece uygulama deneyiminizi iyileştirmek için kullanılır.
2. E-posta adresiniz ve telefon numaranız üçüncü şahıslarla paylaşılmaz.
3. Uygulama içi mesajlaşmalarınız şifrelenmiş olarak saklanır.
4. Dilediğiniz zaman hesabınızı ve verilerinizi silebilirsiniz.''';

const String defaultKVKK = '''KVKK Aydınlatma Metni:
6698 sayılı Kişisel Verilerin Korunması Kanunu uyarınca, verileriniz işlenmektedir.
- Veri Sorumlusu: Eventful Uygulama Yönetimi
- İşleme Amacı: Etkinlik yönetimi ve topluluk iletişimi
- Haklarınız: Verilerinize erişme, düzeltme ve silme hakkına sahipsiniz.''';

const List<Map<String, dynamic>> availableBadges = [
  {'id': 'founder', 'name': 'Kurucu', 'icon': '🌟', 'color': 'amber', 'description': 'Uygulamanın başlangıç döneminde aramıza katılan öncü üyelerimizden birisiniz.'},
  {'id': 'verified', 'name': 'Onaylı Üye', 'icon': '✅', 'color': 'blue', 'description': 'Kimliği ve profil fotoğrafı moderatörler tarafından doğrulanmış güvenilir üye.'},
  {'id': 'top_organizer', 'name': 'Süper Düzenleyici', 'icon': '🔥', 'color': 'red', 'description': 'Sürekli ve kaliteli etkinlikler düzenleyerek topluluğu canlı tutan üye.'},
  {'id': 'helper', 'name': 'Yardımsever', 'icon': '🤝', 'color': 'green', 'description': 'Diğer kullanıcılara her konuda destek olan ve pozitif geri bildirim alan üye.'},
  {'id': 'event_master', 'name': 'Etkinlik Ustası', 'icon': '🏆', 'color': 'purple', 'description': 'En az 10 başarılı etkinlik düzenleyerek organizasyon yeteneğini kanıtlamış üye.'},
  {'id': 'loyal_user', 'name': 'Sadık Üye', 'icon': '💎', 'color': 'cyan', 'description': '500 puana ulaşarak Eventful ailesine bağlılığını göstermiş kıdemli üye.'},
  {'id': 'explorer', 'name': 'Kaşif', 'icon': '🗺️', 'color': 'orange', 'description': 'Farklı kategorilerde en az 5 farklı etkinliğe katılan macera sever üye.'},
  {'id': 'chatter', 'name': 'Sohbet Uzmanı', 'icon': '💬', 'color': 'lightBlue', 'description': 'Topluluk sohbetlerinde aktif rol alan ve iletişimi kuvvetli üye.'},
  {'id': 'photographer', 'name': 'Anı Yakalayıcı', 'icon': '📸', 'color': 'pink', 'description': 'Etkinliklerde paylaştığı fotoğraflarla anıları ölümsüzleştiren üye.'},
];
