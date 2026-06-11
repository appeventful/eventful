import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/event_model.dart';
import '../../utils/platform_helper.dart';
import '../../services/score_service.dart';
import '../../utils/city_centers.dart';
import '../shimmer_effect.dart';
import '../event_card.dart';
import '../../screens/create_event_screen.dart';
import 'trending_section.dart';

class DiscoverTab extends StatefulWidget {
  final ScrollController? scrollController;
  const DiscoverTab({super.key, this.scrollController});

  @override
  State<DiscoverTab> createState() => DiscoverTabState();
}

class DiscoverTabState extends State<DiscoverTab> {
  final ScoreService _scoreService = ScoreService.instance;
  String _selectedCategory = 'Tümü';
  String _selectedCity = 'İstanbul';
  bool _isLocating = false;
  Position? _currentPosition;
  late Stream<QuerySnapshot> _eventsStream;

  final List<String> _categories = [
    'Tümü', 'Buluşma', 'Sohbet', 'Konser', 'Oyun', 'Kamp', 'Yürüyüş', 'Spor', 'Teknoloji', 'Eğitim', 'Diğer'
  ];

  final List<String> _cities = [
    'Adana', 'Adıyaman', 'Afyonkarahisar', 'Ağrı', 'Amasya', 'Ankara', 'Antalya', 'Artvin', 'Aydın', 'Balıkesir', 'Bilecik', 'Bingöl', 'Bitlis', 'Bolu', 'Burdur', 'Bursa', 'Çanakkale', 'Çankırı', 'Çorum', 'Denizli', 'Diyarbakır', 'Edirne', 'Elazığ', 'Erzincan', 'Erzurum', 'Eskişehir', 'Gaziantep', 'Giresun', 'Gümüşhane', 'Hakkari', 'Hatay', 'Isparta', 'Mersin', 'İstanbul', 'İzmir', 'Kars', 'Kastamonu', 'Kayseri', 'Kırklareli', 'Kırşehir', 'Kocaeli', 'Konya', 'Kütahya', 'Malatya', 'Manisa', 'Kahramanmaraş', 'Mardin', 'Muğla', 'Muş', 'Nevşehir', 'Niğde', 'Ordu', 'Rize', 'Sakarya', 'Samsun', 'Siirt', 'Sinop', 'Sivas', 'Tekirdağ', 'Tokat', 'Trabzon', 'Tunceli', 'Şanlıurfa', 'Uşak', 'Van', 'Yozgat', 'Zonguldak', 'Aksaray', 'Bayburt', 'Karaman', 'Kırıkkale', 'Batman', 'Şırnak', 'Bartın', 'Ardahan', 'Iğdır', 'Yalova', 'Karabük', 'Kilis', 'Osmaniye', 'Düzce'
  ];

  @override
  void initState() {
    super.initState();
    _cities.sort(); 
    _initStream();
    _autoLocate().then((_) {
      if (_selectedCity == 'İstanbul') {
        _checkUserCityPreference();
      }
    });
  }

  void _initStream() {
    _eventsStream = FirebaseFirestore.instance.collection('events')
        .where('isArchived', isEqualTo: false)
        .where('isApproved', isEqualTo: true)
        .where('city', isEqualTo: _selectedCity)
        .snapshots();
  }

  void _checkUserCityPreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      if (userDoc.exists) {
        final userData = userDoc.data();
        String? preferredCity = userData?['preferredCity'];
        if (preferredCity != null && _cities.contains(preferredCity)) {
          setState(() {
            _selectedCity = preferredCity;
            _initStream();
          });
        } else {
          _autoLocate();
        }
      }
    }
  }

  Future<void> _autoLocate() async {
    if (!mounted) return;
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
        if (!mounted) return;
        setState(() => _currentPosition = position);
        
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (!mounted) return;

        if (placemarks.isNotEmpty) {
          String? city = placemarks.first.administrativeArea;
          if (city != null) {
            String normalizedCity = _cities.firstWhere(
              (c) => city.toLowerCase().contains(c.toLowerCase()) || c.toLowerCase().contains(city.toLowerCase()),
              orElse: () => _selectedCity,
            );
            if (mounted) {
              setState(() {
                _selectedCity = normalizedCity;
                _initStream();
              });
              _updateUserCityPreference(normalizedCity);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _updateUserCityPreference(String city) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'preferredCity': city,
      });
    }
  }

  void _showCitySelectionDialog() {
    String? tempCity = _selectedCity;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şehrinizi Seçin', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Size en yakın etkinlikleri göstermek için lütfen şehrinizi seçin.'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setDialogState) => DropdownButtonFormField<String>(
                value: tempCity,
                decoration: InputDecoration(
                  labelText: 'Şehir',
                  prefixIcon: const Icon(Icons.location_city),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _cities.map((String city) {
                  return DropdownMenuItem(value: city, child: Text(city));
                }).toList(),
                onChanged: (val) => setDialogState(() => tempCity = val),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (tempCity != null) {
                setState(() {
                  _selectedCity = tempCity!;
                  _initStream();
                });
                _updateUserCityPreference(tempCity!);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.event_busy, size: 80, color: Colors.orange.shade300),
              ),
              const SizedBox(height: 24),
              const Text(
                'Şehrinde henüz etkinlik yok!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'İlk kıvılcımı sen çakmak ve harika bir buluşma başlatmak ister misin?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateEventScreen()),
                  ).then((_) => refresh());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: Colors.orange.withValues(alpha: 0.4),
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Hemen Etkinlik Oluştur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    return ShimmerEffect(
      child: ListView(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSkeletonBox(height: 30, width: 150),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                width: 300,
                margin: const EdgeInsets.only(right: 12),
                child: _buildSkeletonBox(height: 240, width: 300, radius: 24),
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSkeletonBox(height: 30, width: 180),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildSkeletonBox(height: 120, width: double.infinity, radius: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({required double height, required double width, double radius = 12}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildLaunchBanner() {
    DateTime now = DateTime.now();
    DateTime deadline = DateTime(2025, 5, 31, 23, 59, 59);
    if (now.isAfter(deadline)) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade700, Colors.orange.shade400]),
        boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '31 Mayıs\'a kadar kayıt ol, "Kurucu" rozetini kap!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstagramFollowBanner() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final bool isFollowed = userData?['isInstagramFollowed'] ?? false;
        final bool isGod = FirebaseAuth.instance.currentUser?.email == 'fatihkull17@gmail.com';

        if (isFollowed && !isGod) return const SizedBox.shrink();

        return RepaintBoundary(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleInstagramFollow(uid),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bizi Instagram\'da Takip Et!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                            ),
                            Text(
                              'Takip et ve 50 Puan kazan.',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Takip Et',
                          style: TextStyle(color: Color(0xFFFD1D1D), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleInstagramFollow(String uid) async {
    final url = Uri.parse("https://www.instagram.com/eventfulapptr/");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        
        await _scoreService.updateScore(
          userId: uid,
          amount: ScoreService.instagramFollowReward,
          reason: 'Instagram Takip Ödülü (@eventfulapptr)',
          relatedId: 'instagram_follow_official',
        );

        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isInstagramFollowed': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tebrikler! 50 Puan kazandınız. ✨'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Instagram launch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final userModel = userProvider.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List blockedUsers = userModel?.blockedUsers ?? [];
    List<String> userInterests = userModel != null ? List<String>.from(userModel.notificationSettings.keys) : [];

    return Column(
      children: [
        RepaintBoundary(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _showCitySelectionDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text(_selectedCity, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Spacer(),
                                if (_isLocating)
                                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                else
                                  const Icon(Icons.arrow_drop_down, color: Colors.orange),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location, color: Colors.orange, size: 20),
                        onPressed: _autoLocate,
                        tooltip: "Konumu Algıla",
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 50,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      String cat = _categories[index];
                      bool isSelected = _selectedCategory == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          onSelected: (val) {
                            PlatformHelper.hapticFeedback();
                            setState(() => _selectedCategory = cat);
                          },
                          selectedColor: Colors.orange,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildLaunchBanner(),
        _buildInstagramFollowBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              refresh();
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: StreamBuilder<QuerySnapshot>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("Firestore Error: ${snapshot.error}");
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          const Text(
                            'Bir filtreleme hatası oluştu.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bu filtre kombinasyonu için bir dizin oluşturuluyor olabilir.\n\nHata: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'Tümü';
                                _initStream();
                              });
                            },
                            child: const Text('Filtreleri Sıfırla'),
                          )
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) return _buildSkeletonLoading();
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState(context);
                }

                final now = DateTime.now();

                final Map<String, Map<String, dynamic>> processedData = {};
                final Map<String, double> distances = {};
                
                final snapshotDocs = snapshot.data!.docs;
                
                for (var doc in snapshotDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final id = doc.id;
                  
                  var eventDateData = data['eventDate'] ?? data['date'];
                  DateTime eventDate;
                  if (eventDateData is Timestamp) {
                    eventDate = eventDateData.toDate();
                  } else if (eventDateData is String) {
                    eventDate = DateTime.tryParse(eventDateData) ?? DateTime.now();
                  } else {
                    eventDate = DateTime.now();
                  }
                  
                  processedData[id] = {
                    'isPinned': data['isPinned'] == true,
                    'eventDate': eventDate,
                    'category': data['category'] ?? 'Diğer',
                    'creatorId': data['creatorId']?.toString() ?? '',
                    'isArchived': data['isArchived'] == true,
                    'trendingScore': (data['trendingScore'] ?? 0.0).toDouble(),
                  };

                  if (_currentPosition != null) {
                    double? lat = data['latitude']?.toDouble();
                    double? lng = data['longitude']?.toDouble();

                    if (lat == null || lng == null) {
                      String city = (data['city'] ?? 'İstanbul').toString().trim();
                      final center = cityCenters[city];
                      if (center != null) {
                        lat = center['lat'];
                        lng = center['lng'];
                      }
                    }

                    if (lat != null && lng != null) {
                      distances[id] = Geolocator.distanceBetween(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                        lat,
                        lng,
                      );
                    } else {
                      distances[id] = double.maxFinite;
                    }
                  }
                }
                
                final filteredDocs = snapshotDocs.where((doc) {
                  final id = doc.id;
                  final meta = processedData[id]!;
                  
                  if (blockedUsers.contains(meta['creatorId'])) return false;
                  if (meta['isArchived']) return false;
                  if (_selectedCategory != 'Tümü' && meta['category'] != _selectedCategory) return false;
                  
                  // Etkinlik başladıktan 3 saat sonrasına kadar listede kalmaya devam etsin
                  if (meta['eventDate'].add(const Duration(hours: 3)).isBefore(now)) {
                    return false;
                  }

                  return true;
                }).toList();

                filteredDocs.sort((a, b) {
                  final aMeta = processedData[a.id]!;
                  final bMeta = processedData[b.id]!;
                  
                  if (aMeta['isPinned'] != bMeta['isPinned']) {
                    return (aMeta['isPinned'] as bool) ? -1 : 1; 
                  }

                  if (_currentPosition != null) {
                    double distA = distances[a.id] ?? double.maxFinite;
                    double distB = distances[b.id] ?? double.maxFinite;
                    
                    if ((distA - distB).abs() > 1000) {
                      return distA.compareTo(distB);
                    }
                  }

                  return (aMeta['eventDate'] as DateTime).compareTo(bMeta['eventDate'] as DateTime);
                });

                if (filteredDocs.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filteredDocs.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return TrendingSection(
                        docs: filteredDocs, 
                        userInterests: userInterests,
                        processedData: processedData,
                      );
                    }
                    final event = EventModel.fromFirestore(filteredDocs[index - 1]);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: EventCard(event: event),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
