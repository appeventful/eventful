import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'create_event_screen.dart';
import 'external_event_detail_screen.dart';
import '../services/event_scraper_service.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';
import '../widgets/shimmer_effect.dart';
import '../utils/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CityEventsTab extends StatefulWidget {
  const CityEventsTab({super.key});

  @override
  State<CityEventsTab> createState() => _CityEventsTabState();
}

class _CityEventsTabState extends State<CityEventsTab> {
  String _selectedCity = 'İstanbul';
  List<Map<String, dynamic>> _externalEvents = [];
  bool _isLoading = true;
  bool _isLocating = true;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndEvents();
  }

  Future<void> _initializeLocationAndEvents() async {
    await _determinePosition();
    if (mounted) {
      await _fetchEvents();
    }
  }

  Future<void> _determinePosition() async {
    if (!mounted) return;
    setState(() => _isLocating = true);
    
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
        );
        
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          String? city = placemarks.first.administrativeArea;
          if (city != null) {
            String normalizedCity = cities.firstWhere(
              (c) => city.toLowerCase().contains(c.toLowerCase()) || c.toLowerCase().contains(city.toLowerCase()),
              orElse: () => _selectedCity,
            );
            setState(() {
              _selectedCity = normalizedCity;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Konum alma hatası: $e");
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _fetchEvents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final events = await EventScraperService.fetchEvents(_selectedCity);
      if (mounted) {
        setState(() {
          _externalEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Etkinlik getirme hatası: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Şehrin Etkinlikleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  'Canlı Güncelleniyor • ${DateFormat('HH:mm').format(DateTime.now())}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
        elevation: 0,
        actions: [
          if (_isLocating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            DropdownButton<String>(
              value: _selectedCity,
              underline: const SizedBox(),
              items: cities.map((city) {
                return DropdownMenuItem(value: city, child: Text(city));
              }).toList(),
            onChanged: (val) {
              if (val != null && mounted) {
                setState(() => _selectedCity = val);
                _fetchEvents();
              }
            },
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: _fetchEvents,
              child: _externalEvents.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Bu şehirde şu an etkinlik bulunamadı.', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _externalEvents.length,
                    itemBuilder: (context, index) {
                      final event = _externalEvents[index];
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ExternalEventDetailScreen(event: event)),
                        ),
                        child: _buildExternalEventCard(event),
                      );
                    },
                  ),
            ),
    );
  }

  Widget _buildExternalEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Hero(
                  tag: 'event_image_${event['link']}',
                  child: CachedNetworkImage(
                    imageUrl: event['imageUrl'],
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheHeight: 600,
                    maxWidthDiskCache: 1000,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const ShimmerEffect(
                        child: Center(
                          child: Icon(Icons.image, color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.orange.shade50,
                      child: const Icon(Icons.image, size: 50, color: Colors.orange),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    event['category'],
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AuthService().isGuest 
                    ? 'Görmek için üye ol' 
                    : DateFormat('dd MMMM yyyy • HH:mm', 'tr_TR').format(event['date']),
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  event['title'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.2),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event['locationName'] ?? event['address'] ?? 'Konum Belirtilmedi',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CreateEventButton(event: event),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateEventButton extends StatefulWidget {
  final Map<String, dynamic> event;
  const _CreateEventButton({required this.event});

  @override
  State<_CreateEventButton> createState() => _CreateEventButtonState();
}

class _CreateEventButtonState extends State<_CreateEventButton> {
  bool _isEnriching = false;

  Future<void> _handleCreateEvent() async {
    if (AuthService().isGuest) {
      GuestGuardDialog.show(context, "Etkinlik oluşturma");
      return;
    }

    setState(() => _isEnriching = true);
    try {
      final enrichedData = await EventScraperService.fetchFullEventDetails(widget.event['link']);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateEventScreen(
              prefillData: {
                ...widget.event,
                'description': enrichedData['description']?.isNotEmpty == true 
                    ? enrichedData['description'] 
                    : widget.event['description'],
                'latitude': widget.event['latitude'],
                'longitude': widget.event['longitude'],
                'address': widget.event['address'],
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu.')));
      }
    } finally {
      if (mounted) setState(() => _isEnriching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton.icon(
        onPressed: _isEnriching ? null : _handleCreateEvent,
        icon: _isEnriching 
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.event_available, size: 18),
        label: Text(_isEnriching ? 'Bekleyin...' : 'Bunun için Etkinlik Oluştur'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
