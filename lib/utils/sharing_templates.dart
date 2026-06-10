import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SharingTemplates {
  static String eventForInstagramStory(Map<String, dynamic> event) {
    final String title = event['title'] ?? 'Harika bir etkinlik!';
    final String city = event['city'] ?? 'Şehir belirtilmemiş';
    final String fullDesc = event['description'] ?? '';
    
    // Açıklama özeti (ilk 100 karakter veya ilk cümle)
    String summary = "";
    if (fullDesc.isNotEmpty) {
      summary = fullDesc.length > 100 ? "${fullDesc.substring(0, 97)}..." : fullDesc;
      summary = "\n📝 $summary\n";
    }
    
    DateTime date;
    if (event['eventDate'] is Timestamp) {
      date = (event['eventDate'] as Timestamp).toDate();
    } else if (event['eventDate'] is String) {
      date = DateTime.tryParse(event['eventDate']) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }
    
    final String formattedDate = DateFormat('dd MMMM HH:mm', 'tr').format(date);
    
    return "🌟 $title\n"
           "📍 $city\n"
           "📅 $formattedDate\n"
           "$summary\n"
           "Bu akşam ne yapsak diye düşünme! Eventful ile bize katıl. ✨\n\n"
           "#eventful #etkinlik #sosyalleşme #$city";
  }

  static String photoFeatured(Map<String, dynamic> photoData) {
    final String userName = photoData['userName'] ?? 'Bir kullanıcımız';
    
    return "📸 Haftanın Karesi!\n\n"
           "$userName tarafından yakalanan bu harika an, Eventful topluluğunun enerjisini yansıtıyor. ❤️\n\n"
           "Sen de katıl, anılarını paylaş, puanları topla! 🚀\n\n"
           "#eventful #moment #photography #community";
  }

  static String profileShare(String username, int points) {
    return "👋 Selam! Ben Eventful'dayım.\n"
           "👤 Kullanıcı: @$username\n"
           "🏆 Puan: $points\n\n"
           "Beni takip et, beraber etkinliklere gidelim! 🔗\n\n"
           "#eventful #social #newfriends";
  }

  static String weeklySummary() {
    return "📅 Haftalık Etkinlik Rehberin Yayında! 🚀\n\n"
           "Bu hafta İstanbul, Ankara, İzmir ve daha birçok şehirde harika etkinlikler seni bekliyor. 🌟\n\n"
           "Kaydır ve haftalık planını yap! Tüm detaylar Eventful uygulamasında. ✨\n\n"
           "#eventful #haftalıkplan #etkinlikrehberi #konser #tiyatro #sosyalleşme";
  }
}
