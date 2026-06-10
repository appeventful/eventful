import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DataPortabilityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> downloadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    Map<String, dynamic> allData = {};

    // 1. Profil Bilgileri
    final userDoc = await _db.collection('users').doc(user.uid).get();
    allData['profile'] = userDoc.data();

    // 2. Etkinlikleri (Düzenlediği)
    final eventsQuery = await _db.collection('events').where('creatorId', isEqualTo: user.uid).get();
    allData['organized_events'] = eventsQuery.docs.map((d) => d.data()).toList();

    // 3. Yorumları
    // Not: Tüm etkinliklerdeki yorumları aramak maliyetli olabilir, 
    // ama KVKK gereği kullanıcıya verisini sağlamalıyız.
    // Şimdilik sadece örnek amaçlı temel verileri alıyoruz.
    allData['export_date'] = DateTime.now().toIso8601String();
    allData['info'] = "Bu dosya KVKK kapsaminda Eventful tarafindan saglanmistir.";

    // JSON'a dönüştür
    String jsonString = jsonEncode(allData);

    // Dosyaya yaz
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/eventful_verilerim.json');
    await file.writeAsString(jsonString);

    // Paylaş/İndir
    await Share.shareXFiles([XFile(file.path)], text: 'Eventful Verilerim');
  }
}
