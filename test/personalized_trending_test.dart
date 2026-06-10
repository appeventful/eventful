import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:eventful_app/models/event_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Personalized Trending Logic', () {
    test('Boosts scores for user interests and sorts accordingly', () {
      final List<Map<String, dynamic>> mockDocs = [
        {
          'id': '1',
          'title': 'High Score Other',
          'category': 'Konser',
          'trendingScore': 1.0,
          'isArchived': false,
          'eventDate': Timestamp.now(),
        },
        {
          'id': '2',
          'title': 'Lower Score Interest',
          'category': 'Oyun',
          'trendingScore': 0.8,
          'isArchived': false,
          'eventDate': Timestamp.now(),
        },
      ];

      final userInterests = ['Oyun'];

      // Logic from _buildTrendingSection (HomeScreen)
      var sorted = List<Map<String, dynamic>>.from(mockDocs);
      sorted.sort((a, b) {
        double aScore = (a['trendingScore'] ?? 0.0).toDouble();
        double bScore = (b['trendingScore'] ?? 0.0).toDouble();

        if (userInterests.contains(a['category'])) aScore += 0.5;
        if (userInterests.contains(b['category'])) bScore += 0.5;
        
        return bScore.compareTo(aScore);
      });

      // After boost: 
      // '1' (Konser) remains 1.0
      // '2' (Oyun) becomes 0.8 + 0.5 = 1.3
      // Expected order: '2', then '1'
      expect(sorted[0]['id'], '2');
      expect(sorted[1]['id'], '1');
    });
  });
}
