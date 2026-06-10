import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;
  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _pickedLocation;
  GoogleMapController? _mapController;
  bool _isLoading = true;
  bool _isSearching = false;
  LatLng _initialCameraPosition = const LatLng(41.0082, 28.9784); // Varsayılan: İstanbul
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupInitialLocation();
  }

  Future<void> _setupInitialLocation() async {
    if (widget.initialLocation != null) {
      setState(() {
        _pickedLocation = widget.initialLocation;
        _initialCameraPosition = widget.initialLocation!;
        _isLoading = false;
      });
      return;
    }

    try {
      Position? lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        setState(() {
          _initialCameraPosition = LatLng(lastPos.latitude, lastPos.longitude);
        });
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      setState(() {
        _initialCameraPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });
      
      _mapController?.animateCamera(CameraUpdate.newLatLng(_initialCameraPosition));

    } catch (e) {
      debugPrint("Konum alınamadı: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchPlace() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        
        setState(() {
          _pickedLocation = target;
          _isSearching = false;
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 16),
          ),
        );
      }
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum bulunamadı. Lütfen daha spesifik bir adres deneyin.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Seç', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _initialCameraPosition,
              zoom: 15,
            ),
            onMapCreated: (controller) => _mapController = controller,
            onTap: (position) {
              setState(() => _pickedLocation = position);
            },
            markers: _pickedLocation == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('picked'),
                      position: _pickedLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                    ),
                  },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            zoomControlsEnabled: false,
          ),
          
          // Arama Çubuğu
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Mekan veya adres ara...',
                  prefixIcon: const Icon(Icons.search, color: Colors.orange),
                  suffixIcon: _isSearching 
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _searchPlace,
                      ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
                onSubmitted: (_) => _searchPlace(),
              ),
            ),
          ),

          if (_pickedLocation == null)
            Positioned(
              bottom: 100,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Haritaya dokunun veya üstten arama yapın.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.orange)),
        ],
      ),
      floatingActionButton: _pickedLocation != null
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pop(_pickedLocation),
              label: const Text('Konumu Onayla', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              icon: const Icon(Icons.check, color: Colors.white),
              backgroundColor: Colors.orange,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
