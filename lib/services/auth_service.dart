import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../services/notification_service.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb || Platform.isIOS 
      ? '327687814157-fp3229fguetbfjuert5ijg7ur6d9q4k8.apps.googleusercontent.com' 
      : null,
  );

  // Kayıt sırasında alınan geçici veriler
  static Map<String, String>? pendingData;

  Stream<User?> get authStateChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInAnonymously() async {
    try {
      return await _auth.signInAnonymously();
    } catch (e) {
      debugPrint("Anonymous Sign-In Error: $e");
      return null;
    }
  }

  bool get isGuest => currentUser?.isAnonymous ?? true;

  // --- Email/Password Authentication ---

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Email Sign-In Error: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await credential.user?.sendEmailVerification();
      return credential;
    } catch (e) {
      debugPrint("Email Sign-Up Error: $e");
      rethrow;
    }
  }

  Future<void> registerFullUser({
    required String email,
    required String password,
    required UserModel userModel,
    File? profileImage,
  }) async {
    try {
      // 1. Create Auth User
      UserCredential credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      String uid = credential.user!.uid;

      // Send verification email
      try {
        await credential.user?.sendEmailVerification();
      } catch (e) {
        debugPrint("Email verification error (ignored): $e");
      }

      // 2. Handle Profile Image if any
      String? imageUrl;
      if (profileImage != null) {
        imageUrl = await _uploadProfileImage(uid, profileImage);
      }

      // 3. Prepare User Data (Using existing completeProfile logic)
      bool isFounder = false;
      DateTime launchDeadline = DateTime(2025, 5, 31);
      if (DateTime.now().isBefore(launchDeadline)) {
        isFounder = true;
      }

      Map<String, dynamic> userData = userModel.copyWith(uid: uid, email: email).toMap();
      if (imageUrl != null) userData['profileImage'] = imageUrl;
      
      List<String> initialBadges = List<String>.from(userModel.badges);
      if (isFounder && !initialBadges.contains('founder')) {
        initialBadges.add('founder');
      }

      userData['isFounder'] = isFounder;
      userData['badges'] = initialBadges;
      userData['createdAt'] = FieldValue.serverTimestamp();
      userData['phone'] = _normalizePhone(userModel.phone ?? '');
      userData['friends'] = [];
      userData['points'] = 0;
      userData['deviceId'] = await getDeviceId();

      // 4. Save to Firestore
      await _firestore.collection('users').doc(uid).set(userData);
      
      // Initialize notifications
      try {
        await NotificationService.initialize();
      } catch (e) {
        debugPrint("Notification init error (ignored): $e");
      }
    } catch (e) {
      debugPrint("Error in registerFullUser: $e");
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint("Password Reset Error: $e");
      rethrow;
    }
  }

  Future<bool> isEmailRegistered(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Check Email Error: $e");
      return false;
    }
  }

  // --- Phone Authentication ---

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) verificationCompleted,
    required Function(FirebaseAuthException) verificationFailed,
    required Function(String, int?) codeSent,
    required Function(String) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential?> signInWithPhoneCredential(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Phone Sign-In Error: $e");
      rethrow;
    }
  }

  // --- Social Authentication ---

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256Nonce(rawNonce),
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Apple Sign-In Error: $e");
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => charset[random % charset.length]).join();
  }

  String _sha256Nonce(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --- Profile Management ---

  Stream<UserModel?> userStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> completeProfile(UserModel userModel, File? profileImage) async {
    try {
      String? imageUrl;
      if (profileImage != null) {
        imageUrl = await _uploadProfileImage(userModel.uid, profileImage);
      }

      // Founder Check
      bool isFounder = false;
      DateTime launchDeadline = DateTime(2025, 5, 31);
      if (DateTime.now().isBefore(launchDeadline)) {
        isFounder = true;
      }

      Map<String, dynamic> userData = userModel.toMap();
      if (imageUrl != null) userData['profileImage'] = imageUrl;
      
      List<String> initialBadges = List<String>.from(userModel.badges);
      if (isFounder && !initialBadges.contains('founder')) {
        initialBadges.add('founder');
      }

      userData['isFounder'] = isFounder;
      userData['badges'] = initialBadges;
      if (isFounder && !initialBadges.contains('founder')) {
        initialBadges.add('founder');
      }
      userData['createdAt'] = FieldValue.serverTimestamp();
      userData['phone'] = _normalizePhone(userModel.phone ?? '');
      userData['friends'] = [];
      userData['points'] = 0;
      userData['deviceId'] = await getDeviceId();

      await _firestore.collection('users').doc(userModel.uid).set(userData);
      await NotificationService.initialize();
    } catch (e) {
      debugPrint("Error completing profile: $e");
      rethrow;
    }
  }

  // --- Helpers ---

  Future<String?> _uploadProfileImage(String uid, File imageFile) async {
    try {
      Reference ref = _storage.ref().child('profile_images').child('$uid.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<String?> getDeviceId() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) return null;
    try {
      if (Platform.isAndroid) {
        var androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        var iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      }
    } catch (e) {
      debugPrint("Error getting device ID: $e");
    }
    return null;
  }

  Future<bool> isDeviceBanned() async {
    String? deviceId = await getDeviceId();
    if (deviceId == null) return false;

    try {
      final doc = await _firestore.collection('blacklisted_devices').doc(deviceId).get();
      return doc.exists;
    } catch (e) {
      debugPrint("Check Device Ban Error: $e");
      return false; // Hata durumunda (örn: yetki yoksa) girişe izin ver veya güvenli tarafta kal
    }
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> logout() async => await _auth.signOut();

  // --- Social Actions ---

  Future<void> sendFriendRequest(String targetUid) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    // 1. Kendi dokümanını güncelle (Gönderilen istekler)
    await _firestore.collection('users').doc(uid).update({
      'sentFriendRequests': FieldValue.arrayUnion([targetUid])
    });

    // 2. Push ve Uygulama içi bildirim gönder
    await NotificationService.sendNotification(
      recipientId: targetUid,
      title: 'Yeni Arkadaşlık İsteği',
      body: 'Sizinle arkadaş olmak isteyen biri var!',
      data: {
        'type': 'friend_request', 
        'senderId': uid,
        'status': 'pending',
      },
    );
  }

  Future<void> cancelFriendRequest(String targetUid) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    // 1. Kendi listenden çıkar
    await _firestore.collection('users').doc(uid).update({
      'sentFriendRequests': FieldValue.arrayRemove([targetUid])
    });

    // 2. Karşı tarafın bildirimlerinden sil
    final snapshot = await _firestore.collection('users')
        .doc(targetUid)
        .collection('notifications')
        .where('senderId', isEqualTo: uid)
        .where('type', isEqualTo: 'friend_request')
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> acceptFriendRequest(String notificationId, String senderId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    WriteBatch batch = _firestore.batch();

    // 1. Bildirimi güncelle (Kendi alt koleksiyonundaki)
    batch.update(_firestore.collection('users').doc(uid).collection('notifications').doc(notificationId), {
      'status': 'accepted',
      'isRead': true,
    });

    // 2. Arkadaş listelerini güncelle
    batch.update(_firestore.collection('users').doc(uid), {
      'friends': FieldValue.arrayUnion([senderId])
    });
    batch.update(_firestore.collection('users').doc(senderId), {
      'friends': FieldValue.arrayUnion([uid]),
      'sentFriendRequests': FieldValue.arrayRemove([uid])
    });

    await batch.commit();

    // 3. Karşı tarafa "Kabul edildi" bildirimi gönder
    await NotificationService.sendNotification(
      recipientId: senderId,
      title: 'Arkadaşlık İsteği Kabul Edildi',
      body: 'Artık arkadaşsınız!',
      data: {'type': 'friend_accepted', 'senderId': uid},
    );
  }

  Future<void> rejectFriendRequest(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'status': 'rejected'
    });
  }

  Future<void> removeFriend(String targetUid) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    WriteBatch batch = _firestore.batch();
    batch.update(_firestore.collection('users').doc(uid), {
      'friends': FieldValue.arrayRemove([targetUid])
    });
    batch.update(_firestore.collection('users').doc(targetUid), {
      'friends': FieldValue.arrayRemove([uid])
    });
    await batch.commit();
  }

  Future<void> toggleFollow(String targetUid, bool currentlyFollowing) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    WriteBatch batch = _firestore.batch();
    if (currentlyFollowing) {
      batch.update(_firestore.collection('users').doc(uid), {
        'following': FieldValue.arrayRemove([targetUid])
      });
      batch.update(_firestore.collection('users').doc(targetUid), {
        'followers': FieldValue.arrayRemove([uid])
      });
    } else {
      batch.update(_firestore.collection('users').doc(uid), {
        'following': FieldValue.arrayUnion([targetUid])
      });
      batch.update(_firestore.collection('users').doc(targetUid), {
        'followers': FieldValue.arrayUnion([uid])
      });
    }
    await batch.commit();
  }

  Future<void> toggleBlock(String targetUid, bool currentlyBlocked) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    WriteBatch batch = _firestore.batch();
    if (currentlyBlocked) {
      batch.update(_firestore.collection('users').doc(uid), {
        'blockedUsers': FieldValue.arrayRemove([targetUid])
      });
    } else {
      batch.update(_firestore.collection('users').doc(uid), {
        'blockedUsers': FieldValue.arrayUnion([targetUid]),
        'friends': FieldValue.arrayRemove([targetUid]),
        'following': FieldValue.arrayRemove([targetUid])
      });
      batch.update(_firestore.collection('users').doc(targetUid), {
        'friends': FieldValue.arrayRemove([uid]),
        'followers': FieldValue.arrayRemove([uid])
      });
    }
    await batch.commit();
  }

  // --- Event Requests ---

  Future<void> acceptEventRequest(String notificationId, String eventId, String senderId) async {
    WriteBatch batch = _firestore.batch();
    batch.update(_firestore.collection('notifications').doc(notificationId), {
      'status': 'accepted'
    });
    batch.update(_firestore.collection('events').doc(eventId), {
      'participants': FieldValue.arrayUnion([senderId])
    });
    await batch.commit();
  }

  Future<void> rejectEventRequest(String notificationId, String eventId, String senderId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'status': 'rejected'
    });
  }

  // --- Account Actions ---

  Future<String?> freezeAccount(String reason) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return 'Kullanıcı bulunamadı.';
      await _firestore.collection('users').doc(uid).update({
        'isFrozen': true,
        'freezeReason': reason,
        'freezeDate': FieldValue.serverTimestamp(),
      });
      await logout();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteAccount({required String reason}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Kullanıcı bulunamadı.';
      await _firestore.collection('users').doc(user.uid).update({
        'isDeleted': true,
        'deleteReason': reason,
        'deleteDate': FieldValue.serverTimestamp(),
      });
      await user.delete();
      await logout();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
