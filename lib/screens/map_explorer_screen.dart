import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/event_model.dart';
import '../utils/image_constants.dart';
import 'event_detail_screen.dart';

class MapExplorerScreen extends StatefulWidget {
  const MapExplorerScreen({super.key});

  @override
  State<MapExplorerScreen> createState() => _MapExplorerScreenState();
}

class _MapExplorerScreenState extends State<MapExplorerScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  double _radiusKm = 15.0;
  Set<Marker> _markers = {};
  List<EventModel> _events = [];
  bool _isLoading = true;
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
          _loadEvents();
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEvents() async {
    if (_currentPosition == null) return;
    if (mounted) setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .where('isArchived', isEqualTo: false)
          .where('isApproved', isEqualTo: true)
          .get();

      final List<EventModel> allEvents = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc))
          .where((e) => e.latitude != null && e.longitude != null)
          .toList();

      _filterEvents(allEvents);
    } catch (e) {
      debugPrint("Error loading events: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterEvents(List<EventModel> allEvents) {
    if (_currentPosition == null) return;

    final filtered = allEvents.where((event) {
      double distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        event.latitude!,
        event.longitude!,
      );
      return distance <= _radiusKm * 1000;
    }).toList();

    // Mesafeye göre sırala (En yakın en başta)
    filtered.sort((a, b) {
      double distA = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, a.latitude!, a.longitude!);
      double distB = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });

    final markers = filtered.asMap().entries.map((entry) {
      int idx = entry.key;
      EventModel event = entry.value;
      return Marker(
        markerId: MarkerId(event.id),
        position: LatLng(event.latitude!, event.longitude!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        onTap: () {
          _pageController.animateToPage(
            idx,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        infoWindow: InfoWindow(
          title: event.title,
          snippet: event.category,
        ),
      );
    }).toSet();

    if (mounted) {
      setState(() {
        _events = filtered;
        _markers = markers;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    final event = _events[index];
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(event.latitude!, event.longitude!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Etkinlik Haritası', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(230), // ~0.9 alpha
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildMap(),
          _buildTopControls(),
          _buildEventCarousel(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildMap() {
    // Fallback: İstanbul koordinatları
    final LatLng defaultLocation = const LatLng(41.0082, 28.9784);
    
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: _currentPosition != null 
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : defaultLocation,
        zoom: 12,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        // Eğer konum geldiyse oraya odaklan
        if (_currentPosition != null) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 12),
          );
        }
      },
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      mapType: MapType.normal, // Açıkça belirtelim
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'mylocation',
            onPressed: () {
              if (_currentPosition != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 14),
                );
              }
            },
            backgroundColor: Theme.of(context).cardColor,
            child: const Icon(Icons.my_location, color: Colors.orange),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(26), blurRadius: 10)],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.radar, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Mesafe: ${_radiusKm.toInt()} km',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: _radiusKm,
                      min: 1,
                      max: 100,
                      activeColor: Colors.orange,
                      onChanged: (val) => setState(() => _radiusKm = val),
                      onChangeEnd: (val) => _loadEvents(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCarousel() {
    if (_events.isEmpty && !_isLoading) {
      return Positioned(
        bottom: 40,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              'Bu mesafede etkinlik bulunamadı.',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      height: 160,
      child: PageView.builder(
        controller: _pageController,
        itemCount: _events.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final event = _events[index];
          return AnimatedScale(
            scale: _currentPage == index ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 300),
            child: _buildEventCard(event),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EventDetailScreen(eventId: event.id)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(26),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: CachedNetworkImage(
                imageUrl: event.imageUrl.isNotEmpty ? event.imageUrl : ImageConstants.defaultEventImage,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(color: Colors.orange.withAlpha(51), child: const Icon(Icons.image)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.category,
                      style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, event.latitude!, event.longitude!) / 1000).toStringAsFixed(1)} km uzakta',
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );
  }
}
