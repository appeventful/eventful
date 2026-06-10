class ImageConstants {
  static const String defaultEventImage = 'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=800';

  static String getUnsplashUrl(String query) {
    final cleanQuery = Uri.encodeComponent(query.replaceAll(' ', ','));
    return 'https://source.unsplash.com/featured/800x600/?$cleanQuery';
  }

  static String getDynamicResim(String baslik, {String? extra}) {
    final combined = '$baslik ${extra ?? ''}'.trim();
    final query = Uri.encodeComponent(combined);
    return 'https://source.unsplash.com/featured/800x600/?$query';
  }

  static String getFeaturedImage(String query) {
    final encodedQuery = Uri.encodeComponent(query);
    return 'https://source.unsplash.com/featured/1200x800/?$encodedQuery';
  }

  static const Map<String, List<String>> categoryStockImages = {
    'Buluşma': [
      'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=800',
      'https://images.unsplash.com/photo-1523240715639-99f846716100?w=800',
      'https://images.unsplash.com/photo-1521791136064-7986c2920216?w=800',
    ],
    'Sohbet': [
      'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800',
      'https://images.unsplash.com/photo-1543269865-cbf427effbad?w=800',
      'https://images.unsplash.com/photo-1517048676732-d65bc937f952?w=800',
    ],
    'Konser': [
      'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?w=800',
      'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800',
      'https://images.unsplash.com/photo-1459749411177-042180ce673c?w=800',
    ],
    'Oyun': [
      'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=800',
      'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=800',
      'https://images.unsplash.com/photo-1612287230202-1ff1d85d1bdf?w=800',
    ],
    'Kamp': [
      'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800',
      'https://images.unsplash.com/photo-1523987355523-c7b5b0dd90a7?w=800',
      'https://images.unsplash.com/photo-1478131143081-80f7f84ca84c?w=800',
    ],
    'Yürüyüş': [
      'https://images.unsplash.com/photo-1551632432-c735e8306e91?w=800',
      'https://images.unsplash.com/photo-1501555088652-021faa106b9b?w=800',
      'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800',
    ],
    'Spor': [
      'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=800',
      'https://images.unsplash.com/photo-1461896836934-ffe607ba8211?w=800',
      'https://images.unsplash.com/photo-1526676023601-d758c976aa61?w=800',
    ],
    'Teknoloji': [
      'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800',
      'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=800',
      'https://images.unsplash.com/photo-1519389950473-47ba0277781c?w=800',
    ],
    'Eğitim': [
      'https://images.unsplash.com/photo-1524178232363-1fb2b075b655?w=800',
      'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=800',
      'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=800',
    ],
    'Genel': [
      'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=800',
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800',
      'https://images.unsplash.com/photo-1514525253361-bee87187030c?w=800',
    ],
    'Diğer': [
      'https://images.unsplash.com/photo-1505373877841-8d25f7d46678?w=800',
      'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800',
      'https://images.unsplash.com/photo-1514525253361-bee87187030c?w=800',
    ],
  };

  static const Map<String, List<String>> keywordImages = {
    'kahve': ['https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800'],
    'yemek': ['https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800'],
    'kitap': ['https://images.unsplash.com/photo-1495446815901-a7297e633e8d?w=800'],
    'müzik': ['https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800'],
    'sinema': ['https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800'],
    'doğa': ['https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800'],
    'kod': ['https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800'],
    'yazılım': ['https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800'],
    'parti': ['https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=800'],
    'gezi': ['https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=800'],
  };
}
