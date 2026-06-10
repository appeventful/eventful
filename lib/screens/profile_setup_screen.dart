import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'policy_detail_screen.dart';
import '../utils/constants.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _usernameController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedCity;
  File? _profileImage;
  bool _isLoading = false;
  bool _kvkkAccepted = false;
  
  // Privacy Settings
  bool _hideAge = false;
  bool _hideGender = false;
  bool _hideLocation = false;
  bool _hideInstagram = false;

  final AuthService _authService = AuthService();

  bool _isNameReadOnly = true;
  bool _isPhoneReadOnly = true;

  @override
  void initState() {
    super.initState();
    // Kayıt ekranından gelen verileri al
    final pending = AuthService.pendingData;
    _nameController = TextEditingController(text: pending?['name']);
    _phoneController = TextEditingController(text: pending?['phone']);
    
    // Eğer pending data yoksa (hayalet kullanıcı), alanları doldurulabilir yap
    if (pending == null || pending['name'] == null) _isNameReadOnly = false;
    if (pending == null || pending['phone'] == null) _isPhoneReadOnly = false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || !_kvkkAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun ve sözleşmeleri onaylayın.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Admin kontrolü
      String userEmail = user.email ?? '';
      String userRole = 'user';
      
      if (userEmail == adminEmail) {
        userRole = 'admin';
      }

      // Check if username is taken
      final usernameDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim().toLowerCase())
          .get();

      if (usernameDoc.docs.isNotEmpty) {
        throw 'Bu kullanıcı adı zaten alınmış.';
      }

      // Prepare user data
      UserModel newUser = UserModel(
        uid: user.uid,
        email: userEmail,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        role: userRole,
        birthDate: Timestamp.fromDate(_selectedDate!),
        gender: _selectedGender,
        location: _selectedCity,
        hideAge: _hideAge,
        hideGender: _hideGender,
        hideLocation: _hideLocation,
        hideInstagram: _hideInstagram,
        kvkkAccepted: _kvkkAccepted,
        termsAccepted: _kvkkAccepted,
        privacyAccepted: _kvkkAccepted,
      );

      // Register via AuthService (it handles image upload and Firestore)
      await _authService.completeProfile(newUser, _profileImage);

      // Success! AuthWrapper will now see the document and navigate to Home.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profilini Tamamla'), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.orange.shade100,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null ? const Icon(Icons.camera_alt, size: 40, color: Colors.orange) : null,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                readOnly: _isNameReadOnly,
                decoration: InputDecoration(
                  labelText: 'Ad Soyad',
                  border: const OutlineInputBorder(),
                  fillColor: _isNameReadOnly ? const Color(0xFFF5F5F5) : Colors.white,
                  filled: true,
                  helperText: _isNameReadOnly ? 'Ad Soyad sonradan değiştirilemez.' : 'Lütfen adınızı ve soyadınızı girin.',
                ),
                validator: (v) => v!.isEmpty ? 'Ad Soyad gerekli' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                readOnly: _isPhoneReadOnly,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Telefon Numarası',
                  border: const OutlineInputBorder(),
                  fillColor: _isPhoneReadOnly ? const Color(0xFFF5F5F5) : Colors.white,
                  filled: true,
                  helperText: _isPhoneReadOnly ? 'Telefon numarası sonradan değiştirilemez.' : 'Örn: 05xx xxx xx xx',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Telefon numarası gerekli';
                  if (v.replaceAll(RegExp(r'[^0-9]'), '').length < 10) return 'Geçerli bir numara girin';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Kullanıcı Adı', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_selectedDate == null ? 'Doğum Tarihi Seçin' : 'Doğum Tarihi: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
                tileColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: ['Erkek', 'Kadın', 'Diğer'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _selectedGender = v),
                decoration: const InputDecoration(labelText: 'Cinsiyet', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCity,
                items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCity = v),
                decoration: const InputDecoration(labelText: 'Şehir', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              const Align(alignment: Alignment.centerLeft, child: Text("Gizlilik Ayarları", style: TextStyle(fontWeight: FontWeight.bold))),
              CheckboxListTile(
                title: const Text("Yaşımı Gizle", style: TextStyle(fontSize: 14)),
                value: _hideAge,
                onChanged: (v) => setState(() => _hideAge = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text("Cinsiyetimi Gizle", style: TextStyle(fontSize: 14)),
                value: _hideGender,
                onChanged: (v) => setState(() => _hideGender = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text("Şehrimi Gizle", style: TextStyle(fontSize: 14)),
                value: _hideLocation,
                onChanged: (v) => setState(() => _hideLocation = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text("Instagram Adresimi Gizle", style: TextStyle(fontSize: 14)),
                value: _hideInstagram,
                onChanged: (v) => setState(() => _hideInstagram = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _kvkkAccepted,
                    onChanged: (v) => setState(() => _kvkkAccepted = v!),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          children: [
                            TextSpan(
                              text: 'Kullanım Koşulları',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PolicyDetailScreen(title: 'Kullanım Koşulları', policyType: 'terms')),
                                ),
                            ),
                            const TextSpan(text: ' ve '),
                            TextSpan(
                              text: 'Gizlilik Politikası',
                              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PolicyDetailScreen(title: 'Gizlilik Politikası', policyType: 'privacy')),
                                ),
                            ),
                            const TextSpan(text: '\'nı okudum, onaylıyorum.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Kaydet ve Başla'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoundedRectangleAttributes extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
  }
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}
  @override
  ShapeBorder scale(double t) => this;
}
