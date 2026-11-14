import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../auth/auth_provider.dart';

class ProgressFeedScreen extends StatefulWidget {
  final String? filterChildId;
  final String? filterChildAlias;
  final List<Map<String, dynamic>>? initialReports;

  const ProgressFeedScreen({
    super.key,
    this.filterChildId,
    this.filterChildAlias,
    this.initialReports,
  });

  @override
  State<ProgressFeedScreen> createState() => _ProgressFeedScreenState();
}

class _ProgressFeedScreenState extends State<ProgressFeedScreen> {
  final LocalDatabase _localDb = LocalDatabase();
  List<Map<String, dynamic>> _reports = [];
  Set<String> _sponsoredAliases = {};
  Set<String> _sponsoredIds = {};
  bool _isLoading = true;
  bool _onlyMyChildren = false;
  String _selectedCategory = 'Semua';

  static const List<String> _categories = [
    'Semua',
    'Prestasi',
    'Karya Anak',
    'Kesehatan',
    'Kegiatan',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialReports != null) {
      _reports = List<Map<String, dynamic>>.from(widget.initialReports!);
      _isLoading = false;
    } else {
      _loadFeed();
    }
  }

  @override
  void didUpdateWidget(covariant ProgressFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialReports != oldWidget.initialReports && widget.initialReports != null) {
      _reports = List<Map<String, dynamic>>.from(widget.initialReports!);
      _isLoading = false;
    }
  }

  Future<void> _loadFeed() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userEmail = auth.userEmail.toLowerCase().trim();
      final userName = auth.userName.toLowerCase().trim();
      final donations = await _localDb.getCachedDonations();

      final aliases = <String>{};
      final ids = <String>{};
      for (final d in donations) {
        final dEmail = (d['donor_email'] ?? '').toString().toLowerCase().trim();
        final dName = (d['donor_name'] ?? '').toString().toLowerCase().trim();
        final matchesUser = (userEmail.isNotEmpty && dEmail == userEmail) ||
            (userName.isNotEmpty && (dName == userName || dName == userEmail));
        if (matchesUser || donations.isNotEmpty && userEmail.isEmpty) {
          final alias = (d['child_alias'] ?? '').toString().trim().toLowerCase();
          final cid = (d['child_id'] ?? '').toString().trim();
          if (alias.isNotEmpty) aliases.add(alias);
          if (cid.isNotEmpty) ids.add(cid);
        }
      }
      _sponsoredAliases = aliases;
      _sponsoredIds = ids;
    } catch (_) {}

    List<Map<String, dynamic>> loaded = [];
    try {
      final queryParams = <String, dynamic>{};
      if (widget.filterChildId != null && widget.filterChildId!.isNotEmpty) {
        queryParams['child_id'] = widget.filterChildId;
      }
      final res = await DioClient().dio.get('/reports', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data is Map && res.data['data'] is List) {
        loaded = List<Map<String, dynamic>>.from(
          (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        if (loaded.isNotEmpty) {
          await _localDb.cacheProgressReports(loaded);
        }
      }
    } catch (_) {}

    if (loaded.isEmpty) {
      try {
        loaded = await _localDb.getCachedProgressReports(
          childId: widget.filterChildId,
          childAlias: widget.filterChildAlias,
        );
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _reports = loaded;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    return _reports.where((r) {
      if (widget.filterChildId != null && widget.filterChildId!.isNotEmpty) {
        final cid = (r['child_id'] ?? '').toString().trim();
        final cAlias = (r['child_alias'] ?? '').toString().trim().toLowerCase();
        final targetAlias = (widget.filterChildAlias ?? '').trim().toLowerCase();
        final matchChild = cid == widget.filterChildId ||
            (targetAlias.isNotEmpty && cAlias == targetAlias);
        if (!matchChild) return false;
      } else if (widget.filterChildAlias != null && widget.filterChildAlias!.isNotEmpty) {
        final cAlias = (r['child_alias'] ?? '').toString().trim().toLowerCase();
        if (cAlias != widget.filterChildAlias!.trim().toLowerCase()) return false;
      }

      if (_onlyMyChildren) {
        final cid = (r['child_id'] ?? '').toString().trim();
        final cAlias = (r['child_alias'] ?? '').toString().trim().toLowerCase();
        if (!_sponsoredIds.contains(cid) && !_sponsoredAliases.contains(cAlias)) {
          return false;
        }
      }

      if (_selectedCategory != 'Semua') {
        final cat = (r['category'] ?? '').toString();
        if (cat != _selectedCategory) return false;
      }
      return true;
    }).toList();
  }

  Uint8List? _tryDecodeBase64(String raw) {
    if (raw.isEmpty) return null;
    try {
      final clean = raw.contains(',') ? raw.split(',').last : raw;
      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }

  Widget _buildEvidenceImage(String url, {double height = 180}) {
    if (url.trim().isEmpty) return const SizedBox.shrink();
    if (url.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }
    final bytes = _tryDecodeBase64(url);
    if (bytes == null || bytes.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Prestasi':
        return Colors.amber.shade800;
      case 'Karya Anak':
        return Colors.purple.shade700;
      case 'Kesehatan':
        return Colors.teal.shade700;
      default:
        return AppColors.primary;
    }
  }

  void _showReportDetail(Map<String, dynamic> report) {
    final childAlias = (report['child_alias'] ?? 'Anak Asuh').toString();
    final title = (report['title'] ?? '').toString().isNotEmpty
        ? report['title'].toString()
        : 'Kabar Perkembangan $childAlias';
    final category = (report['category'] ?? 'Kegiatan').toString();
    final summary = (report['summary'] ?? '').toString();
    final evidenceUrl = (report['evidence_url'] ?? '').toString();
    final author = (report['author_name'] ?? 'Pengurus Panti').toString();
    final period = (report['period'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _categoryColor(category).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: _categoryColor(category),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (period.isNotEmpty)
                    Text(
                      period,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Untuk: $childAlias • Ditulis oleh $author',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              if (evidenceUrl.isNotEmpty) ...[
                _buildEvidenceImage(evidenceUrl, height: 220),
                const SizedBox(height: 14),
              ],
              Text(
                summary,
                style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredReports;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.filterChildAlias != null
              ? 'Kabar ${widget.filterChildAlias}'
              : 'Kabar Perkembangan Anak',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeed,
        child: Column(
          children: [
            if (widget.filterChildId == null && widget.filterChildAlias == null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Semua Anak'),
                      selected: !_onlyMyChildren,
                      onSelected: (_) => setState(() => _onlyMyChildren = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Anak Asuh Saya'),
                      selected: _onlyMyChildren,
                      onSelected: (_) => setState(() => _onlyMyChildren = true),
                    ),
                  ],
                ),
              ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final selected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: selected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.18),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            Icon(Icons.auto_stories_outlined, size: 56, color: Colors.grey),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'Belum ada kabar perkembangan anak.',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                              ),
                            ),
                            SizedBox(height: 6),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Cerita prestasi, karya, dan aktivitas terbaru dari panti akan muncul di sini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            final title = (item['title'] ?? '').toString().isNotEmpty
                                ? item['title'].toString()
                                : 'Kabar Terbaru';
                            final category = (item['category'] ?? 'Kegiatan').toString();
                            final childAlias = (item['child_alias'] ?? 'Anak Asuh').toString();
                            final summary = (item['summary'] ?? '').toString();
                            final evidenceUrl = (item['evidence_url'] ?? '').toString();
                            final period = (item['period'] ?? '').toString();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 1.5,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showReportDetail(item),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _categoryColor(category).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              category,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _categoryColor(category),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            childAlias,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryDark,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (period.isNotEmpty)
                                            Text(
                                              period,
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        summary,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (evidenceUrl.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        _buildEvidenceImage(evidenceUrl, height: 150),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
