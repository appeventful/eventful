import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String category;
  final String city;
  final String address;
  final DateTime eventDate;
  final String creatorId;
  final List<String> participants;
  final bool isApprovalRequired;
  final bool isApproved;
  final String imageUrl;
  final List<String> attendanceYes;
  final List<String> attendanceNo;
  final Map<String, String> referrals;
  final bool isPinned;
  final bool isArchived;
  final bool isAttendanceDutyChecked;
  final int quota;
  final String requirements;
  final double trendingScore;
  final double averageRating;
  final double? latitude;
  final double? longitude;
  final String? externalLink;
  final String? source;
  final String? qrCodeSecret;

  EventModel({
    required this.id,
    required this.title,
    required this.category,
    required this.city,
    required this.address,
    required this.eventDate,
    required this.creatorId,
    required this.participants,
    required this.isApprovalRequired,
    this.isApproved = true,
    this.imageUrl = '',
    this.attendanceYes = const [],
    this.attendanceNo = const [],
    this.referrals = const {},
    this.isPinned = false,
    this.isArchived = false,
    this.isAttendanceDutyChecked = false,
    this.quota = 0,
    this.requirements = '',
    this.trendingScore = 0.0,
    this.averageRating = 0.0,
    this.latitude,
    this.longitude,
    this.externalLink,
    this.source,
    this.qrCodeSecret,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final rawDate = data['eventDate'] ?? data['date'];
    DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (data['tarih'] != null) {
      // Legacy date format handling if it was a string, otherwise fallback to now
      try {
        parsedDate = DateTime.parse(data['tarih']);
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    String img = data['imageUrl']?.toString() ?? data['resim']?.toString() ?? data['image']?.toString() ?? '';
    if (img == "null") img = '';

    return EventModel(
      id: doc.id,
      title: data['title'] ?? data['baslik'] ?? 'İsimsiz Etkinlik',
      category: data['category'] ?? data['kategori'] ?? 'Diğer',
      city: data['city'] ?? (data['konum']?.toString().split(',').first ?? 'İstanbul'),
      address: data['address'] ?? (data['konum'] ?? 'Konum yok'),
      eventDate: parsedDate,
      creatorId: data['creatorId'] ?? data['olusturanEmail'] ?? '',
      participants: List<String>.from(data['participants'] ?? data['katilimcilar'] ?? []),
      isApprovalRequired: data['isApprovalRequired'] ?? data['referansZorunlu'] ?? false,
      isApproved: data['isApproved'] ?? true,
      imageUrl: img,
      attendanceYes: List<String>.from(data['attendanceYes'] ?? []),
      attendanceNo: List<String>.from(data['attendanceNo'] ?? []),
      referrals: Map<String, String>.from(data['referanslar'] ?? {}),
      isPinned: data['isPinned'] ?? false,
      isArchived: data['isArchived'] ?? false,
      isAttendanceDutyChecked: data['isAttendanceDutyChecked'] ?? false,
      quota: (data['quota'] ?? 0).toInt(),
      requirements: data['requirements'] ?? '',
      trendingScore: (data['trendingScore'] ?? 0.0).toDouble(),
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      externalLink: data['externalLink'],
      source: data['source'],
      qrCodeSecret: data['qrCodeSecret'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'city': city,
      'address': address,
      'eventDate': eventDate,
      'creatorId': creatorId,
      'participants': participants,
      'isApprovalRequired': isApprovalRequired,
      'isApproved': isApproved,
      'imageUrl': imageUrl,
      'attendanceYes': attendanceYes,
      'attendanceNo': attendanceNo,
      'referanslar': referrals,
      'isPinned': isPinned,
      'isArchived': isArchived,
      'isAttendanceDutyChecked': isAttendanceDutyChecked,
      'quota': quota,
      'requirements': requirements,
      'trendingScore': trendingScore,
      'averageRating': averageRating,
      'latitude': latitude,
      'longitude': longitude,
      'externalLink': externalLink,
      'source': source,
      'qrCodeSecret': qrCodeSecret,
    };
  }
}
