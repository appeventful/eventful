import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'map_picker_screen.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';

class EditEventScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> eventData;

  const EditEventScreen({super.key, required this.eventId, required this.eventData});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _addressController;
  final StorageService _storageService = StorageService();
  
  File? _selectedImageFile;
  String? _currentImageUrl;
  late String _selectedCategory;
  final List<String> _categories = List.from(categories);
  
  late String _selectedCity;
  final List<String> _cities = List.from(cities);

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedLocation;
  bool _isLoading = false;
  late bool _isApprovalRequired;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.eventData['title']);
    _descController = TextEditingController(text: widget.eventData['description']);
    _addressController = TextEditingController(text: widget.eventData['address'] ?? '');
    _selectedCategory = widget.eventData['category'] ?? 'Genel';
    _selectedCity = widget.eventData['city'] ?? 'İstanbul';
    _isApprovalRequired = widget.eventData['isApprovalRequired'] ?? false;
    _currentImageUrl = widget.eventData['imageUrl'];
    
    // Mevcut koordinatları al
    if (widget.eventData['latitude'] != null && widget.eventData['longitude'] != null) {
      _selectedLocation = LatLng(
        (widget.eventData['latitude'] as num).toDouble(),
        (widget.eventData['longitude'] as num).toDouble(),
      );
    }

    _cities.sort();

    if (widget.eventData['eventDate'] != null) {
      DateTime dt;
      dynamic rawDate = widget.eventData['eventDate'];
      if (rawDate is Timestamp) {
        dt = rawDate.toDate();
      } else if (rawDate is String) {
        dt = DateTime.tryParse(rawDate) ?? DateTime.now();
      } else {
        dt = DateTime.now();
      }
      _selectedDate = dt;
      _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
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
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      if (mounted) _selectTime(context);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Etkinliği Düzenle', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resim Düzenleme Alanı
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 2),
                        image: _selectedImageFile != null
                            ? DecorationImage(image: FileImage(_selectedImageFile!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: _selectedImageFile != null
                          ? Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => setState(() => _selectedImageFile = null),
                              ),
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_currentImageUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: ColorFiltered(
                                      colorFilter: ColorFilter.mode(
                                        Colors.black.withValues(alpha: 0.3),
                                        BlendMode.darken,
                                      ),
                                      child: CachedNetworkImage(
                                        imageUrl: _currentImageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                        errorWidget: (context, url, error) => const Icon(Icons.error),
                                      ),
                                    ),
                                  ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 40),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Fotoğrafı Değiştir',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 10)]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Etkinlik Başlığı',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val!.isEmpty ? 'Başlık gerekli' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Etkinlik Açıklaması',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val!.isEmpty ? 'Açıklama gerekli' : null,
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
                    onChanged: (String? newValue) => setState(() => _selectedCategory = newValue!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'Şehir',
                      prefixIcon: const Icon(Icons.location_city),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _cities.map((String city) {
                      return DropdownMenuItem(value: city, child: Text(city));
                    }).toList(),
                    onChanged: (String? newValue) => setState(() => _selectedCity = newValue!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: InputDecoration(
                      labelText: 'Açık Adres / Mekan Adı',
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
                          ? '⚠️ Haritada görünmesi için konum seçilmesi önerilir.' 
                          : '✅ Konum başarıyla işaretlendi.',
                      style: TextStyle(
                        fontSize: 11, 
                        color: _selectedLocation == null ? Colors.orange.shade700 : Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
                      onPressed: _updateEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      String? imageUrl = _currentImageUrl;
      
      // Eğer yeni resim seçilmişse yükle
      if (_selectedImageFile != null) {
        final String? newUrl = await _storageService.uploadEventImage(widget.eventId, _selectedImageFile!);
        if (newUrl != null) {
          imageUrl = newUrl;
        }
      }

      DateTime fullDate = DateTime(
        _selectedDate?.year ?? DateTime.now().year, 
        _selectedDate?.month ?? DateTime.now().month, 
        _selectedDate?.day ?? DateTime.now().day,
        _selectedTime?.hour ?? 12, 
        _selectedTime?.minute ?? 0,
      );

      await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'city': _selectedCity,
        'address': _addressController.text.trim(),
        'eventDate': Timestamp.fromDate(fullDate),
        'isApprovalRequired': _isApprovalRequired,
        'imageUrl': imageUrl,
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Etkinlik başarıyla güncellendi!')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint("Update error: $e");
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Güncelleme Hatası'),
          content: Text('İşlem başarısız oldu. Hata: $e'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
    }
  }
}
