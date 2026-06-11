import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../utils/error_messages.dart';
import 'policy_detail_screen.dart';
import '../utils/platform_helper.dart';
import 'package:flutter/cupertino.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  File? _profileImage;
  bool _isLoading = false;
  
  bool _acceptedTerms = false;
  bool _acceptedKVKK = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  Future<void> _selectDate() async {
    if (PlatformHelper.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: CupertinoColors.separator.resolveFrom(context), width: 0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('Bitti'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate ?? DateTime(2000),
                  maximumDate: DateTime.now(),
                  minimumYear: 1940,
                  onDateTimeChanged: (DateTime newDate) {
                    setState(() => _selectedDate = newDate);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime(2000),
        firstDate: DateTime(1940),
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: Colors.orange, onPrimary: Colors.white),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) {
      setState(() => _error = 'Lütfen tüm alanları doldurun ve doğum tarihinizi seçin.');
      return;
    }

    if (!_acceptedTerms || !_acceptedKVKK) {
      setState(() => _error = 'Lütfen tüm sözleşmeleri onaylayın.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 0. Check Device Ban
      if (await _auth.isDeviceBanned()) {
        throw 'Güvenlik Protokolü: Bu cihaz üzerinden yeni hesap oluşturulması engellenmiştir.';
      }

      // 1. Check if username is taken
      final usernameDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim().toLowerCase())
          .get();

      if (usernameDoc.docs.isNotEmpty) {
        throw 'Bu kullanıcı adı zaten alınmış. Lütfen farklı bir isim deneyin.';
      }

      // 2. Prepare Model
      UserModel newUser = UserModel(
        uid: '', // Will be set by service
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        role: 'user', // Default role
        birthDate: Timestamp.fromDate(_selectedDate!),
        gender: _selectedGender,
        kvkkAccepted: _acceptedKVKK,
        termsAccepted: _acceptedTerms,
        privacyAccepted: _acceptedTerms, 
      );

      // 3. Register Full User (Auth + Firestore)
      await _auth.registerFullUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userModel: newUser,
        profileImage: _profileImage,
      );

      if (mounted) {
        // Kayıt başarılı, kullanıcı zaten login oldu. 
        // Navigator.pop(context) ile AuthWrapper'a döneriz.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = ErrorMessages.parseAuthError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Yeni Hesap', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Image Picker
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.orange.shade50,
                      backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                      child: _profileImage == null
                          ? const Icon(Icons.person, size: 50, color: Colors.orange)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('Kişisel Bilgiler'),
              _buildTextField(
                controller: _nameController,
                label: 'Ad Soyad',
                icon: Icons.badge_outlined,
                validator: (v) => v!.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _usernameController,
                label: 'Kullanıcı Adı',
                icon: Icons.alternate_email,
                validator: (v) => v!.isEmpty ? 'Gerekli' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildGenderPicker(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('İletişim & Güvenlik'),
              _buildTextField(
                controller: _emailController,
                label: 'E-posta',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.contains('@') ? null : 'Geçerli bir mail girin',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _phoneController,
                label: 'Telefon (05xx)',
                icon: Icons.phone_android,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.length >= 10 ? null : 'Eksik numara',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _passwordController,
                label: 'Şifre',
                icon: Icons.lock_outline,
                obscureText: true,
                validator: (v) => v!.length >= 6 ? null : 'En az 6 karakter',
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _confirmPasswordController,
                label: 'Şifre Onayla',
                icon: Icons.lock_clock_outlined,
                obscureText: true,
                validator: (v) => v == _passwordController.text ? null : 'Şifreler uyuşmuyor',
              ),
              
              const SizedBox(height: 24),
              _buildAgreementSection(),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
              ],

              const SizedBox(height: 32),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Kayıt Ol ve Başla', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700, letterSpacing: 1),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.black87, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.orange.shade400, size: 22),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.orange, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        floatingLabelStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: Colors.orange.shade400, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate == null ? 'Doğum Tarihi' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                style: TextStyle(color: _selectedDate == null ? Colors.grey.shade600 : Colors.black87, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderPicker() {
    return InkWell(
      onTap: PlatformHelper.isIOS ? _showIOSGenderPicker : null,
      child: IgnorePointer(
        ignoring: PlatformHelper.isIOS,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedGender,
              dropdownColor: Colors.white,
              items: ['Erkek', 'Kadın', 'Diğer'].map((g) => DropdownMenuItem(
                value: g, 
                child: Text(g, style: const TextStyle(color: Colors.black87)),
              )).toList(),
              onChanged: (v) => setState(() => _selectedGender = v),
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Cinsiyet',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.people_outline, color: Colors.orange, size: 20),
                suffixIcon: PlatformHelper.isIOS ? const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showIOSGenderPicker() {
    final List<String> genders = ['Erkek', 'Kadın', 'Diğer'];
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text('Cinsiyet Seçin'),
        actions: genders.map((g) => CupertinoActionSheetAction(
          onPressed: () {
            setState(() => _selectedGender = g);
            Navigator.pop(context);
          },
          child: Text(g),
        )).toList(),
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
      ),
    );
  }

  Widget _buildAgreementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAgreementRow(
          value: _acceptedKVKK,
          onChanged: (v) => setState(() => _acceptedKVKK = v ?? false),
          text: 'KVKK Aydınlatma Metni',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PolicyDetailScreen(title: 'KVKK Aydınlatma Metni', policyType: 'kvkk')),
          ),
        ),
        const SizedBox(height: 8),
        _buildAgreementRow(
          value: _acceptedTerms,
          onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          isMultiPolicy: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PolicyDetailScreen(title: 'Kullanım Koşulları', policyType: 'terms')),
          ),
          onTapSecondary: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PolicyDetailScreen(title: 'Gizlilik Politikası', policyType: 'privacy')),
          ),
        ),
      ],
    );
  }

  Widget _buildAgreementRow({
    required bool value,
    required Function(bool?) onChanged,
    String? text,
    required VoidCallback onTap,
    bool isMultiPolicy = false,
    VoidCallback? onTapSecondary,
  }) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.orange,
            side: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isMultiPolicy
              ? RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'Kullanım Koşulları',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = onTap,
                      ),
                      const TextSpan(text: ' ve '),
                      TextSpan(
                        text: 'Gizlilik Politikası',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = onTapSecondary,
                      ),
                      const TextSpan(text: '\'nı okudum, onaylıyorum.'),
                    ],
                  ),
                )
              : RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    children: [
                      TextSpan(
                        text: text,
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = onTap,
                      ),
                      const TextSpan(text: '\'ni okudum, onaylıyorum.'),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
