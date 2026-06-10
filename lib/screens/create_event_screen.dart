import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_picker_screen.dart';
import '../utils/constants.dart';
import '../utils/image_helper.dart';
import '../services/score_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../widgets/guest_guard_dialog.dart';

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? prefillData;
  const CreateEventScreen({super.key, this.prefillData});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  final _quotaController = TextEditingController(text: '0');
  final _requirementsController = TextEditingController();
  final ScoreService _scoreService = ScoreService();
  final StorageService _storageService = StorageService();
  
  File? _selectedImageFile;
  String? _prefilledImageUrl;
  bool _isCheckingRestriction = true;
  bool _isRestricted = false;
  bool _isLoading = false;
  bool _isApprovalRequired = false;
  bool _isLocating = false;
  String _selectedCategory = categories.first;
  String _selectedCity = 'İstanbul';

  final List<String> _categories = List.from(categories);
  final List<String> _cities = List.from(cities);
  
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with prefill data if available
    _titleController = TextEditingController(text: widget.prefillData?['title'] ?? '');
    _descController = TextEditingController(text: widget.prefillData?['description'] ?? '');
    _addressController = TextEditingController(text: widget.prefillData?['location'] ?? '');
    _prefilledImageUrl = widget.prefillData?['imageUrl'];

    if (widget.prefillData != null) {
      if (widget.prefillData!['latitude'] != null && widget.prefillData!['longitude'] != null) {
        _selectedLocation = LatLng(
          widget.prefillData!['latitude'] is String ? double.parse(widget.prefillData!['latitude']) : widget.prefillData!['latitude'],
          widget.prefillData!['longitude'] is String ? double.parse(widget.prefillData!['longitude']) : widget.prefillData!['longitude']
        );
      }
      if (widget.prefillData!['city'] != null) {
        _selectedCity = widget.prefillData!['city'];
      }
      if (widget.prefillData!['category'] != null) {
        // Try to match category
        String cat = widget.prefillData!['category'];
        if (_categories.contains(cat)) {
          _selectedCategory = cat;
        } else if (cat.contains('Müzik') || cat.contains('Konser')) {
          _selectedCategory = 'Konser';
        }
      }
      if (widget.prefillData!['date'] is DateTime) {
        DateTime date = widget.prefillData!['date'];
        _selectedDate = date;
        _selectedTime = TimeOfDay.fromDateTime(date);
      }
    }

    _checkRestriction();
    
    // Sort cities for dropdown
    _cities.sort();
    
    // Ensure _selectedCity and _selectedCategory are valid values from lists
    if (!_cities.contains(_selectedCity)) {
      _selectedCity = _cities.contains('İstanbul') ? 'İstanbul' : _cities.first;
    }
    if (!_categories.contains(_selectedCategory)) {
      _selectedCategory = _categories.first;
    }

    _initializeCity();
  }

  Future<void> _initializeCity() async {
    // 1. Try Auto-locate
    await _autoLocate();
    
    // 2. If still default and not prefilled, try user preference
    if (_selectedCity == 'İstanbul' && (widget.prefillData == null || widget.prefillData!['city'] == null)) {
      await _checkUserCityPreference();
    }
  }

  Future<void> _checkUserCityPreference() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists && mounted) {
          final userData = userDoc.data();
          String? preferredCity = userData?['preferredCity'];
          if (preferredCity != null && _cities.contains(preferredCity)) {
            setState(() => _selectedCity = preferredCity);
          }
        }
      } catch (e) {
        debugPrint("Tercih edilen şehir alınamadı: $e");
      }
    }
  }

  Future<void> _autoLocate() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    
    try {
      // 1. Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum servisleri kapalı. Lütfen konumu açın.'))
          );
        }
        return;
      }

      // 2. Check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni kalıcı olarak reddedildi.'))
          );
        }
        return;
      }

      // 3. Get current position with timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
      
      // 4. Reverse geocode to find city
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, position.longitude,
      );

      if (placemarks.isNotEmpty && mounted) {
        String? city = placemarks.first.administrativeArea ?? placemarks.first.locality;
        if (city != null) {
          String normalizedCity = _cities.firstWhere(
            (c) => city.toLowerCase().contains(c.toLowerCase()) || 
                   c.toLowerCase().contains(city.toLowerCase()),
            orElse: () => _selectedCity,
          );
          setState(() => _selectedCity = normalizedCity);
        }
      }
    } catch (e) {
      debugPrint("Konum alma hatası: $e");
      if (mounted && e is! TimeoutException) {
         // Silently fail or show brief info
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openMapPicker() async {
    final LatLng? picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedLocation = picked;
      });
      
      // Koordinatlardan adres çözümleme (Reverse Geocoding)
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          picked.latitude, picked.longitude
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          
          // Daha temiz bir adres oluşturma
          List<String> addressParts = [];
          if (p.street != null && p.street!.isNotEmpty && !p.street!.contains('Unnamed')) {
            addressParts.add(p.street!);
          }
          if (p.subLocality != null && p.subLocality!.isNotEmpty) {
            addressParts.add(p.subLocality!);
          }
          if (p.locality != null && p.locality!.isNotEmpty) {
            addressParts.add(p.locality!);
          }
          
          String formattedAddress = addressParts.join(', ');
          
          if (mounted) {
            setState(() {
              if (formattedAddress.isNotEmpty) {
                _addressController.text = formattedAddress;
              }
              
              // Şehri de güncellemeye çalış (administrativeArea genelde il bilgisini tutar)
              String? city = p.administrativeArea;
              if (city != null) {
                String normalizedCity = _cities.firstWhere(
                  (c) => city.toLowerCase().contains(c.toLowerCase()) || 
                         c.toLowerCase().contains(city.toLowerCase()),
                  orElse: () => _selectedCity,
                );
                _selectedCity = normalizedCity;
              }
            });
          }
        }
      } catch (e) {
        debugPrint("Reverse geocoding error: $e");
      }
    }
  }

  Future<void> _checkRestriction() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        bool canCreate = await _scoreService.canCreateEvent(user.uid).timeout(
          const Duration(seconds: 5),
          onTimeout: () => true,
        );
        if (mounted) {
          setState(() {
            _isRestricted = !canCreate;
            _isCheckingRestriction = false;
          });
        }
      } else {
        if (mounted) setState(() => _isCheckingRestriction = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingRestriction = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      if (context.mounted) _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateText = _selectedDate == null ? 'Tarih Seç' : DateFormat('dd.MM.yyyy').format(_selectedDate!);
    String timeText = _selectedTime == null ? 'Saat Seç' : _selectedTime!.format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinlik Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isCheckingRestriction
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : _isRestricted
              ? _buildRestrictedUI()
              : _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Colors.orange))
                  : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resim Seçme / Önizleme Alanı
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.orange.withOpacity(0.2), width: 2),
                        image: _selectedImageFile != null 
                          ? DecorationImage(image: FileImage(_selectedImageFile!), fit: BoxFit.cover)
                          : (_prefilledImageUrl != null 
                              ? DecorationImage(image: NetworkImage(_prefilledImageUrl!), fit: BoxFit.cover)
                              : null),
                      ),
                      child: _selectedImageFile == null && _prefilledImageUrl == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 40, color: Colors.orange.shade300),
                              const SizedBox(height: 10),
                              const Text(
                                'Kapak Fotoğrafı Ekle',
                                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                              const Text(
                                '(İsteğe bağlı, seçmezseniz otomatik atanır)',
                                style: TextStyle(color: Colors.grey, fontSize: 10),
                              ),
                            ],
                          )
                        : Container(
                            alignment: Alignment.topRight,
                            padding: const EdgeInsets.all(8),
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => setState(() {
                                  _selectedImageFile = null;
                                  _prefilledImageUrl = null;
                                }),
                              ),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Etkinlik Başlığı',
                      prefixIcon: const Icon(Icons.title),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val!.isEmpty ? 'Başlık gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Etkinlik Açıklaması',
                      prefixIcon: const Icon(Icons.description_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val!.isEmpty ? 'Açıklama gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // Şehir Seçimi
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'Şehir',
                      prefixIcon: _isLocating 
                        ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                        : const Icon(Icons.location_city),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location, size: 20),
                        onPressed: _isLocating ? null : _autoLocate,
                        tooltip: "Konumu Algıla",
                      ),
                    ),
                    items: _cities.map((String city) {
                      return DropdownMenuItem(value: city, child: Text(city));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCity = val!),
                  ),
                  const SizedBox(height: 16),

                  // Açık Adres
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Adres / Mekan Adı',
                      hintText: 'Örn: Beşiktaş Meydanı, Maçka Parkı...',
                      prefixIcon: const Icon(Icons.map_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _selectedLocation == null ? Colors.orange.shade200 : Colors.green,
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _selectedLocation == null ? Icons.location_searching : Icons.check_circle,
                          color: _selectedLocation == null ? Colors.orange : Colors.green,
                        ),
                        onPressed: _openMapPicker,
                        tooltip: "Haritadan Seç",
                      ),
                    ),
                    validator: (val) => val!.isEmpty ? 'Adres gerekli' : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                    child: Text(
                      _selectedLocation == null 
                          ? '⚠️ Haritadan konum seçilmesi önerilir (Haritada görünmesi için).' 
                          : '✅ Konum başarıyla işaretlendi.',
                      style: TextStyle(
                        fontSize: 11, 
                        color: _selectedLocation == null ? Colors.orange.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _categories.map((String category) {
                      return DropdownMenuItem(value: category, child: Text(category));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val!),
                  ),
                  const SizedBox(height: 16),

                  // Kontenjan ve Şartlar
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _quotaController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Kontenjan',
                            hintText: '0: Sınırsız',
                            prefixIcon: const Icon(Icons.people_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _requirementsController,
                          decoration: InputDecoration(
                            labelText: 'Katılım Şartı',
                            hintText: 'Örn: Öğrenci olmak',
                            prefixIcon: const Icon(Icons.rule),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectDate(context),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(_selectedDate == null ? 'Tarih Seç' : DateFormat('dd.MM.yyyy', 'tr_TR').format(_selectedDate!)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _selectTime(context),
                          icon: const Icon(Icons.access_time),
                          label: Text(_selectedTime == null ? 'Saat Seç' : _selectedTime!.format(context)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Onay Gerekli', style: TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: const Text('Katılımcılar onayınızı beklemelidir.'),
                    value: _isApprovalRequired,
                    onChanged: (val) => setState(() => _isApprovalRequired = val),
                    activeThumbColor: Colors.orange,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submitEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Etkinliği Yayınla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildRestrictedUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            const Text('Hesap Kısıtlandı', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Bu ay çok fazla devamsızlık yaptığınız için yeni etkinlik oluşturamazsınız.', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Geri Dön'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Galeriden Seç"),
              onTap: () async {
                Navigator.pop(context);
                final file = await _storageService.pickImage(ImageSource.gallery);
                if (file != null) setState(() => _selectedImageFile = file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Kamera ile Çek"),
              onTap: () async {
                Navigator.pop(context);
                final file = await _storageService.pickImage(ImageSource.camera);
                if (file != null) setState(() => _selectedImageFile = file);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tarih ve saat seçin.'))
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (AuthService().isGuest) {
        setState(() => _isLoading = false);
        GuestGuardDialog.show(context, "Etkinlik oluşturma");
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Oturum açık değil.");
      
      final uid = user.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data();
      final String userName = userData?['username'] ?? userData?['name'] ?? 'Anonim';

      // 1. Handle Image Upload
      String imageUrl;
      if (_selectedImageFile != null) {
        // Use a unique name for the image
        final String fileName = 'event_${uid}_${DateTime.now().millisecondsSinceEpoch}';
        imageUrl = await _storageService.uploadEventImage(fileName, _selectedImageFile!) ?? 
                   ImageHelper.getEventImage(_selectedCategory, _titleController.text, _descController.text);
      } else if (_prefilledImageUrl != null) {
        imageUrl = _prefilledImageUrl!;
      } else {
        imageUrl = ImageHelper.getEventImage(
          _selectedCategory, 
          _titleController.text.trim(),
          _descController.text.trim()
        );
      }
      
      // 2. Prepare Date
      DateTime fullDate = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _selectedTime!.hour, _selectedTime!.minute,
      );

      List<String> initialParticipants = [uid];

      // 4. Create Document
      final docRef = await FirebaseFirestore.instance.collection('events').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'city': _selectedCity,
        'address': _addressController.text.trim(),
        'eventDate': Timestamp.fromDate(fullDate),
        'imageUrl': imageUrl,
        'participants': initialParticipants,
        'pendingParticipants': [],
        'isApprovalRequired': _isApprovalRequired,
        'quota': int.tryParse(_quotaController.text) ?? 0,
        'requirements': _requirementsController.text.trim(),
        'creatorId': uid,
        'creatorName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'isApproved': true, 
        'isArchived': false,
        'isAttendanceDutyChecked': false,
        'attended': initialParticipants,
        'absent': [],
        'scoredUsers': [],
        'date': Timestamp.fromDate(fullDate),
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
        'link': widget.prefillData?['link'],
        'externalSource': widget.prefillData?['externalSource'] ?? false,
      });

      // 5. Send Notifications to Followers
      if (userData != null) {
        List followers = userData['followers'] ?? [];
        if (followers.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var followerId in followers) {
            final notifRef = FirebaseFirestore.instance
                .collection('users')
                .doc(followerId)
                .collection('notifications')
                .doc();
            
            batch.set(notifRef, {
              'type': 'new_event_from_following',
              'senderId': uid,
              'senderName': userName,
              'content': 'yeni bir etkinlik oluşturdu: ${_titleController.text.trim()}',
              'relatedId': docRef.id,
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            });
          }
          await batch.commit();
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Etkinlik başarıyla oluşturuldu!'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      debugPrint("Event creation error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hata Oluştu'),
            content: Text('İşlem tamamlanamadı: $e'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam')),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    _quotaController.dispose();
    _requirementsController.dispose();
    super.dispose();
  }
}
