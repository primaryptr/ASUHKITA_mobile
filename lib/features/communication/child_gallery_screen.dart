import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';

class ChildGalleryScreen extends StatefulWidget {
  final String childId;
  final String childAlias;
  final bool isAdmin;
  final List<Map<String, dynamic>>? initialItems;

  const ChildGalleryScreen({
    super.key,
    required this.childId,
    required this.childAlias,
    this.isAdmin = false,
    this.initialItems,
  });

  @override
  State<ChildGalleryScreen> createState() => _ChildGalleryScreenState();
}

class _ChildGalleryScreenState extends State<ChildGalleryScreen> {
  final LocalDatabase _localDb = LocalDatabase();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null) {
      _items = List<Map<String, dynamic>>.from(widget.initialItems!);
      _isLoading = false;
    } else {
      _loadGallery();
    }
  }

  @override
  void didUpdateWidget(covariant ChildGalleryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != oldWidget.initialItems && widget.initialItems != null) {
      _items = List<Map<String, dynamic>>.from(widget.initialItems!);
      _isLoading = false;
    }
  }

  Future<void> _loadGallery() async {
    if (mounted) setState(() => _isLoading = true);

    final List<Map<String, dynamic>> merged = [];
    final Set<String> seenUrls = {};

    void addItem({
      required String id,
      required String title,
      required String imageUrl,
      required String source,
      required String createdAt,
      String summary = '',
    }) {
      final cleanUrl = imageUrl.trim();
      if (cleanUrl.isEmpty) return;
      if (seenUrls.contains(cleanUrl)) return;
      seenUrls.add(cleanUrl);
      merged.add({
        'id': id,
        'title': title.isNotEmpty ? title : 'Karya ${widget.childAlias}',
        'image_url': cleanUrl,
        'source': source,
        'summary': summary,
        'created_at': createdAt,
      });
    }

    // 1. Ambil dari Progress Reports (API + cache SQLite)
    List<Map<String, dynamic>> reports = [];
    try {
      final res = await DioClient().dio.get('/reports', queryParameters: {
        if (widget.childId.isNotEmpty) 'child_id': widget.childId,
        'only_gallery': 'true',
      });
      if (res.statusCode == 200 && res.data is Map && res.data['data'] is List) {
        reports = List<Map<String, dynamic>>.from(
          (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
      }
    } catch (_) {}

    if (reports.isEmpty) {
      try {
        reports = await _localDb.getCachedProgressReports(
          childId: widget.childId,
          childAlias: widget.childAlias,
        );
      } catch (_) {}
    }

    for (final r in reports) {
      final url = (r['evidence_url'] ?? '').toString().trim();
      if (url.isNotEmpty) {
        addItem(
          id: r['id']?.toString() ?? '',
          title: (r['title'] ?? '').toString(),
          imageUrl: url,
          source: 'Kabar & Prestasi',
          summary: (r['summary'] ?? '').toString(),
          createdAt: (r['created_at'] ?? '').toString(),
        );
      }
    }

    // 2. Ambil dari Ruang Kasih chat_messages lokal + /letters?is_gallery_item=true
    try {
      final chatRows = await _localDb.getChatMessages(widget.childAlias);
      for (final msg in chatRows) {
        final msgType = (msg['type'] ?? 'text').toString();
        final url = (msg['file_url'] ?? '').toString().trim();
        if (msgType == 'file' && url.isNotEmpty) {
          addItem(
            id: 'chat_${msg['id'] ?? ''}',
            title: (msg['text'] ?? '').toString().replaceAll('📎 ', ''),
            imageUrl: url,
            source: 'Ruang Kasih',
            createdAt: (msg['created_at'] ?? '').toString(),
          );
        }
      }
    } catch (_) {}

    try {
      final letRes = await DioClient().dio.get('/letters', queryParameters: {
        if (widget.childId.isNotEmpty) 'child_id': widget.childId,
        'is_gallery_item': 'true',
      });
      if (letRes.statusCode == 200 && letRes.data is Map && letRes.data['data'] is List) {
        for (final raw in (letRes.data['data'] as List)) {
          final l = Map<String, dynamic>.from(raw as Map);
          final url = (l['file_url'] ?? '').toString().trim();
          if (url.isNotEmpty) {
            addItem(
              id: 'let_${l['id'] ?? ''}',
              title: (l['content'] ?? '').toString(),
              imageUrl: url,
              source: 'Ruang Kasih',
              createdAt: (l['created_at'] ?? '').toString(),
            );
          }
        }
      }
    } catch (_) {}

    merged.sort((a, b) => (b['created_at'] ?? '').toString().compareTo((a['created_at'] ?? '').toString()));

    if (mounted) {
      setState(() {
        _items = merged;
        _isLoading = false;
      });
    }
  }

  Uint8List? _decodeBase64(String raw) {
    try {
      final clean = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
        ),
      );
    }
    final bytes = _decodeBase64(url);
    if (bytes == null || bytes.isEmpty) {
      return const Center(
        child: Icon(Icons.photo_outlined, color: Colors.grey, size: 32),
      );
    }
    return Image.memory(
      bytes,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.grey, size: 32),
      ),
    );
  }

  Future<void> _sendReaction(Map<String, dynamic> item) async {
    final title = (item['title'] ?? 'Karya').toString();
    final msgText = '❤️ Menyukai karya "$title" milik ${widget.childAlias}! Hebat sekali!';

    try {
      await _localDb.insertChatMessage(
        childAlias: widget.childAlias,
        sender: widget.isAdmin ? 'admin' : 'donor',
        text: msgText,
      );
    } catch (_) {}

    try {
      await DioClient().dio.post('/letters', data: {
        'child_id': widget.childId,
        'content': msgText,
        'sender_role': widget.isAdmin ? 'admin' : 'donor',
      });
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Apresiasi ❤️ untuk karya "$title" terkirim ke Ruang Kasih!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _openPreview(Map<String, dynamic> item) {
    final title = (item['title'] ?? 'Karya Anak').toString();
    final summary = (item['summary'] ?? '').toString();
    final source = (item['source'] ?? 'Galeri').toString();
    final url = (item['image_url'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(source, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 240,
                  child: _buildImage(url, fit: BoxFit.contain),
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendReaction(item);
                      },
                      icon: const Icon(Icons.favorite, size: 16),
                      label: const Text('Kirim ❤️'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pink.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Galeri Karya ${widget.childAlias}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 56, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          'Belum ada karya atau foto anak.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Foto hasil karya, gambar, atau momen kegiatan yang diunggah pengurus panti akan tersimpan rapi di sini.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, idx) {
                    final item = _items[idx];
                    final title = (item['title'] ?? 'Karya Anak').toString();
                    final source = (item['source'] ?? '').toString();
                    final url = (item['image_url'] ?? '').toString();

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                      child: InkWell(
                        onTap: () => _openPreview(item),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildImage(url),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    source,
                                    style: const TextStyle(fontSize: 10, color: AppColors.primaryDark),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
