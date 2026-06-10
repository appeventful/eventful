import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/shimmer_effect.dart';
import 'create_event_screen.dart';
import '../services/event_scraper_service.dart';
import '../services/auth_service.dart';

class ExternalEventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const ExternalEventDetailScreen({super.key, required this.event});

  @override
  State<ExternalEventDetailScreen> createState() => _ExternalEventDetailScreenState();
}

class _ExternalEventDetailScreenState extends State<ExternalEventDetailScreen> {
  bool _isEnriching = false;

  Future<void> _handleCreateEvent() async {
    setState(() => _isEnriching = true);
    try {
      final enrichedData = await EventScraperService.fetchFullEventDetails(widget.event['link']);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CreateEventScreen(
              prefillData: {
                ...widget.event,
                'description': enrichedData['description']?.isNotEmpty == true 
                    ? enrichedData['description'] 
                    : widget.event['description'],
                'location': enrichedData['fullAddress']?.isNotEmpty == true 
                    ? enrichedData['fullAddress'] 
                    : widget.event['location'],
                'latitude': widget.event['latitude'],
                'longitude': widget.event['longitude'],
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hata oluştu, lütfen tekrar deneyin.'))
        );
      }
    } finally {
      if (mounted) setState(() => _isEnriching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final dateStr = DateFormat('dd MMMM yyyy HH:mm', 'tr_TR').format(event['date']);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'event_image_${event['link']}',
                child: CachedNetworkImage(
                  imageUrl: event['imageUrl'],
                  fit: BoxFit.cover,
                  memCacheHeight: 800,
                  maxWidthDiskCache: 1200,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[200],
                    child: const ShimmerEffect(
                      child: Center(
                        child: Icon(Icons.image, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.orange.shade100,
                    child: const Icon(Icons.image, size: 100, color: Colors.orange),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          event['category'],
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 5),
                      Text(
                        AuthService().isGuest 
                          ? 'Görmek için üye ol' 
                          : dateStr, 
                        style: TextStyle(color: AuthService().isGuest ? Colors.orange : Colors.grey)
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    event['title'],
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event['location'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Etkinlik Hakkında',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event['description'] ?? 'Açıklama bulunmuyor.',
                    style: TextStyle(
                      fontSize: 15, 
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7) ?? Colors.grey,
                      height: 1.5
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => launchUrl(Uri.parse(event['link'])),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text('Bileti Gör / Detayları İncele', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: _isEnriching ? null : _handleCreateEvent,
                      icon: _isEnriching 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.event_available),
                      label: Text(_isEnriching ? 'Hazırlanıyor...' : 'Bunun İçin Etkinlik Oluştur'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
