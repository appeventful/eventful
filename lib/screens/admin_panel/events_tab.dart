import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

class EventsTab extends StatefulWidget {
  final UserModel? me;
  final bool isAdmin;
  final Function(String id, Map<String, dynamic> data) onShowEventOptions;
  final String initialFilter;
  final Function(String url)? launchUrl;
  final String? Function(String error)? extractIndexUrl;

  const EventsTab({
    super.key,
    required this.me,
    required this.isAdmin,
    required this.onShowEventOptions,
    this.initialFilter = 'Onay Bekleyenler',
    this.launchUrl,
    this.extractIndexUrl,
  });

  @override
  State<EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<EventsTab> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late String _eventStatusFilter;
  final Set<String> _selectedEventIds = {};
  bool _isBulkSelectionMode = false;
  String _adminSearchQuery = "";
  final TextEditingController _adminSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _eventStatusFilter = widget.initialFilter;
  }

  @override
  void dispose() {
    _adminSearchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EventsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _eventStatusFilter = widget.initialFilter;
        _selectedEventIds.clear();
        _isBulkSelectionMode = false;
      });
    }
  }

  void _bulkArchiveEvents() async {
    if (_selectedEventIds.isEmpty) return;
    final batch = _db.batch();
    for (var id in _selectedEventIds) {
      batch.update(_db.collection('events').doc(id), {'isArchived': true});
    }
    await batch.commit();
    if (!mounted) return;
    setState(() {
      _selectedEventIds.clear();
      _isBulkSelectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçili etkinlikler arşivlendi.')));
  }

  void _bulkDeleteEvents() async {
    if (_selectedEventIds.isEmpty) return;
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hepsini Sil'),
        content: Text('${_selectedEventIds.length} etkinliği silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SİL', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final batch = _db.batch();
      for (var id in _selectedEventIds) {
        batch.delete(_db.collection('events').doc(id));
      }
      await batch.commit();
      if (!mounted) return;
      setState(() {
        _selectedEventIds.clear();
        _isBulkSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçili etkinlikler silindi.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: _adminSearchController,
            decoration: InputDecoration(
              hintText: 'Etkinlik Ara (Başlık, Şehir, Kategori)',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _adminSearchQuery.isNotEmpty 
                ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () {
                    _adminSearchController.clear();
                    setState(() => _adminSearchQuery = "");
                  }) 
                : null,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _adminSearchQuery = v.trim().toLowerCase()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: ['Onay Bekleyenler', 'Aktif', 'Arşivlenmiş'].contains(_eventStatusFilter) ? _eventStatusFilter : 'Aktif',
                  items: ['Onay Bekleyenler', 'Aktif', 'Arşivlenmiş'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() {
                    _eventStatusFilter = v!;
                    _selectedEventIds.clear();
                    _isBulkSelectionMode = false;
                  }),
                ),
              ),
              if (_isBulkSelectionMode) ...[
                IconButton(icon: const Icon(Icons.archive), onPressed: _bulkArchiveEvents, tooltip: 'Hepsini Arşivle'),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _bulkDeleteEvents, tooltip: 'Hepsini Sil'),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _isBulkSelectionMode = false)),
              ] else
                TextButton(onPressed: () => setState(() => _isBulkSelectionMode = true), child: const Text('Toplu Seç')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _db.collection('events').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final errorStr = snapshot.error.toString();
                final indexUrl = widget.extractIndexUrl?.call(errorStr);
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning, color: Colors.orange, size: 48),
                        const SizedBox(height: 16),
                        const Text('Veri çekme hatası (İndeks gerekiyor olabilir)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (indexUrl != null && widget.launchUrl != null) 
                          ElevatedButton.icon(
                            onPressed: () => widget.launchUrl!(indexUrl), 
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Gerekli İndeksi Oluştur'),
                          )
                        else
                          Text(errorStr, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              
              var events = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                
                // Search filter
                if (_adminSearchQuery.isNotEmpty) {
                  String title = (data['title'] ?? '').toString().toLowerCase();
                  String city = (data['city'] ?? '').toString().toLowerCase();
                  String category = (data['category'] ?? '').toString().toLowerCase();
                  if (!title.contains(_adminSearchQuery) && !city.contains(_adminSearchQuery) && !category.contains(_adminSearchQuery)) {
                    return false;
                  }
                }

                if (widget.me?.isCityRepresentative == true && !widget.isAdmin) {
                   if ((data['city'] ?? '').toString().trim().toLowerCase() != widget.me!.responsibleCity?.trim().toLowerCase()) return false;
                }
                if (_eventStatusFilter == 'Onay Bekleyenler') return data['isApproved'] == false;
                if (_eventStatusFilter == 'Arşivlenmiş') return data['isArchived'] == true;
                return (data['isArchived'] != true) && (data['isApproved'] == true);
              }).toList();

              events.sort((a, b) {
                var aData = a.data() as Map<String, dynamic>;
                var bData = b.data() as Map<String, dynamic>;
                var aTime = aData['createdAt'] as Timestamp? ?? aData['eventDate'] as Timestamp?;
                var bTime = bData['createdAt'] as Timestamp? ?? bData['eventDate'] as Timestamp?;
                if (aTime == null || bTime == null) return 0;
                return bTime.compareTo(aTime);
              });

              if (events.isEmpty) return const Center(child: Text('Etkinlik bulunamadı.'));

              return ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  var doc = events[index];
                  var data = doc.data() as Map<String, dynamic>;
                  bool isSelected = _selectedEventIds.contains(doc.id);

                  return ListTile(
                    leading: _isBulkSelectionMode 
                      ? Checkbox(value: isSelected, onChanged: (v) {
                          setState(() {
                            if (v == true) _selectedEventIds.add(doc.id);
                            else _selectedEventIds.remove(doc.id);
                          });
                        })
                      : (data['imageUrl'] != null ? Image.network(data['imageUrl'], width: 40, height: 40, fit: BoxFit.cover) : const Icon(Icons.event)),
                    title: Text(data['title'] ?? 'Başlıksız', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: Text("${data['city'] ?? ''} - ${data['category'] ?? ''}", style: const TextStyle(fontSize: 12)),
                    trailing: data['isPinned'] == true ? const Icon(Icons.push_pin, color: Colors.blue, size: 16) : const Icon(Icons.chevron_right),
                    onTap: () {
                      if (_isBulkSelectionMode) {
                        setState(() {
                          if (isSelected) _selectedEventIds.remove(doc.id);
                          else _selectedEventIds.add(doc.id);
                        });
                      } else {
                        widget.onShowEventOptions(doc.id, data);
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
