import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String rules; // List<String> yerine String
  final List<String> moderators;
  final List<String> members;
  final List<String> restrictedMembers;
  final List<String> pinnedMessages;
  final String? icon;

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rules,
    required this.moderators,
    required this.members,
    required this.restrictedMembers,
    required this.pinnedMessages,
    this.icon,
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // Eski verilerle uyumluluk için: Eğer rules bir liste ise birleştir
    String rulesText = '';
    if (data['rules'] is List) {
      rulesText = (data['rules'] as List).join('\n');
    } else {
      rulesText = data['rules'] ?? '';
    }

    return CommunityModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      rules: rulesText,
      moderators: List<String>.from(data['moderators'] ?? []),
      members: List<String>.from(data['members'] ?? []),
      restrictedMembers: List<String>.from(data['restrictedMembers'] ?? []),
      pinnedMessages: List<String>.from(data['pinnedMessages'] ?? []),
      icon: data['icon'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'rules': rules,
      'moderators': moderators,
      'members': members,
      'restrictedMembers': restrictedMembers,
      'pinnedMessages': pinnedMessages,
      'icon': icon,
    };
  }
}
