


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../../services/gemini_service.dart';
import '../../services/notification_service.dart';
import '../auth/auth_provider.dart';
import '../communication/child_gallery_screen.dart';
import '../communication/family_room_screen.dart';
import '../donation/donation_form_screen.dart';
import '../home/home_screen.dart';
import '../reports/progress_feed_screen.dart';
import '../schedule/schedule_screen.dart';

class ChildDetailScreen extends StatefulWidget {
  final Map<String, dynamic> childData;

  const ChildDetailScreen({super.key, required this.childData});

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  int _selectedPackageIndex = 0;
  bool _isSponsoredByMe = false;
  int _myTotalDonation = 0;
  List<Map<String, dynamic>> _myDonations = [];
  List<Map<String, dynamic>> _childReports = [];
  List<Map<String, dynamic>> _childWishlists = [];
  List<Map<String, dynamic>> _childReceipts = [];
  String? _childDream;
  String? _childHobby;

  final List<Map<String, dynamic>> _packages = [
    {
      'id': 'pkg_pendidikan',
      'name': 'Paket Pendidikan Cemerlang',
      'desc': 'Buku pelajaran, seragam sekolah, tas, sepatu, dan uang SPP.',
      'monthly_idr': 250000,
    },
    {
      'id': 'pkg_harian',
      'name': 'Paket Nutrisi & Harian',
      'desc': 'Kebutuhan makan bergizi 3x sehari, susu berkalsium, dan vitamin.',
      'monthly_idr': 150000,
    },
    {
      'id': 'pkg_lengkap',
      'name': 'Paket Asuh Komprehensif',
      'desc': 'Mencakup seluruh biaya pendidikan, nutrisi, bimbingan belajar, & kesehatan.',
      'monthly_idr': 400000,
    },
  ];

  @override
  void initState() {
    super.initState();
    HomeScreen.refreshNotifier.addListener(_checkSponsorshipStatus);
    _checkSponsorshipStatus();
  }

  @override
  void dispose() {
    HomeScreen.refreshNotifier.removeListener(_checkSponsorshipStatus);
    super.dispose();
  }

  Future<void> _checkSponsorshipStatus() async {
    try {
      final childAlias = (widget.childData['alias'] ?? widget.childData['name'] ?? '').toString().trim().toLowerCase();
      final childId = (widget.childData['id'] ?? '').toString().trim().toLowerCase();
      final localDonations = await LocalDatabase().getCachedDonations();
      int total = 0;
      final matched = <Map<String, dynamic>>[];

      String myEmail = '';
      String myName = '';
      if (!mounted) return;
      try {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        myEmail = auth.userEmail.toLowerCase().trim();
        myName = auth.userName.toLowerCase().trim();
      } catch (_) {}

      for (var d in localDonations) {
        final dEmail = (d['donor_email'] ?? '').toString().toLowerCase().trim();
        final dName = (d['donor_name'] ?? '').toString().toLowerCase().trim();
        final isMyDonation = (myEmail.isNotEmpty && dEmail == myEmail) ||
            (myName.isNotEmpty && (dName == myName || dName == myEmail));
        final dAlias = (d['child_alias'] ?? '').toString().trim().toLowerCase();
        final dChildId = (d['child_id'] ?? '').toString().trim().toLowerCase();
        final isChildMatch = (dAlias.isNotEmpty && dAlias == childAlias) ||
            (childId.isNotEmpty && (dChildId == childId || dAlias == childId));
        if (isMyDonation && isChildMatch) {
          matched.add(d);
          final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
          total += amt;
        }
      }

      // Sinkronkan cita-cita & hobi dari inputan admin jika belum ada di widget.childData
      try {
        final newKids = await LocalDatabase().getNewChildren();
        final match = newKids.firstWhere(
          (k) => (k['name'] ?? k['alias'] ?? '').toString().trim().toLowerCase() == childAlias,
          orElse: () => {},
        );
        if (match.isNotEmpty) {
          if (match['dream'] != null && match['dream'].toString().trim().isNotEmpty) {
            _childDream = match['dream'].toString().trim();
          }
          if (match['hobby'] != null && match['hobby'].toString().trim().isNotEmpty) {
            _childHobby = match['hobby'].toString().trim();
          }
        }
      } catch (_) {}

      List<Map<String, dynamic>> loadedReports = [];
      try {
        final repRes = await DioClient().dio.get('/reports', queryParameters: {
          if (childId.isNotEmpty) 'child_id': widget.childData['id'],
        });
        if (repRes.statusCode == 200 && repRes.data is Map && repRes.data['data'] is List) {
          loadedReports = List<Map<String, dynamic>>.from(
            (repRes.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
          if (loadedReports.isNotEmpty) {
            await LocalDatabase().cacheProgressReports(loadedReports);
          }
        }
      } catch (_) {}
      if (loadedReports.isEmpty) {
        try {
          loadedReports = await LocalDatabase().getCachedProgressReports(
            childId: widget.childData['id']?.toString(),
            childAlias: (widget.childData['alias'] ?? widget.childData['name'])?.toString(),
          );
        } catch (_) {}
      }

      List<Map<String, dynamic>> loadedWishlists = [];
      try {
        final wlRes = await DioClient().dio.get('/wishlists', queryParameters: {
          if (childId.isNotEmpty) 'child_id': widget.childData['id'],
        });
        if (wlRes.statusCode == 200 && wlRes.data is Map && wlRes.data['data'] is List) {
          loadedWishlists = List<Map<String, dynamic>>.from(
            (wlRes.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
          );
          if (loadedWishlists.isNotEmpty) {
            await LocalDatabase().cacheWishlists(loadedWishlists);
          }
        }
      } catch (_) {}
      if (loadedWishlists.isEmpty) {
        try {
          loadedWishlists = await LocalDatabase().getCachedWishlists(
            childId: widget.childData['id']?.toString(),
            childAlias: (widget.childData['alias'] ?? widget.childData['name'])?.toString(),
          );
        } catch (_) {}
      }

      List<Map<String, dynamic>> loadedReceipts = [];
      if (matched.isNotEmpty) {
        try {
          final allReceipts = await LocalDatabase().getReceipts();
          loadedReceipts = allReceipts.where((r) {
            final rName = (r['childName'] ?? '').toString().trim().toLowerCase();
            return rName == childAlias || (childId.isNotEmpty && rName == childId);
          }).toList();
        } catch (_) {}

        final rawBirth = (widget.childData['birth_date'] ?? '').toString().trim();
        final parsedBirth = DateTime.tryParse(rawBirth);
        if (parsedBirth != null) {
          try {
            await NotificationService().scheduleChildBirthdayReminder(
              childId: childId.isNotEmpty ? childId : childAlias,
              childAlias: (widget.childData['alias'] ?? widget.childData['name'] ?? 'Anak Asuh').toString(),
              birthDate: parsedBirth,
            );
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _isSponsoredByMe = matched.isNotEmpty;
          _myTotalDonation = total;
          _myDonations = matched;
          // PBI 1: load semua reports (bukan cuma 3) agar status harian selalu tampil
          _childReports = loadedReports;
          // PBI 2: filter wishlist deleted
          _childWishlists = loadedWishlists
              .where((w) => (w['status'] ?? 'open').toString() != 'deleted')
              .toList();
          _childReceipts = loadedReceipts;
        });
      }
    } catch (_) {}
  }

  String _formatRupiah(num value) {
    return 'Rp ${value.toInt().toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}';
  }

  // PBI 1: Banner status harian terbaru dari admin
  Widget _buildDailyStatusBanner(String alias) {
    // Cari report terbaru yang punya daily_status tidak kosong
    final reportWithStatus = _childReports.firstWhere(
      (r) => (r['daily_status'] ?? '').toString().trim().isNotEmpty,
      orElse: () => {},
    );
    if (reportWithStatus.isEmpty) return const SizedBox.shrink();

    final statusText = reportWithStatus['daily_status'].toString().trim();
    final category = (reportWithStatus['category'] ?? 'Kegiatan').toString();
    final rawDate = (reportWithStatus['created_at'] ?? '').toString();
    String dateLabel = '';
    try {
      final dt = DateTime.parse(rawDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) {
        dateLabel = 'Hari ini';
      } else if (diff.inDays == 1) {
        dateLabel = 'Kemarin';
      } else if (diff.inDays < 7) {
        dateLabel = '${diff.inDays} hari lalu';
      } else {
        dateLabel = '${dt.day}/${dt.month}/${dt.year}';
      }
    } catch (_) {}

    final categoryColors = <String, Color>{
      'Prestasi': const Color(0xFF1565C0),
      'Karya Anak': const Color(0xFF6A1B9A),
      'Kesehatan': const Color(0xFF2E7D32),
      'Kegiatan': const Color(0xFFE65100),
    };
    final chipColor = categoryColors[category] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [chipColor.withValues(alpha: 0.08), chipColor.withValues(alpha: 0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: chipColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.campaign_outlined, color: chipColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: chipColor),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(Map<String, dynamic> child) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.card_giftcard_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Kebutuhan Spesifik Mendesak (Wishlist)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            if (_childWishlists.isEmpty)
              const Text(
                'Belum ada daftar kebutuhan spesifik mendesak saat ini.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else
              Column(
                children: _childWishlists.map((w) {
                  final itemName = (w['item_name'] ?? 'Kebutuhan Anak').toString();
                  final est = (w['estimated_idr'] is num)
                      ? (w['estimated_idr'] as num).toDouble()
                      : double.tryParse(w['estimated_idr']?.toString() ?? '0') ?? 0.0;
                  final status = (w['status'] ?? 'open').toString();
                  final statusLabel = status == 'fulfilled'
                      ? 'Sudah Disalurkan'
                      : status == 'funded'
                          ? 'Terpenuhi Donatur'
                          : 'Butuh Dukungan';
                  final statusColor = status == 'fulfilled'
                      ? Colors.green
                      : status == 'funded'
                          ? Colors.blue
                          : Colors.orange;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(itemName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                statusLabel,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Estimasi: ${_formatRupiah(est)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                        ),
                        if (status == 'open') ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DonationFormScreen(
                                      childData: child,
                                      packageData: {
                                        'id': 'pkg_wishlist',
                                        'name': 'Wishlist: $itemName',
                                        'monthly_idr': est,
                                      },
                                      wishlistItem: w,
                                    ),
                                  ),
                                );
                                await _checkSponsorshipStatus();
                              },
                              icon: const Icon(Icons.volunteer_activism, size: 16),
                              label: const Text('Penuhi Kebutuhan Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptsCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jejak Penyaluran Dana',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            if (_childReceipts.isEmpty)
              const Text(
                'Nota/bukti penyaluran dana dari pengurus panti akan tampil di sini setelah dana dibelanjakan.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else
              Column(
                children: _childReceipts.map((r) {
                  final imgRaw = (r['receiptImage'] ?? '').toString().trim();
                  Widget thumb = const Icon(Icons.receipt, color: AppColors.primary, size: 28);
                  if (imgRaw.startsWith('data:image')) {
                    try {
                      final bytes = base64Decode(imgRaw.split(',').last);
                      thumb = ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(bytes, width: 48, height: 48, fit: BoxFit.cover),
                      );
                    } catch (_) {}
                  }
                  final amt = (r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        thumb,
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text((r['title'] ?? 'Penyaluran Dana').toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(
                                '${_formatRupiah(amt)} • ${(r['date'] ?? '').toString()}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                              ),
                              if ((r['description'] ?? '').toString().isNotEmpty)
                                Text(r['description'].toString(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showQuickPrayerSheet(String alias, String childId) async {
    final controller = TextEditingController();
    final presets = [
      'Tetap semangat belajarnya ya $alias! 🎒',
      'Semoga $alias sehat selalu dan makin berprestasi! 🌟',
      'Kakak doakan cita-cita $alias segera tercapai. Aamiin 🤲',
    ];
    bool isGeneratingAi = false;

    String donorName = 'Donatur Asuh';
    try {
      donorName = Provider.of<AuthProvider>(context, listen: false).userName;
    } catch (_) {}

    final messageToSend = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sCtx) => StatefulBuilder(
        builder: (sCtx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sCtx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Kirim Doa / Semangat untuk $alias',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: presets.map((p) {
                    return ActionChip(
                      label: Text(p, style: const TextStyle(fontSize: 11)),
                      onPressed: () => controller.text = p,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Tulis Pesan Doa atau Dukungan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: isGeneratingAi
                          ? null
                          : () async {
                              setSheetState(() => isGeneratingAi = true);
                              final aiMsg = await GeminiService().generateLetter(
                                childAlias: alias,
                                topic: 'pesan doa dan semangat untuk $alias',
                                donorName: donorName,
                              );
                              if (sCtx.mounted) {
                                setSheetState(() {
                                  controller.text = aiMsg;
                                  isGeneratingAi = false;
                                });
                              }
                            },
                      icon: const Icon(Icons.auto_awesome, size: 16),
                      label: Text(isGeneratingAi ? 'Menyusun...' : 'Buat dengan AI', style: const TextStyle(fontSize: 12)),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(sCtx, controller.text.trim()),
                      icon: const Icon(Icons.send, size: 16),
                      label: const Text('Kirim ke Ruang Kasih', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();

    if (messageToSend == null || messageToSend.isEmpty) return;

    try {
      await LocalDatabase().insertChatMessage(
        childAlias: alias,
        sender: 'donor',
        text: messageToSend,
      );
    } catch (_) {}
    try {
      await DioClient().dio.post('/letters', data: {
        if (childId.isNotEmpty) 'child_id': childId,
        'child_alias': alias,
        'sender': 'donor',
        'text': messageToSend,
        'type': 'text',
      });
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Doa & semangat berhasil dikirim untuk $alias! 💛'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _activateBirthdayReminder(String alias, String childId, String rawBirthDate) async {
    final parsed = DateTime.tryParse(rawBirthDate);
    if (parsed == null) return;
    try {
      await NotificationService().scheduleChildBirthdayReminder(
        childId: childId.isNotEmpty ? childId : alias,
        childAlias: alias,
        birthDate: parsed,
      );
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengingat Ulang Tahun $alias (${parsed.day}/${parsed.month}) aktif! 🎂'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Widget _buildPrayerAndBirthdayCard(Map<String, dynamic> child, String alias) {
    final childId = (child['id'] ?? '').toString();
    final rawBirthDate = (child['birth_date'] ?? '').toString().trim();
    final hasBirthDate = rawBirthDate.isNotEmpty && DateTime.tryParse(rawBirthDate) != null;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.favorite_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Doa, Semangat & Momen Spesial',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () => _showQuickPrayerSheet(alias, childId),
              icon: const Icon(Icons.volunteer_activism, size: 18),
              label: const Text('Kirim Doa / Semangat', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (hasBirthDate) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _activateBirthdayReminder(alias, childId, rawBirthDate),
                icon: const Icon(Icons.cake_outlined, size: 18),
                label: Text('Pasang Pengingat Ulang Tahun ($rawBirthDate)', style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.childData;
    final alias = (child['alias'] ?? child['name'] ?? 'Anak Asuh').toString();
    final age = child['age'] ?? 8;
    final gender = child['gender'] ?? 'Laki-laki';
    final city = child['orphanage_city'] ?? child['city'] ?? 'Mataram, NTB';
    final orphanage = child['orphanage_name'] ?? 'Peduli Anak Foundation';
    final rawDream = _childDream ?? child['dream']?.toString();
    final rawHobby = _childHobby ?? child['hobby']?.toString();
    final dream = (rawDream != null && rawDream.trim().isNotEmpty && rawDream.trim() != '-') ? rawDream.trim() : null;
    final hobby = (rawHobby != null && rawHobby.trim().isNotEmpty && rawHobby.trim() != '-') ? rawHobby.trim() : null;
    final category = child['need_category'] ?? child['urgentNeeds'] ?? 'Pendidikan';
    final targetNum = (child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Profil $alias'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Kirim Pesan (Ruang Kasih)',
            icon: const Icon(Icons.chat_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Jadwalkan Video Call',
            icon: const Icon(Icons.video_call_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DonationFormScreen(
                      childData: child,
                      packageData: _packages[_selectedPackageIndex],
                    ),
                  ),
                );
                await _checkSponsorshipStatus();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.favorite),
              label: const Text(
                'Lanjut ke Form Donasi & Sertifikat',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: _buildAvatar(child),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alias,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usia: $age Tahun • $gender',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$orphanage ($city)',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // PBI 1: Banner status harian dari admin (muncul jika ada kabar terbaru)
            _buildDailyStatusBanner(alias),

            if (_isSponsoredByMe)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade50, Colors.orange.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.amber.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.workspace_premium, color: Colors.amber, size: 26),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '🌟 Anak Asuh Anda (Aktif Didampingi)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF8B6914)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Alhamdulillah! Anda tercatat sebagai Orang Tua Asuh resmi ananda $alias dengan akumulasi kontribusi ${_formatRupiah(_myTotalDonation)} (${_myDonations.length}x transaksi).',
                      style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FamilyRoomScreen()),
                              );
                            },
                            icon: const Icon(Icons.chat, size: 16),
                            label: const Text('Ruang Kasih', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ScheduleScreen()),
                              );
                            },
                            icon: const Icon(Icons.videocam, size: 16),
                            label: const Text('Video Call', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Data Lengkap & Biodata Anak', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const Divider(height: 20),
                          if (dream != null)
                            _buildDataRow(Icons.lightbulb_outline, 'Cita-Cita / Impian', dream),
                          if (hobby != null)
                            _buildDataRow(Icons.sports_soccer_outlined, 'Hobi & Minat', hobby),
                          _buildDataRow(Icons.location_on_outlined, 'Lokasi Panti', city),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),


                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_stories_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Cerita Kehidupan & Harapan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                          const Divider(height: 20),
                          Text(
                            child['story_summary'] ?? child['story'] ?? 'Anak yang rajin belajar, penuh semangat dan gemar menghafal doa serta giat membantu teman-temannya di panti asuhan.',
                            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.newspaper_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Jejak Perkembangan Terbaru',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProgressFeedScreen(
                                        filterChildId: child['id']?.toString(),
                                        filterChildAlias: alias,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Lihat Semua Kabar', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChildGalleryScreen(
                                      childId: (child['id'] ?? '').toString(),
                                      childAlias: alias,
                                      isAdmin: Provider.of<AuthProvider>(context, listen: false).isAdmin,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.photo_library_outlined, size: 16),
                              label: const Text('Lihat Galeri Karya', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const Divider(height: 16),
                          if (_childReports.isEmpty)
                            const Text(
                              'Belum ada kabar perkembangan terbaru untuk anak ini.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            )
                          else
                            Column(
                              children: _childReports.take(3).map((rep) {
                                final title = (rep['title'] ?? '').toString().isNotEmpty
                                    ? rep['title'].toString()
                                    : 'Kabar Terbaru';
                                final category = (rep['category'] ?? 'Kegiatan').toString();
                                final summary = (rep['summary'] ?? '').toString();
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                      if (summary.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildPrayerAndBirthdayCard(child, alias),
                  const SizedBox(height: 16),

                  _buildWishlistCard(child),
                  if (_isSponsoredByMe) ...[
                    const SizedBox(height: 16),
                    _buildReceiptsCard(),
                  ],
                  const SizedBox(height: 16),

                  Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pie_chart_outline, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Target Pemenuhan Kebutuhan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    category.toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Target Dana Kebutuhan:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                              Text(_formatRupiah(targetNum), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: targetNum > 0 ? (_myTotalDonation / targetNum).clamp(0.0, 1.0) : 0.0,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Terkumpul: ${_formatRupiah(_myTotalDonation)} (${targetNum > 0 ? ((_myTotalDonation / targetNum) * 100).toInt() : 0}%)',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),


                  const Text(
                    'Pilih Paket Sponsorship Orang Tua Asuh',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Dukungan Anda disalurkan secara transparan dengan bukti penyaluran resmi panti.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _packages.length,
                    itemBuilder: (context, idx) {
                      final pkg = _packages[idx];
                      final isSelected = _selectedPackageIndex == idx;

                      return Card(
                        elevation: isSelected ? 3 : 1,
                        color: isSelected ? AppColors.surfaceLight : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _selectedPackageIndex = idx),
                          child: Padding(
                            padding: const EdgeInsets.all(14.0),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        pkg['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        pkg['desc'],
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_formatRupiah(pkg['monthly_idr'])} / bulan',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> child) {
    final url = (child['avatar'] ?? child['photo'] ?? '').toString();
    if (url.startsWith('data:image')) {
      try {
        final bytes = Uri.parse(url).data?.contentAsBytes();
        if (bytes != null) return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: Colors.white, child: const Icon(Icons.face, size: 64, color: AppColors.primary)));
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.white,
          child: const Icon(Icons.face, size: 64, color: AppColors.primary),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: const Icon(Icons.face, size: 64, color: AppColors.primary),
    );
  }
}
