import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:etkinlik_io_api/etkinlik_io_api.dart';
import 'package:dio/dio.dart';

class EventScraperService {
  static const String _apiToken = "aa492d9164a308fe8f9d75af035838f9";
  
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://etkinlik.io/api/v2/',
    headers: {'X-Etkinlik-Token': _apiToken},
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static final _api = EtkinlikIoApi(dio: _dio);

  // SDK transformer'ı olmayan temiz bir dio (manuel fetch için)
  static final _cleanDio = Dio(BaseOptions(
    baseUrl: 'https://etkinlik.io/api/v2/',
    headers: {'X-Etkinlik-Token': _apiToken},
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ))..interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path.startsWith('/')) {
        options.path = options.path.substring(1);
      }
      return handler.next(options);
    },
  ));

  static final Map<String, int> _cityIds = {
    'Adana': 1, 'Adıyaman': 2, 'Afyon': 3, 'Afyonkarahisar': 85, 'Ağrı': 4, 'Aksaray': 5,
    'Amasya': 6, 'Ankara': 7, 'Antalya': 8, 'Ardahan': 9, 'Artvin': 10, 'Aydın': 11,
    'Balıkesir': 12, 'Bartın': 13, 'Batman': 14, 'Bayburt': 15, 'Bilecik': 16, 'Bingöl': 17,
    'Bitlis': 18, 'Bolu': 19, 'Burdur': 20, 'Bursa': 21, 'Çanakkale': 22, 'Çankırı': 23,
    'Çorum': 24, 'Denizli': 25, 'Diyarbakır': 26, 'Düzce': 27, 'Edirne': 28, 'Elazığ': 29,
    'Erzincan': 30, 'Erzurum': 31, 'Eskişehir': 32, 'Gaziantep': 33, 'Giresun': 34,
    'Gümüşhane': 35, 'Hakkari': 36, 'Hatay': 37, 'Iğdır': 38, 'Isparta': 38, 'İstanbul': 40,
    'İzmir': 41, 'Kahramanmaraş': 42, 'Karabük': 43, 'Karaman': 44, 'Kars': 45,
    'Kastamonu': 46, 'Kayseri': 47, 'Kilis': 51, 'Kırıkkale': 48, 'Kırklareli': 49,
    'Kırşehir': 50, 'Kocaeli': 52, 'Konya': 53, 'Kütahya': 54, 'Malatya': 55, 'Manisa': 56,
    'Mardin': 57, 'Mersin': 58, 'Muğla': 59, 'Muş': 60, 'Nevşehir': 61, 'Niğde': 62,
    'Ordu': 63, 'Osmaniye': 64, 'Rize': 65, 'Sakarya': 66, 'Samsun': 67, 'Şanlıurfa': 71,
    'Siirt': 68, 'Sinop': 69, 'Şırnak': 72, 'Sivas': 70, 'Tekirdağ': 73, 'Tokat': 74,
    'Trabzon': 75, 'Tunceli': 76, 'Uşak': 77, 'Van': 78, 'Yalova': 79, 'Yozgat': 80,
    'Zonguldak': 81, 'İzmit': 52, 'Adapazarı': 66, 'İçel': 58, 'Mersin (İçel)': 58,
    'Antakya': 37, 'İskenderun': 37
  };

  static Future<List<Map<String, dynamic>>> fetchEvents(String city) async {
    try {
      String? cityIdsStr;
      if (city != 'Tümü' && _cityIds.containsKey(city)) {
        cityIdsStr = _cityIds[city]!.toString();
      }

      debugPrint("Etkinlik İsteği (Manuel): Şehir=$city, CityID=$cityIdsStr");

      // SDK deserialization hatası verdiği için manuel fetch yapıyoruz
      final response = await _cleanDio.get('/events', queryParameters: {
        if (cityIdsStr != null) 'city_ids': cityIdsStr,
        'take': 100,
        'sort_by': 'upcoming',
      });

      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> items = response.data['items'] ?? [];
        debugPrint("API Yanıtı: ${items.length} etkinlik bulundu.");

        final List<Map<String, dynamic>> processedEvents = [];
        
        for (var item in items) {
          final venue = item['venue'];
          final eventCity = venue?['city']?['name']?.toString().toLowerCase() ?? '';
          final targetCity = city.toLowerCase();
          final bool cityMatches = city == 'Tümü' || eventCity.contains(targetCity) || targetCity.contains(eventCity);
          
          if (!cityMatches) continue;

          // Tarih işlemleri
          final String? dateStr = item['start'];
          if (dateStr == null) continue;
          
          final DateTime eventDate = DateTime.parse(dateStr);
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          final bool isFutureOrToday = eventDate.isAfter(today) || (eventDate.year == today.year && eventDate.month == today.month && eventDate.day == today.day);
          
          if (!isFutureOrToday) continue;

          String? imageUrl = item['poster_url'];
          final category = item['category']?['name'] ?? '';

          processedEvents.add({
            'externalId': item['id']?.toString() ?? '',
            'title': item['name'] ?? 'Başlıksız Etkinlik',
            'description': _cleanHtml(item['content'] ?? 'Detaylı bilgi bulunmuyor.'),
            'location': venue?['name'] ?? city,
            'address': venue?['address'] ?? '',
            'latitude': double.tryParse(venue?['lat']?.toString() ?? ''),
            'longitude': double.tryParse(venue?['lng']?.toString() ?? ''),
            'city': city == 'Tümü' ? (venue?['city']?['name'] ?? 'İstanbul') : city,
            'date': eventDate,
            'category': _mapToInternalCategory(category),
            'imageUrl': (imageUrl != null && imageUrl.isNotEmpty) 
                ? imageUrl 
                : _getFallbackImage(category),
            'link': item['url'] ?? '',
            'source': 'Etkinlik.io',
            'externalSource': true,
          });
        }

        return processedEvents;
      }
      return [];
    } catch (e) {
      debugPrint("fetchEvents manuel hata: $e");
      return [];
    }
  }

  static Future<void> scrapeAndSaveEvents({required String city, int limit = 10}) async {
    List<Map<String, dynamic>> events = await fetchEvents(city);
    
    if (limit < events.length) {
      events.shuffle();
    }

    final db = FirebaseFirestore.instance;
    
    int saved = 0;
    for (var event in events) {
      if (saved >= limit) break;
      
      if (event['externalId'].isNotEmpty) {
        final existingById = await db.collection('events').where('externalId', isEqualTo: event['externalId']).get();
        if (existingById.docs.isNotEmpty) continue;
      }

      if (event['link'].isNotEmpty) {
        final existingByLink = await db.collection('events').where('link', isEqualTo: event['link']).get();
        if (existingByLink.docs.isNotEmpty) continue;
      }

      final Timestamp eventTs = Timestamp.fromDate(event['date']);
      final existingByContent = await db.collection('events')
          .where('title', isEqualTo: event['title'])
          .where('city', isEqualTo: event['city'])
          .where('eventDate', isEqualTo: eventTs)
          .get();
      
      if (existingByContent.docs.isNotEmpty) continue;

      await db.collection('events').add({
        ...event,
        'eventDate': eventTs,
        'isApproved': true,
        'isArchived': false,
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': 'system_scraper',
        'participants': [],
        'pendingParticipants': [],
      });
      saved++;
    }
  }

  static Future<void> scrapeOneFromEveryCity() async {
    for (String city in _cityIds.keys) {
      await scrapeAndSaveEvents(city: city, limit: 1);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  static Future<void> scrapeFiveFromSelectedCities(List<String> cities) async {
    for (String city in cities) {
      await scrapeAndSaveEvents(city: city, limit: 5);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  static Future<Map<String, dynamic>> fetchFullEventDetails(String link) async {
    // Note: The SDK typically allows getting details by ID. 
    // Since we usually have the ID in our system if it came from the API, 
    // this method could be improved to take an ID.
    // For now, keeping it consistent with previous signature but leveraging the SDK's models if we had the ID.
    return {};
  }

  static Future<Map<String, dynamic>> fetchEventById(int id) async {
    try {
      final response = await _cleanDio.get('/events/$id');
      if (response.statusCode == 200 && response.data != null) {
        final item = response.data;
        final venue = item['venue'];
        return {
          'description': _cleanHtml(item['content'] ?? ''),
          'latitude': double.tryParse(venue?['lat']?.toString() ?? ''),
          'longitude': double.tryParse(venue?['lng']?.toString() ?? ''),
          'address': venue?['address'] ?? '',
        };
      }
    } catch (e) {
      debugPrint("fetchEventById error: $e");
    }
    return {};
  }

  static String _cleanHtml(String html) {
    if (html.isEmpty) return "";
    String result = html
        .replaceAll(RegExp(r'<(br|p|div|li)[^>]*>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ')
        .replaceAll('&#039;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();

    result = result.replaceAll(RegExp(r' +'), ' ');
    result = result.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    return result.trim();
  }

  static String _getFallbackImage(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('konser')) return 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=500';
    if (cat.contains('tiyatro') || cat.contains('sahne')) return 'https://images.unsplash.com/photo-1507676184212-d03ab07a01bf?w=500';
    if (cat.contains('spor')) return 'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=500';
    if (cat.contains('eğitim')) return 'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=500';
    return 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=500';
  }

  static String _mapToInternalCategory(String externalCat) {
    final lower = externalCat.toLowerCase();
    if (lower.contains('konser') || lower.contains('müzik')) return 'Konser';
    if (lower.contains('tiyatro') || lower.contains('sahne')) return 'Oyun';
    if (lower.contains('eğitim')) return 'Eğitim';
    if (lower.contains('spor')) return 'Spor';
    return 'Genel';
  }
}
