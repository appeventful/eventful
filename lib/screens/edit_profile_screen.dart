import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/user_model.dart';
import '../widgets/custom_avatar.dart';
import '../utils/constants.dart';

class EditProfileScreen extends StatefulWidget {
  final String? targetUserId;
  const EditProfileScreen({super.key, this.targetUserId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instagramController = TextEditingController();
  final _bioController = TextEditingController();
  final _favoriteBooksController = TextEditingController();
  final _favoriteMoviesController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  DateTime? _selectedBirthDate;
  String? _selectedGender;
  String? _selectedCity;
  
  bool _hideAge = false;
  bool _hideGender = false;
  bool _hideLocation = false;
  bool _hideInstagram = false;

  bool _isLoading = false;
  Map<String, dynamic>? _userData;
  bool _isAdminEditing = false;

  File? _image;
  String? _selectedAvatarUrl;
  String? _currentImageUrl;

  final List<String> _maleAvatars = [
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/male/45.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/male/86.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/male/1.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/male/15.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/male/22.png',
  ];

  final List<String> _femaleAvatars = [
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/female/68.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/female/1.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/female/5.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/female/18.png',
    'https://raw.githubusercontent.com/Ashwinvalento/cartoon-avatar/master/lib/images/female/24.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final targetUid = widget.targetUserId ?? currentUid;
    
    _isAdminEditing = widget.targetUserId != null && widget.targetUserId != currentUid;

    final doc = await FirebaseFirestore.instance.collection('users').doc(targetUid).get();
    if (doc.exists) {
      if (mounted) {
        final user = UserModel.fromFirestore(doc);
        setState(() {
          _userData = doc.data();
          _nameController.text = user.name;
          _usernameController.text = user.username;
          _emailController.text = user.email;
          _phoneController.text = user.phone ?? '';
          _instagramController.text = user.instagramHandle ?? '';
          _bioController.text = user.bio;
          _favoriteBooksController.text = user.favoriteBooks.join(", ");
          _favoriteMoviesController.text = user.favoriteMovies.join(", ");
          _selectedGender = user.gender;
          if (_selectedGender == 'Erkek') _selectedGender = 'male';
          if (_selectedGender == 'Kadın') _selectedGender = 'female';
          if (_selectedGender == 'Diğer') _selectedGender = 'other';
          
          _selectedCity = user.location;
          _hideAge = user.hideAge;
          _hideGender = user.hideGender;
          _hideLocation = user.hideLocation;
          _hideInstagram = user.hideInstagram;
          
          _currentImageUrl = user.profileImage;

          if (user.birthDate != null) {
            _selectedBirthDate = user.birthDate!.toDate();
          }
        });
      }
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeni şifre en az 6 karakter olmalıdır.')));
      return;
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      final cred = EmailAuthProvider.credential(email: user!.email!, password: _currentPasswordController.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPasswordController.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre başarıyla güncellendi.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Şifre güncellenemedi: $e')));
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _selectedAvatarUrl = null;
      });
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeriden Seç'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Fotoğraf Çek'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.face),
              title: const Text('Avatar Seç'),
              onTap: () {
                Navigator.of(context).pop();
                _showAvatarSelectionDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarSelectionDialog() {
    String? tempGender = _selectedGender;
    if (tempGender == 'Erkek') tempGender = 'male';
    if (tempGender == 'Kadın') tempGender = 'female';
    if (tempGender == null || tempGender == 'other' || (tempGender != 'male' && tempGender != 'female')) {
      tempGender = 'male';
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final avatars = tempGender == 'male' ? _maleAvatars : _femaleAvatars;
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Bir Avatar Seçin'),
                DropdownButton<String>(
                  value: tempGender,
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Erkek')),
                    DropdownMenuItem(value: 'female', child: Text('Kadın')),
                  ],
                  onChanged: (val) {
                    setDialogState(() => tempGender = val);
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: avatars.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAvatarUrl = avatars[index];
                        _image = null;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _selectedAvatarUrl == avatars[index] ? Colors.orange : Colors.transparent,
                          width: 2,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        backgroundImage: NetworkImage(avatars[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      ),
    );
  }

  Future<void> _saveChanges() async {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final targetUid = widget.targetUserId ?? currentUid;
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic> updates = {};
      
      if (_image != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_images').child('$targetUid.jpg');
        await ref.putFile(_image!);
        updates['profileImage'] = await ref.getDownloadURL();
        updates['isProfileImageApproved'] = false; // Mark for moderation
        updates['useCharacterImage'] = false;
      } else if (_selectedAvatarUrl != null) {
        updates['profileImage'] = _selectedAvatarUrl;
        updates['isProfileImageApproved'] = true; // Avatars are pre-approved
        updates['useCharacterImage'] = false;
      }

      // Direct Updates
      if (_usernameController.text != _userData?['username']) {
        final username = _usernameController.text.trim().toLowerCase();
        if (username.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kullanıcı adı boş olamaz.')));
          setState(() => _isLoading = false);
          return;
        }

        // Check uniqueness
        final existing = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        if (existing.docs.isNotEmpty && existing.docs.first.id != targetUid) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu kullanıcı adı zaten alınmış.')));
          setState(() => _isLoading = false);
          return;
        }
        updates['username'] = username;
      }
      if (_bioController.text != _userData?['bio']) updates['bio'] = _bioController.text;
      if (_instagramController.text != _userData?['instagramHandle']) updates['instagramHandle'] = _instagramController.text;
      if (_selectedGender != _userData?['gender']) updates['gender'] = _selectedGender;
      if (_selectedCity != _userData?['location']) updates['location'] = _selectedCity;

      if (_hideAge != _userData?['hideAge']) updates['hideAge'] = _hideAge;
      if (_hideGender != _userData?['hideGender']) updates['hideGender'] = _hideGender;
      if (_hideLocation != _userData?['hideLocation']) updates['hideLocation'] = _hideLocation;
      if (_hideInstagram != _userData?['hideInstagram']) updates['hideInstagram'] = _hideInstagram;
      
      List<String> books = _favoriteBooksController.text.split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      List<String> movies = _favoriteMoviesController.text.split(",").map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      updates['favoriteBooks'] = books;
      updates['favoriteMovies'] = movies;

      if (_selectedBirthDate != null && 
          (_userData?['birthDate'] == null || _selectedBirthDate != (_userData?['birthDate'] as Timestamp).toDate())) {
        updates['birthDate'] = Timestamp.fromDate(_selectedBirthDate!);
      }

      // Name and Phone require admin approval OR if admin is editing they are direct
      bool nameChanged = _nameController.text != _userData?['name'];
      bool phoneChanged = _phoneController.text != _userData?['phone'];

      if (nameChanged || phoneChanged) {
        if (_isAdminEditing) {
          updates['name'] = _nameController.text;
          updates['phone'] = _phoneController.text;
        } else {
          await FirebaseFirestore.instance.collection('updateRequests').add({
            'userId': targetUid,
            'currentName': _userData?['name'],
            'newName': _nameController.text,
            'currentPhone': _userData?['phone'],
            'newPhone': _phoneController.text,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('İsim ve telefon değişikliği yönetici onayına gönderildi.')),
            );
          }
        }
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(targetUid).update(updates);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profili Düzenle'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: _userData == null 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceActionSheet,
                          child: Stack(
                            children: [
                              CustomAvatar(
                                radius: 50,
                                imageUrl: _image?.path ?? _selectedAvatarUrl ?? _currentImageUrl,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showAvatarSelectionDialog,
                          icon: const Icon(Icons.face, size: 20),
                          label: const Text('Karakter Avatarı Seç'),
                          style: TextButton.styleFrom(foregroundColor: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('Kişisel Bilgiler'),
                  _buildTextField('Ad Soyad', _nameController, readOnly: !_isAdminEditing, suffixIcon: !_isAdminEditing ? Icons.lock_outline : null),
                  const SizedBox(height: 10),
                  _buildTextField('Telefon', _phoneController, readOnly: !_isAdminEditing, suffixIcon: !_isAdminEditing ? Icons.lock_outline : null),
                  if (!_isAdminEditing)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text('* Ad ve telefon değişimi için yönetici onayı gerekir.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  const SizedBox(height: 15),
                  _buildTextField('Kullanıcı Adı', _usernameController),
                  const SizedBox(height: 15),
                  _buildTextField('E-posta', _emailController, readOnly: true),
                  const SizedBox(height: 15),
                  _buildTextField('Instagram Kullanıcı Adı', _instagramController, hintText: 'eventfulapptr'),
                  const SizedBox(height: 15),
                  _buildDatePicker(),
                  const SizedBox(height: 15),
                  _buildGenderPicker(),
                  const SizedBox(height: 15),
                  _buildCityPicker(),
                  const SizedBox(height: 30),
                  _buildSectionTitle('Gizlilik Ayarları'),
                  _buildPrivacySwitch('Yaşımı Gizle', _hideAge, (v) => setState(() => _hideAge = v)),
                  _buildPrivacySwitch('Cinsiyetimi Gizle', _hideGender, (v) => setState(() => _hideGender = v)),
                  _buildPrivacySwitch('Şehrimi Gizle', _hideLocation, (v) => setState(() => _hideLocation = v)),
                  _buildPrivacySwitch('Instagram Adresimi Gizle', _hideInstagram, (v) => setState(() => _hideInstagram = v)),
                  const SizedBox(height: 15),
                  _buildTextField('Biyografi', _bioController, maxLines: 3),
                  const SizedBox(height: 15),
                  _buildTextField('Favori Kitaplar (Virgül ile ayırın)', _favoriteBooksController),
                  const SizedBox(height: 15),
                  _buildTextField('Favori Filmler (Virgül ile ayırın)', _favoriteMoviesController),
                  
                  if (!_isAdminEditing) ...[
                    const SizedBox(height: 30),
                    _buildSectionTitle('Güvenlik'),
                    _buildTextField('Mevcut Şifre', _currentPasswordController, isPassword: true),
                    const SizedBox(height: 10),
                    _buildTextField('Yeni Şifre', _newPasswordController, isPassword: true),
                    const SizedBox(height: 10),
                    OutlinedButton(onPressed: _updatePassword, child: const Text('Şifreyi Güncelle')),
                  ],
                  
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Değişiklikleri Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool readOnly = false, bool isPassword = false, IconData? suffixIcon, String? hintText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          readOnly: readOnly,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18, color: Colors.grey) : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: readOnly 
                ? (isDark ? Colors.white10 : Colors.grey[100]) 
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Doğum Tarihi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            DateTime? picked = await showDatePicker(
              context: context,
              initialDate: _selectedBirthDate ?? DateTime(2000),
              firstDate: DateTime(1950),
              lastDate: DateTime.now(),
            );
            if (picked != null && mounted) setState(() => _selectedBirthDate = picked);
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey), 
              borderRadius: BorderRadius.circular(12), 
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_selectedBirthDate == null ? 'Seçiniz' : DateFormat('dd.MM.yyyy').format(_selectedBirthDate!)),
                const Icon(Icons.calendar_today, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cinsiyet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
            filled: true, 
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]
          ),
          items: const [
            DropdownMenuItem(value: 'male', child: Text('Erkek')),
            DropdownMenuItem(value: 'female', child: Text('Kadın')),
            DropdownMenuItem(value: 'other', child: Text('Diğer')),
          ],
          onChanged: (val) => setState(() {
            _selectedGender = val;
            _selectedAvatarUrl = null;
          }),
        ),
      ],
    );
  }

  Widget _buildCityPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Şehir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
            filled: true, 
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50]
          ),
          items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) => setState(() => _selectedCity = val),
        ),
      ],
    );
  }

  Widget _buildPrivacySwitch(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.orange,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
