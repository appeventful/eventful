import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/constants.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String username;
  final String role; // 'admin', 'moderator', 'city_representative', 'user'
  final String? responsibleCity; // For city representatives
  final bool isBanned;
  final bool isRestricted; // Absence restriction
  final int referenceParticipationCount; // Required participation to lift restriction
  final String? banReason;
  final Timestamp? banUntil;
  final String profileImage;
  final int points;
  final List<String> blockedUsers;
  final List<String> sentFriendRequests;
  final List<String> friends;
  final List<String> followers;
  final List<String> following;
  final double trustScore;
  final int ratingCount;
  final bool isFounder;
  final bool hasSeenFounderWelcome;
  final bool kvkkAccepted;
  final bool termsAccepted;
  final bool privacyAccepted;
  final String bio;
  final List<String> favoriteBooks;
  final List<String> favoriteMovies;
  final bool hideAge;
  final bool hideHoroscope;
  final bool hideLocation;
  final bool hideInstagram;
  final bool hideGender;
  final String? gender; // 'male', 'female', 'other'
  final String? characterImage;
  final bool useCharacterImage;
  final String? phone;
  final String? location;
  final String? instagramHandle;
  final bool isInstagramFollowed;
  final Timestamp? birthDate;
  final bool isFrozen;
  final bool isDeleted;
  final bool isGhostMode;
  final bool isProfileImageApproved;
  final bool emailVerified;
  final List<String> badges;
  final String? deviceId;
  final Map<String, bool> notificationSettings;
  final String supporterTier; // 'none', 'bronze', 'silver', 'gold'

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.username,
    this.role = 'user',
    this.responsibleCity,
    this.isBanned = false,
    this.isRestricted = false,
    this.referenceParticipationCount = 0,
    this.banReason,
    this.banUntil,
    this.profileImage = '',
    this.points = 0,
    this.blockedUsers = const [],
    this.sentFriendRequests = const [],
    this.friends = const [],
    this.followers = const [],
    this.following = const [],
    this.trustScore = 0.0,
    this.ratingCount = 0,
    this.isFounder = false,
    this.hasSeenFounderWelcome = false,
    this.kvkkAccepted = false,
    this.termsAccepted = false,
    this.privacyAccepted = false,
    this.bio = '',
    this.favoriteBooks = const [],
    this.favoriteMovies = const [],
    this.hideAge = false,
    this.hideHoroscope = false,
    this.hideLocation = false,
    this.hideInstagram = false,
    this.hideGender = false,
    this.gender,
    this.characterImage,
    this.useCharacterImage = false,
    this.phone,
    this.location,
    this.instagramHandle,
    this.isInstagramFollowed = false,
    this.birthDate,
    this.isFrozen = false,
    this.isDeleted = false,
    this.isGhostMode = false,
    this.isProfileImageApproved = false,
    this.emailVerified = false,
    this.badges = const [],
    this.deviceId,
    this.notificationSettings = const {
      'new_message': true,
      'friend_request': true,
      'event_approval': true,
      'event_reminder': true,
      'mentions': true,
    },
    this.supporterTier = 'none',
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? username,
    String? role,
    String? responsibleCity,
    bool? isBanned,
    bool? isRestricted,
    int? referenceParticipationCount,
    String? banReason,
    Timestamp? banUntil,
    String? profileImage,
    int? points,
    List<String>? blockedUsers,
    List<String>? sentFriendRequests,
    List<String>? friends,
    List<String>? followers,
    List<String>? following,
    double? trustScore,
    int? ratingCount,
    bool? isFounder,
    bool? hasSeenFounderWelcome,
    bool? kvkkAccepted,
    bool? termsAccepted,
    bool? privacyAccepted,
    String? bio,
    List<String>? favoriteBooks,
    List<String>? favoriteMovies,
    bool? hideAge,
    bool? hideHoroscope,
    bool? hideLocation,
    bool? hideInstagram,
    bool? hideGender,
    String? gender,
    String? characterImage,
    bool? useCharacterImage,
    String? phone,
    String? location,
    String? instagramHandle,
    bool? isInstagramFollowed,
    Timestamp? birthDate,
    bool? isFrozen,
    bool? isDeleted,
    bool? isGhostMode,
    bool? isProfileImageApproved,
    bool? emailVerified,
    List<String>? badges,
    String? deviceId,
    Map<String, bool>? notificationSettings,
    String? supporterTier,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      role: role ?? this.role,
      responsibleCity: responsibleCity ?? this.responsibleCity,
      isBanned: isBanned ?? this.isBanned,
      isRestricted: isRestricted ?? this.isRestricted,
      referenceParticipationCount: referenceParticipationCount ?? this.referenceParticipationCount,
      banReason: banReason ?? this.banReason,
      banUntil: banUntil ?? this.banUntil,
      profileImage: profileImage ?? this.profileImage,
      points: points ?? this.points,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      sentFriendRequests: sentFriendRequests ?? this.sentFriendRequests,
      friends: friends ?? this.friends,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      trustScore: trustScore ?? this.trustScore,
      ratingCount: ratingCount ?? this.ratingCount,
      isFounder: isFounder ?? this.isFounder,
      hasSeenFounderWelcome: hasSeenFounderWelcome ?? this.hasSeenFounderWelcome,
      kvkkAccepted: kvkkAccepted ?? this.kvkkAccepted,
      termsAccepted: termsAccepted ?? this.termsAccepted,
      privacyAccepted: privacyAccepted ?? this.privacyAccepted,
      bio: bio ?? this.bio,
      favoriteBooks: favoriteBooks ?? this.favoriteBooks,
      favoriteMovies: favoriteMovies ?? this.favoriteMovies,
      hideAge: hideAge ?? this.hideAge,
      hideHoroscope: hideHoroscope ?? this.hideHoroscope,
      hideLocation: hideLocation ?? this.hideLocation,
      hideInstagram: hideInstagram ?? this.hideInstagram,
      hideGender: hideGender ?? this.hideGender,
      gender: gender ?? this.gender,
      characterImage: characterImage ?? this.characterImage,
      useCharacterImage: useCharacterImage ?? this.useCharacterImage,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      isInstagramFollowed: isInstagramFollowed ?? this.isInstagramFollowed,
      birthDate: birthDate ?? this.birthDate,
      isFrozen: isFrozen ?? this.isFrozen,
      isDeleted: isDeleted ?? this.isDeleted,
      isGhostMode: isGhostMode ?? this.isGhostMode,
      isProfileImageApproved: isProfileImageApproved ?? this.isProfileImageApproved,
      emailVerified: emailVerified ?? this.emailVerified,
      badges: badges ?? this.badges,
      deviceId: deviceId ?? this.deviceId,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      supporterTier: supporterTier ?? this.supporterTier,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    // God Mode Check: Specified email or phone always returns admin
    String detectedRole = data['role'] ?? 'user';
    if (data['email'] == adminEmail || data['phone'] == adminPhone) {
      detectedRole = 'admin';
    }

    Timestamp? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is String) {
        DateTime? dt = DateTime.tryParse(value);
        if (dt != null) return Timestamp.fromDate(dt);
      }
      return null;
    }

    Map<String, bool> settings = Map<String, bool>.from(data['notificationSettings'] ?? {
      'new_message': true,
      'friend_request': true,
      'event_approval': true,
      'event_reminder': true,
      'mentions': true,
    });

    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      username: data['username'] ?? (data['name'] ?? '').toString().toLowerCase().replaceAll(' ', ''),
      role: detectedRole,
      responsibleCity: data['responsibleCity'],
      isBanned: data['isBanned'] ?? false,
      isRestricted: data['isRestricted'] ?? false,
      referenceParticipationCount: data['referenceParticipationCount'] ?? 0,
      banReason: data['banReason'],
      banUntil: parseTimestamp(data['banUntil']),
      profileImage: data['profileImage'] ?? data['profileImageUrl'] ?? '',
      points: (data['points'] ?? 0).toInt(),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      sentFriendRequests: List<String>.from(data['sentFriendRequests'] ?? []),
      friends: List<String>.from(data['friends'] ?? []),
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      trustScore: (data['trustScore'] ?? 0.0).toDouble(),
      ratingCount: (data['ratingCount'] ?? 0).toInt(),
      isFounder: data['isFounder'] ?? false,
      hasSeenFounderWelcome: data['hasSeenFounderWelcome'] ?? false,
      kvkkAccepted: data['kvkkAccepted'] ?? false,
      termsAccepted: data['termsAccepted'] ?? false,
      privacyAccepted: data['privacyAccepted'] ?? false,
      bio: data['bio'] ?? '',
      favoriteBooks: List<String>.from(data['favoriteBooks'] ?? []),
      favoriteMovies: List<String>.from(data['favoriteMovies'] ?? []),
      hideAge: data['hideAge'] ?? false,
      hideHoroscope: data['hideHoroscope'] ?? false,
      hideLocation: data['hideLocation'] ?? false,
      hideInstagram: data['hideInstagram'] ?? false,
      hideGender: data['hideGender'] ?? false,
      gender: data['gender'],
      characterImage: data['characterImage'],
      useCharacterImage: data['useCharacterImage'] ?? false,
      phone: data['phone'],
      location: data['location'],
      instagramHandle: data['instagramHandle'],
      isInstagramFollowed: data['isInstagramFollowed'] ?? false,
      birthDate: parseTimestamp(data['birthDate']),
      isFrozen: data['isFrozen'] ?? false,
      isDeleted: data['isDeleted'] ?? false,
      isGhostMode: data['isGhostMode'] ?? false,
      isProfileImageApproved: data['isProfileImageApproved'] ?? false,
      emailVerified: data['emailVerified'] ?? false,
      badges: List<String>.from(data['badges'] ?? []),
      deviceId: data['deviceId'],
      notificationSettings: settings,
      supporterTier: data['supporterTier'] ?? 'none',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'username': username,
      'role': role,
      'responsibleCity': responsibleCity,
      'isBanned': isBanned,
      'isRestricted': isRestricted,
      'referenceParticipationCount': referenceParticipationCount,
      'banReason': banReason,
      'banUntil': banUntil,
      'profileImage': profileImage,
      'points': points,
      'blockedUsers': blockedUsers,
      'sentFriendRequests': sentFriendRequests,
      'friends': friends,
      'followers': followers,
      'following': following,
      'trustScore': trustScore,
      'ratingCount': ratingCount,
      'isFounder': isFounder,
      'hasSeenFounderWelcome': hasSeenFounderWelcome,
      'kvkkAccepted': kvkkAccepted,
      'termsAccepted': termsAccepted,
      'privacyAccepted': privacyAccepted,
      'bio': bio,
      'favoriteBooks': favoriteBooks,
      'favoriteMovies': favoriteMovies,
      'hideAge': hideAge,
      'hideHoroscope': hideHoroscope,
      'hideLocation': hideLocation,
      'hideInstagram': hideInstagram,
      'hideGender': hideGender,
      'gender': gender,
      'characterImage': characterImage,
      'useCharacterImage': useCharacterImage,
      'phone': phone,
      'location': location,
      'instagramHandle': instagramHandle,
      'isInstagramFollowed': isInstagramFollowed,
      'birthDate': birthDate,
      'isFrozen': isFrozen,
      'isDeleted': isDeleted,
      'isGhostMode': isGhostMode,
      'isProfileImageApproved': isProfileImageApproved,
      'emailVerified': emailVerified,
      'badges': badges,
      'deviceId': deviceId,
      'notificationSettings': notificationSettings,
      'supporterTier': supporterTier,
    };
  }

  bool get isAdmin => role == 'admin' || email == adminEmail || phone == adminPhone;
  bool get isModerator => role == 'moderator' || isAdmin;
  bool get isCityRepresentative => role == 'city_representative';
  bool get isStaff => isAdmin || isModerator || isCityRepresentative;
  bool get isSupporter => supporterTier != 'none';

  bool canManageCity(String? city) {
    if (isAdmin || isModerator) return true;
    if (isCityRepresentative && responsibleCity != null && city != null) {
      // Comparison handles case sensitivity just in case
      return responsibleCity!.trim().toLowerCase() == city.trim().toLowerCase();
    }
    return false;
  }

  bool get isPassive => isFrozen || isDeleted;

  String getEffectiveImageUrl({bool isMe = false, bool viewerIsAdmin = false}) {
    if (useCharacterImage) {
      return characterImage ?? '';
    }
    
    // If it's my own profile or the viewer is an admin, show the image even if not approved
    if (isMe || viewerIsAdmin || isProfileImageApproved) {
      return profileImage;
    }
    
    // Otherwise return empty (or could return characterImage as fallback if desired)
    return '';
  }

  TextStyle getNameStyle(BuildContext context, {double fontSize = 16, bool isBold = true}) {
    Color? nameColor;
    List<Shadow>? shadows;
    FontWeight fontWeight = isBold ? FontWeight.bold : FontWeight.normal;

    switch (supporterTier) {
      case 'bronze':
        nameColor = kBronzeColor;
        break;
      case 'silver':
        nameColor = kSilverColor;
        shadows = [
          Shadow(
            blurRadius: 10.0,
            color: kSilverColor.withOpacity(0.5),
            offset: const Offset(0, 0),
          ),
        ];
        break;
      case 'gold':
        nameColor = kGoldColor;
        shadows = [
          Shadow(
            blurRadius: 15.0,
            color: kGoldColor.withOpacity(0.8),
            offset: const Offset(0, 0),
          ),
          const Shadow(
            blurRadius: 5.0,
            color: Colors.white,
            offset: Offset(0, 0),
          ),
        ];
        break;
      default:
        // Standart renk, temanın varsayılan metin rengi
        return TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
    }

    return TextStyle(
      color: nameColor,
      fontWeight: fontWeight,
      fontSize: fontSize,
      shadows: shadows,
    );
  }
}
