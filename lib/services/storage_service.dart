import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  /// Galeriden veya Kameradan resim seçer
  Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024, // Boyutu sınırla (Maliyet tasarrufu)
        maxHeight: 1024,
        imageQuality: 80, // Kaliteyi %80'e çek (Gözle görülmez kayıp, ciddi alan kazancı)
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint("Resim seçme hatası: $e");
    }
    return null;
  }

  /// Profil fotoğrafı yükler
  Future<String?> uploadProfilePhoto(String userId, File file) async {
    try {
      final ref = _storage.ref().child('profile_pics').child(userId).child('avatar.jpg');
      
      // Yükleme işlemi
      await ref.putFile(file);
      
      // İndirme URL'sini al
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Profil resmi yükleme hatası: $e");
      return null;
    }
  }

  /// Etkinlik resmi yükler
  Future<String?> uploadEventImage(String eventId, File file) async {
    try {
      final String fileName = 'event_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('event_images').child(eventId).child(fileName);
      
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Etkinlik resmi yükleme hatası: $e");
      return null;
    }
  }

  /// Dosya silme (Örn: Eski resmi silmek için)
  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      debugPrint("Dosya silme hatası: $e");
    }
  }
}
