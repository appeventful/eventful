import 'dart:math';

class ImageHelper {
  // Kategorileri İngilizce anahtar kelimelere eşleyerek 'bulunamadı' hatasını önlüyoruz.
  static const Map<String, String> _categoryKeywords = {
    'Buluşma': 'meetup,people',
    'Sohbet': 'talk,friends',
    'Konser': 'concert,music',
    'Oyun': 'gaming,fun',
    'Kamp': 'camping,nature',
    'Yürüyüş': 'hiking,mountain',
    'Spor': 'sports,fitness',
    'Teknoloji': 'coding,tech',
    'Eğitim': 'study,school',
    'Parti': 'party,nightlife',
    'Yemek': 'food,restaurant',
    'Kahve': 'coffee,cafe',
    'Sinema': 'movie,cinema',
    'Gezi': 'travel,city',
    'Genel': 'event,gathering',
    'Diğer': 'abstract,background',
  };

  static String getEventImage(String category, String title, String description) {
    final Random random = Random();
    
    // 1. Kategoriden anahtar kelimeleri al (Türkçe başlık yerine İngilizce keyword kullanımı)
    String keywords = _categoryKeywords[category] ?? 'event,social';
    
    // 2. Havuzu genişletmek için rastgele bir stil ekle
    final styles = ['modern', 'vibrant', 'happy', 'professional', 'creative', 'scenic'];
    String style = styles[random.nextInt(styles.length)];

    // 3. Başlığın hash kodu + mikrosaniye + rastgele sayı ile sarsılmaz bir seed oluştur
    // Bu değer LoremFlickr'ın resim havuzundaki 'index'idir.
    final int seed = (title.hashCode.abs() + 
                      DateTime.now().microsecondsSinceEpoch + 
                      random.nextInt(999999)) % 1000000;
    
    // lock=$seed sayesinde her etkinlik havuzdan farklı bir 'index'teki resmi çeker.
    // /all parametresi Unsplash, Flickr ve Pexels dahil tüm kaynakları tarar.
    return 'https://loremflickr.com/800/600/$keywords,$style/all?lock=$seed';
  }
}
