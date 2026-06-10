import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/rating_service.dart';

class RatingScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  const RatingScreen({super.key, required this.eventId, required this.eventTitle});

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final RatingService _ratingService = RatingService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final Map<String, double> _scores = {};
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _alreadyRated = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final eventDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventId).get();
    final eventData = eventDoc.data() as Map<String, dynamic>? ?? {};
    List attended = eventData['attendanceYes'] ?? eventData['attended'] ?? [];
    String creatorId = eventData['creatorId'] ?? '';
    
    List<String> toRate = [];
    if (attended.contains(_currentUserId) || creatorId == _currentUserId) {
       // I can rate everyone else in attended list
       for (var uid in attended) {
         if (uid != _currentUserId) toRate.add(uid);
       }
       // If I am participant, I can rate creator
       if (creatorId != _currentUserId && !toRate.contains(creatorId)) {
         toRate.add(creatorId);
       }
    }

    for (var uid in toRate) {
      bool rated = await _ratingService.hasRatedUser(widget.eventId, _currentUserId!, uid);
      if (rated) _alreadyRated.add(uid);
      _scores[uid] = 5.0;
      _controllers[uid] = TextEditingController();
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.eventTitle} - Değerlendir'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('events').doc(widget.eventId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('Bir hata oluştu.'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              var eventData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              List attended = eventData['attendanceYes'] ?? eventData['attended'] ?? [];
              String creatorId = eventData['creatorId'] ?? '';

              List<String> targetIds = [];
              for (var uid in attended) {
                if (uid != _currentUserId) targetIds.add(uid);
              }
              if (creatorId != _currentUserId && !targetIds.contains(creatorId)) {
                targetIds.add(creatorId);
              }

              if (targetIds.isEmpty) {
                return const Center(child: Text('Değerlendirilecek kimse bulunamadı.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: targetIds.length,
                itemBuilder: (context, index) {
                  String targetId = targetIds[index];
                  bool isRated = _alreadyRated.contains(targetId);
                  bool isCreator = targetId == creatorId;

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(targetId).get(),
                    builder: (context, userSnap) {
                      if (userSnap.hasError || !userSnap.hasData || !userSnap.data!.exists) return const SizedBox.shrink();
                      var userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                      String name = userData['name'] ?? 'Kullanıcı';
                      String? img = userData['profileImage'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: (img != null && img.isNotEmpty) ? CachedNetworkImageProvider(img) : null,
                                    child: (img == null || img.isEmpty) ? const Icon(Icons.person) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        if (isCreator)
                                          const Text('Organizatör', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  if (isRated)
                                    const Icon(Icons.check_circle, color: Colors.green)
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (!isRated) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (starIndex) {
                                    return IconButton(
                                      icon: Icon(
                                        starIndex < _scores[targetId]! ? Icons.star : Icons.star_border,
                                        color: Colors.amber,
                                        size: 32,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _scores[targetId] = (starIndex + 1).toDouble();
                                        });
                                      },
                                    );
                                  }),
                                ),
                                TextField(
                                  controller: _controllers[targetId],
                                  decoration: const InputDecoration(
                                    hintText: 'Yorumunuzu yazın (opsiyonel)...',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _submitSingleRating(targetId),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                    child: const Text('Puanla'),
                                  ),
                                ),
                              ] else
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: Text('Bu kullanıcıyı oyladınız.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
    );
  }

  void _submitSingleRating(String targetId) async {
    try {
      await _ratingService.submitRating(
        eventId: widget.eventId,
        fromId: _currentUserId!,
        toId: targetId,
        score: _scores[targetId]!,
        comment: _controllers[targetId]?.text.trim(),
      );
      
      setState(() {
        _alreadyRated.add(targetId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Puanınız kaydedildi!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }
}
