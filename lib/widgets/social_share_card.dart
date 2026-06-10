import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import '../utils/constants.dart';
import '../services/auth_service.dart';

class SocialShareCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final GlobalKey boundaryKey;
  final bool isPost; // true: Square Post (1:1), false: Story (9:16)
  final String? customTag;
  final bool isWeeklySummary;
  final String theme; // 'classic', 'modern', 'neon', 'minimal'

  const SocialShareCard({
    super.key,
    required this.event,
    required this.boundaryKey,
    this.isPost = false,
    this.customTag,
    this.isWeeklySummary = false,
    this.theme = 'classic',
  });

  @override
  Widget build(BuildContext context) {
    final String title = event['title'] ?? 'Harika bir etkinlik!';
    final String city = event['city'] ?? 'Şehir belirtilmemiş';
    final String location = event['locationName'] ?? event['address'] ?? city;
    final String creatorName = event['creatorName'] ?? 'Düzenleyici';
    final int participantsCount = (event['participants'] as List?)?.length ?? 0;
    final String imageUrl = event['imageUrl'] ?? 'https://images.unsplash.com/photo-1501281668745-f7f57925c3b4?auto=format&fit=crop&w=800&q=80';
    
    DateTime date;
    if (event['eventDate'] != null) {
      var eventDate = event['eventDate'];
      if (eventDate is DateTime) {
        date = eventDate;
      } else if (eventDate is String) {
        date = DateTime.tryParse(eventDate) ?? DateTime.now();
      } else {
        // Assume it's a Timestamp from Firestore
        try {
          date = (eventDate as dynamic).toDate();
        } catch (e) {
          date = DateTime.now();
        }
      }
    } else {
      date = DateTime.now();
    }
    
    final String day = DateFormat('dd').format(date);
    String month;
    try {
      month = DateFormat('MMMM', 'tr_TR').format(date).toUpperCase();
    } catch (e) {
      month = "ETKİNLİK"; // Hata durumunda fallback
    }
    final String time = DateFormat('HH:mm').format(date);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth == double.infinity 
            ? 360.0 
            : constraints.maxWidth;
        
        final double width = maxWidth;
        final double height = isPost ? width : (width * 16 / 9);

        return RepaintBoundary(
          key: boundaryKey,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(isPost ? 15 : 20),
            ),
            child: _buildThemeContent(width, height, title, city, location, creatorName, participantsCount, imageUrl, day, month, time),
          ),
        );
      },
    );
  }

  Widget _buildThemeContent(double width, double height, String title, String city, String location, String creatorName, int participantsCount, String imageUrl, String day, String month, String time) {
    switch (theme) {
      case 'modern':
        return _buildModernTheme(width, height, title, city, location, creatorName, participantsCount, imageUrl, day, month, time);
      case 'neon':
        return _buildNeonTheme(width, height, title, city, location, creatorName, participantsCount, imageUrl, day, month, time);
      case 'minimal':
        return _buildMinimalTheme(width, height, title, city, location, creatorName, participantsCount, imageUrl, day, month, time);
      case 'classic':
      default:
        return _buildClassicTheme(width, height, title, city, location, creatorName, participantsCount, imageUrl, day, month, time);
    }
  }

  Widget _buildClassicTheme(double width, double height, String title, String city, String location, String creatorName, int participantsCount, String imageUrl, String day, String month, String time) {
    return Stack(
      children: [
        // Background Image with Gradient Overlay
        ClipRRect(
          borderRadius: BorderRadius.circular(isPost ? 15 : 20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: kDeepCharcoal,
                    child: const Center(child: CircularProgressIndicator(color: kPrimaryOrange)),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: kDeepCharcoal,
                  child: const Icon(Icons.broken_image, color: Colors.white54, size: 40),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kDeepCharcoal.withOpacity(0.2),
                      kDeepCharcoal.withOpacity(0.5),
                      kDeepCharcoal.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Content
        Padding(
          padding: EdgeInsets.all(isPost ? width * 0.045 : width * 0.065),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Branding
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.event_available, color: kPrimaryOrange, size: isPost ? width * 0.065 : width * 0.09),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'EVENTFUL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isPost ? width * 0.045 : width * 0.055,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (customTag != null) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimaryOrange,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        customTag!,
                        style: const TextStyle(color: kDeepCharcoal, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              
              const Spacer(),
              
              // Date Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AuthService().isGuest 
                  ? Text(
                      'ÜYE OL VE GÖR',
                      style: TextStyle(
                        color: kPrimaryOrange,
                        fontSize: isPost ? width * 0.028 : width * 0.033,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isPost ? width * 0.05 : width * 0.065,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          month,
                          style: TextStyle(
                            color: kPrimaryOrange,
                            fontSize: isPost ? width * 0.028 : width * 0.033,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
              ),
              
              SizedBox(height: isPost ? width * 0.033 : width * 0.055),
              
              // Title
              Text(
                title,
                maxLines: isPost ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isPost ? width * 0.065 : width * 0.09,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              
              SizedBox(height: isPost ? width * 0.028 : width * 0.045),
              
              // Location
              Row(
                children: [
                  Icon(Icons.location_on, color: kPrimaryOrange, size: isPost ? width * 0.04 : width * 0.05),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: isPost ? width * 0.036 : width * 0.045,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Time & City
              Row(
                children: [
                  Icon(Icons.access_time_filled, color: kPrimaryOrange, size: isPost ? width * 0.04 : width * 0.05),
                  const SizedBox(width: 4),
                  Text(
                    AuthService().isGuest ? 'Görmek için üye ol' : time,
                    style: TextStyle(color: Colors.white70, fontSize: isPost ? width * 0.036 : width * 0.045),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.location_city, color: kPrimaryOrange, size: isPost ? width * 0.04 : width * 0.05),
                  const SizedBox(width: 4),
                  Text(
                    city,
                    style: TextStyle(color: Colors.white70, fontSize: isPost ? width * 0.036 : width * 0.045),
                  ),
                ],
              ),
              
              SizedBox(height: isPost ? width * 0.033 : width * 0.055),
              
              // Creator and Participants
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, color: kPrimaryOrange, size: isPost ? width * 0.033 : width * 0.04),
                        const SizedBox(width: 4),
                        Text(
                          creatorName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isPost ? width * 0.03 : width * 0.036,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.groups, color: kPrimaryOrange, size: isPost ? width * 0.033 : width * 0.04),
                        const SizedBox(width: 4),
                        Text(
                          '$participantsCount Katılımcı',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isPost ? width * 0.03 : width * 0.036,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Call to Action
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: isPost ? width * 0.028 : width * 0.045),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryOrange, kPrimaryOrange.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(isPost ? 10 : 15),
                ),
                child: Center(
                  child: Text(
                    'Uygulamada Gör',
                    style: TextStyle(
                      color: kDeepCharcoal,
                      fontWeight: FontWeight.bold,
                      fontSize: isPost ? width * 0.038 : width * 0.045,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernTheme(double width, double height, String title, String city, String location, String creatorName, int participantsCount, String imageUrl, String day, String month, String time) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(isPost ? 15 : 20),
          child: Image.network(
            imageUrl, 
            fit: BoxFit.cover, 
            height: height, 
            width: width,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Colors.white,
                child: const Center(child: CircularProgressIndicator(color: kPrimaryOrange)),
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isPost ? 15 : 20),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.white, Colors.white.withOpacity(0.8), Colors.transparent],
              stops: const [0.0, 0.4, 0.7],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(color: kDeepCharcoal, fontSize: width * 0.08, fontWeight: FontWeight.w900, letterSpacing: -1),
              ),
              const SizedBox(height: 8),
              Container(height: 3, width: 40, color: kPrimaryOrange),
              const SizedBox(height: 12),
              Text(
                AuthService().isGuest ? "GÖRMEK İÇİN ÜYE OL" : "$day $month • $time",
                style: TextStyle(color: kDeepCharcoal, fontSize: width * 0.04, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                location,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: width * 0.035),
              ),
              const SizedBox(height: 20),
              CircleAvatar(
                backgroundColor: kPrimaryOrange,
                radius: 25,
                child: const Icon(Icons.arrow_forward, color: Colors.white),
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNeonTheme(double width, double height, String title, String city, String location, String creatorName, int participantsCount, String imageUrl, String day, String month, String time) {
    const neonColor = Color(0xFF00FF9D);
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(isPost ? 15 : 20),
        border: Border.all(color: neonColor, width: 4),
      ),
      child: Stack(
        children: [
          Opacity(
            opacity: 0.4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isPost ? 15 : 20),
              child: Image.network(
                imageUrl, 
                fit: BoxFit.cover, 
                height: height, 
                width: width,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("LIVE EVENT", style: TextStyle(color: neonColor, fontWeight: FontWeight.bold, fontSize: width * 0.04, letterSpacing: 4)),
                const Spacer(),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: width * 0.1,
                    fontWeight: FontWeight.w900,
                    shadows: const [Shadow(color: neonColor, blurRadius: 20)],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      AuthService().isGuest ? "ÜYE OL VE GÖR" : "$day $month", 
                      style: const TextStyle(color: neonColor, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(width: 10),
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: neonColor, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Text(
                      AuthService().isGuest ? "--:--" : time, 
                      style: const TextStyle(color: Colors.white)
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(location, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: width * 0.04)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalTheme(double width, double height, String title, String city, String location, String creatorName, int participantsCount, String imageUrl, String day, String month, String time) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                imageUrl, 
                fit: BoxFit.cover, 
                width: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: kPrimaryOrange));
                },
              ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AuthService().isGuest ? '?' : day, 
                    style: TextStyle(fontSize: width * 0.12, fontWeight: FontWeight.w300, color: kDeepCharcoal)
                  ),
                  Text(
                    AuthService().isGuest ? 'ÜYE OL VE GÖR' : month, 
                    style: TextStyle(fontSize: width * 0.05, fontWeight: FontWeight.bold, color: kPrimaryOrange, letterSpacing: AuthService().isGuest ? 1 : 5)
                  ),
                  const SizedBox(height: 15),
                  Text(title, style: TextStyle(fontSize: width * 0.06, fontWeight: FontWeight.w600, color: kDeepCharcoal)),
                  const Spacer(),
                  Text(location, style: TextStyle(fontSize: width * 0.035, color: Colors.grey)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

