import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EventScraperService {
  static const String _apiToken = "aa492d9164a308fe8f9d75af035838f9";
  static const String _baseUrl = "https://etkinlik.io/api/v2";

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
    'Zonguldak': 81
  };

  static Future<List<Map<String, dynamic>>> fetchEvents(String city) async {
    try {
      Map<String, String> queryParams = {
        'limit': '100',
      };

      if (city != 'Tümü' && _cityIds.containsKey(city)) {
        queryParams['city_ids'] = _cityIds[city].toString();
      }

      final uri = Uri.parse('$_baseUrl/events').replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: {'X-Etkinlik-Token': _apiToken},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> items = data['items'] ?? [];
        
        final List<Map<String, dynamic>> processedEvents = items.where((item) {
          final eventCity = item['venue']?['city']?['name']?.toString().toLowerCase() ?? '';
          final targetCity = city.toLowerCase();
          final bool cityMatches = eventCity.contains(targetCity) || targetCity.contains(eventCity);
          
          if (!cityMatches) return false;

          // Bugünü ve geçmişi filtrele
          final DateTime? eventDate = DateTime.tryParse(item['start'] ?? '');
          if (eventDate == null) return false;
          
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          
          // Sadece bugünden sonraki (yarın ve sonrası) etkinlikleri al
          return eventDate.isAfter(today.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)));
        }).map((item) {
          // Resim URL'sini bulmak için tüm ihtimalleri tara
          String? apiImageUrl;
          
          if (item['poster'] != null) {
            if (item['poster'] is String) {
              apiImageUrl = item['poster'];
            } else if (item['poster'] is Map) {
              // Daha düşük boyutlu resimleri tercih et (Hız için)
              apiImageUrl = item['poster']['large'] ?? item['poster']['url'] ?? item['poster']['original'];
            }
          }
          
          // Yedek alanları kontrol et
          apiImageUrl ??= item['poster_url']?.toString() ?? item['image']?.toString();
          
          return {
            'externalId': item['id']?.toString() ?? '',
            'title': item['name'] ?? 'Başlıksız Etkinlik',
            'description': _cleanHtml(item['content'] ?? 'Detaylı bilgi bulunmuyor.'),
            'location': item['venue']?['name'] ?? city,
            'address': item['venue']?['address'] ?? '',
            'latitude': double.tryParse(item['venue']?['lat']?.toString() ?? ''),
            'longitude': double.tryParse(item['venue']?['lng']?.toString() ?? ''),
            'city': city,
            'date': DateTime.tryParse(item['start'] ?? '') ?? DateTime.now(),
            'category': _mapToInternalCategory(item['category']?['name'] ?? ''),
            'imageUrl': (apiImageUrl != null && apiImageUrl.isNotEmpty) 
                ? apiImageUrl 
                : _getFallbackImage(item['category']?['name'] ?? ''),
            'link': item['url'] ?? '',
            'source': 'Etkinlik.io',
            'externalSource': true,
          };
        }).toList();

        return processedEvents;
      }
      return [];
    } catch (e) {
      debugPrint("fetchEvents hatası: $e");
      return [];
    }
  }

  static Future<void> scrapeAndSaveEvents({required String city, int limit = 10}) async {
    List<Map<String, dynamic>> events = await fetchEvents(city);
    
    // Eğer bir limit varsa, rastgele günlerden seçmek için listeyi karıştır
    if (limit < events.length) {
      events.shuffle();
    }

    final db = FirebaseFirestore.instance;
    
    int saved = 0;
    for (var event in events) {
      if (saved >= limit) break;
      
      // 1. Check by External ID (The most reliable for API)
      if (event['externalId'].isNotEmpty) {
        final existingById = await db.collection('events').where('externalId', isEqualTo: event['externalId']).get();
        if (existingById.docs.isNotEmpty) continue;
      }

      // 2. Check by link
      if (event['link'].isNotEmpty) {
        final existingByLink = await db.collection('events').where('link', isEqualTo: event['link']).get();
        if (existingByLink.docs.isNotEmpty) continue;
      }

      // 3. Check by Title + City + Date (Catch manual duplicates or same event with different link)
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
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  static Future<void> scrapeFiveFromSelectedCities(List<String> selectedCities) async {
    for (String city in selectedCities) {
      await scrapeAndSaveEvents(city: city, limit: 5);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  static Future<Map<String, dynamic>> fetchFullEventDetails(String link) async {
    // Since we don't have a specific API for full details by link alone, 
    // and scraping HTML is fragile, we try to find it in the search results if possible,
    // or just return empty for now as requested.
    // In a real scenario, this would call the API's specific event endpoint if ID was known.
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
