

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/dio_client.dart';

import 'package:intl/intl.dart';

import '../../data/local_db.dart';
import '../../services/notification_service.dart';
import '../auth/auth_provider.dart';
import '../sponsor/sponsor_screen.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  DateTime _selectedDateTime = DateTime.now().add(
    const Duration(days: 1, hours: 2),
  );
  final _topicController = TextEditingController();

  List<String> _sponsoredChildren = [];
  List<Map<String, dynamic>> _schedules = [];
  String? _selectedChild;
  bool _isLoading = true;

  String _reportCategory = 'Laporan Kas & Belanja Bulanan';
  final List<String> _reportCategories = [
    'Laporan Kas & Belanja Bulanan',
    'Audit Bukti Belanja & Nota Transparansi',
    'Rekapitulasi Donasi Kebutuhan Anak',
    'Laporan Akuntabilitas Global (UK BST & Indonesia)',
    'Audit Tahunan Lembaga & On-Chain Ledger',
  ];
  String _reportTarget = 'Semua Anak Asuh & Operasional Panti';

  final Map<String, int> _zoneOffsets = {
    'WIB (Jakarta)': 7,
    'WITA (Makassar)': 8,
    'WIT (Jayapura)': 9,
    'London (UK)': 1,
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    List<Map<String, dynamic>> items = [];
    try {
      final res = await DioClient().dio.get('/orphanages/schedules');
      if (res.statusCode == 200 && res.data is Map && res.data['data'] is List) {
        items = List<Map<String, dynamic>>.from(
          (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        for (final s in items) {
          await LocalDatabase().upsertScheduleLocal(s);
        }
      }
    } catch (_) {}

    if (items.isEmpty) {
      try {
        items = await LocalDatabase().getCachedSchedules();
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _schedules = items);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final isAdmin = auth.userRole == 'admin_panti';

      if (isAdmin) {
        final cachedKids = await LocalDatabase().getCachedChildren();
        final newKids = await LocalDatabase().getNewChildren();
        final setNames = <String>{'Semua Anak Asuh & Operasional Panti'};
        for (var c in [...cachedKids, ...newKids]) {
          final name = (c['alias'] ?? c['name'] ?? '').toString().trim();
          if (name.isNotEmpty) {
            final formatted = name.length > 1
                ? '${name[0].toUpperCase()}${name.substring(1)}'
                : name;
            setNames.add(formatted);
          }
        }
        if (mounted) {
          setState(() {
            _sponsoredChildren = setNames.toList();
            _reportTarget = _sponsoredChildren.first;
          });
        }
      } else {
        final userEmail = auth.userEmail.toLowerCase().trim();
        final userName = auth.userName.toLowerCase().trim();
        final localDonations = await LocalDatabase().getCachedDonations();
        final childSet = <String>{};
        if (userEmail.isNotEmpty || userName.isNotEmpty) {
          for (var d in localDonations) {
            final dEmail = (d['donor_email'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            final dName = (d['donor_name'] ?? '')
                .toString()
                .toLowerCase()
                .trim();
            final isMatch =
                (userEmail.isNotEmpty && dEmail == userEmail) ||
                (userName.isNotEmpty &&
                    (dName == userName || dName == mySafeName(userEmail)));
            if (isMatch) {
              final alias = (d['child_alias'] ?? '').toString().trim();
              if (alias.isNotEmpty) {
                final formatted = alias.length > 1
                    ? '${alias[0].toUpperCase()}${alias.substring(1)}'
                    : alias;
                childSet.add(formatted);
              }
            }
          }
        }

        final list = childSet.toList();
        if (mounted) {
          setState(() {
            _sponsoredChildren = list;
            _selectedChild = list.isNotEmpty ? list.first : null;
          });
        }
      }
      await _loadSchedules();
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String mySafeName(String email) => email;

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  String _formatTimeInZone(int offsetHours) {
    final utc = _selectedDateTime.toUtc();
    final targetTime = utc.add(Duration(hours: offsetHours));
    return DateFormat('EEEE, dd MMM yyyy • HH:mm').format(targetTime);
  }

  Future<void> _saveScheduleAndShowPopup() async {
    if (!_selectedDateTime.isAfter(DateTime.now())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih waktu pengingat yang masih akan datang.'),
          ),
        );
      }
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isAdmin = auth.userRole == 'admin_panti';

    if (isAdmin) {
      final notes = _topicController.text.trim().isNotEmpty
          ? _topicController.text.trim()
          : 'Penyusunan nota belanja seragam, gizi, & rekonsiliasi kas masuk';

      final notifId =
          (_selectedDateTime.millisecondsSinceEpoch ~/ 1000) & 0x7fffffff;


      try {
        await NotificationService().scheduleFinanceReportReminder(
          id: notifId,
          reportCategory: _reportCategory,
          target: _reportTarget,
          scheduledDateTime: _selectedDateTime,
        );
      } catch (error) {
        debugPrint('[Schedule] Gagal memasang pengingat laporan: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Pengingat gagal dipasang. Periksa izin notifikasi dan alarm di Pengaturan Android.',
              ),
            ),
          );
        }
        return;
      }


      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: const [
                Icon(Icons.assessment, color: AppColors.primary, size: 28),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jadwal Laporan Keuangan Disetel!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Jadwal pengingat berhasil disetel!',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pengingat dijadwalkan pada waktu yang dipilih dan tetap aktif saat aplikasi ditutup biasa. Force stop atau pembatasan baterai dapat menunda notifikasi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Jenis: $_reportCategory',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.folder_shared,
                              size: 18,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Target: $_reportTarget',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.notes,
                              size: 18,
                              color: Colors.indigo,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Fokus: $notes',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Text(
                          '• WIB (Jakarta): ${_formatTimeInZone(7)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '• WITA (Makassar): ${_formatTimeInZone(8)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '• WIT (Jayapura): ${_formatTimeInZone(9)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        Text(
                          '• London (UK BST): ${_formatTimeInZone(1)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Icon(Icons.alarm_on, color: AppColors.primary, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Sistem alarm background Android aktif untuk jadwal ini.',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (Navigator.of(context).canPop()) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK, Mengerti'),
              ),
            ],
          ),
        );
      }
      return;
    }


    if (_sponsoredChildren.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Belum Memiliki Anak Asuh'),
          content: const Text(
            'Anda belum memiliki anak asuh yang didampingi. Silakan pilih anak asuh di menu Sponsor terlebih dahulu sebelum menjadwalkan panggilan video.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SponsorScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Buka Menu Sponsor'),
            ),
          ],
        ),
      );
      return;
    }

    final targetChild = _selectedChild ?? _sponsoredChildren.first;
    final topic = _topicController.text.trim().isNotEmpty
        ? _topicController.text.trim()
        : 'Sesi Belajar & Bincang Inspirasi Masa Depan';


    try {
      await NotificationService().scheduleVideoCallReminder(
        id: (_selectedDateTime.millisecondsSinceEpoch ~/ 1000) & 0x7fffffff,
        childAlias: targetChild,
        scheduledDateTime: _selectedDateTime,
      );
    } catch (error) {
      debugPrint('[Schedule] Gagal memasang pengingat video call: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pengingat gagal dipasang. Periksa izin notifikasi dan alarm di Pengaturan Android.',
            ),
          ),
        );
      }
      return;
    }

    final newSchedule = <String, dynamic>{
      'id': 'sch_${DateTime.now().millisecondsSinceEpoch}',
      'sponsorship_id': 'sp-seed-001',
      'child_alias': targetChild,
      'donor_name': auth.userName,
      'scheduled_at_utc': _selectedDateTime.toUtc().toIso8601String(),
      'donor_timezone': 'WIB',
      'status': 'scheduled',
      'notes': topic,
      'admin_notes': '',
      'created_at': DateTime.now().toIso8601String(),
    };
    try {
      final res = await DioClient().dio.post('/orphanages/schedules', data: {
        'sponsorship_id': 'sp-seed-001',
        'scheduled_at_utc': newSchedule['scheduled_at_utc'],
        'donor_timezone': 'Asia/Jakarta',
        'notes': topic,
      });
      if (res.statusCode == 201 && res.data is Map && res.data['data']?['schedule'] is Map) {
        newSchedule['id'] = res.data['data']['schedule']['id']?.toString() ?? newSchedule['id'];
      }
    } catch (_) {}
    await LocalDatabase().upsertScheduleLocal(newSchedule);
    if (mounted) {
      setState(() => _schedules.insert(0, newSchedule));
    }


    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(
                Icons.notifications_active,
                color: AppColors.primary,
                size: 28,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pengingat Berhasil Disetel!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Jadwal pengingat video call berhasil disetel!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pengingat dijadwalkan pada waktu yang dipilih dan tetap aktif saat aplikasi ditutup biasa. Force stop atau pembatasan baterai dapat menunda notifikasi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.face,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Anak Asuh: $targetChild',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.videocam,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Topik: $topic',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Text(
                        '• WIB (Jakarta): ${_formatTimeInZone(7)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '• WITA (Makassar): ${_formatTimeInZone(8)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• WIT (Jayapura): ${_formatTimeInZone(9)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        '• London (UK): ${_formatTimeInZone(1)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: const [
                    Icon(Icons.alarm_on, color: AppColors.primary, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Notifikasi alarm sistem Android akan berdering tepat waktu walau app tertutup.',
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK, Mengerti'),
            ),
          ],
        ),
      );
    }
  }

  Map<String, dynamic> _statusStyle(String status) {
    switch (status) {
      case 'approved':
        return {'label': 'Disetujui', 'color': Colors.green};
      case 'rescheduled':
        return {'label': 'Dijadwalkan Ulang', 'color': Colors.orange};
      case 'completed':
        return {'label': 'Selesai', 'color': Colors.blue};
      default:
        return {'label': 'Menunggu', 'color': Colors.amber.shade800};
    }
  }

  Future<void> _updateScheduleStatus(Map<String, dynamic> schedule, String nextStatus) async {
    final notesCtrl = TextEditingController(text: (schedule['admin_notes'] ?? '').toString());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Update Jadwal (${_statusStyle(nextStatus)['label']})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Catatan Pengurus Panti untuk Donatur',
            hintText: 'Contoh: Siap jam 17:00 WIB / tautan zoom disiapkan',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    final adminNotes = notesCtrl.text.trim();
    notesCtrl.dispose();
    if (confirmed != true) return;

    final id = (schedule['id'] ?? '').toString();
    if (id.isNotEmpty) {
      try {
        await DioClient().dio.patch('/orphanages/schedules/$id/status', data: {
          'status': nextStatus,
          'admin_notes': adminNotes,
        });
      } catch (_) {}
    }

    final updated = {
      ...schedule,
      'status': nextStatus,
      'admin_notes': adminNotes,
    };
    await LocalDatabase().upsertScheduleLocal(updated);
    if (mounted) {
      setState(() {
        final idx = _schedules.indexWhere((s) => s['id'] == schedule['id']);
        if (idx >= 0) _schedules[idx] = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status jadwal diperbarui menjadi ${_statusStyle(nextStatus)['label']}'), backgroundColor: AppColors.primary),
      );
    }
  }

  Widget _buildAdminQueueTab() {
    if (_schedules.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada pengajuan video call dari donatur.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _schedules.length,
      itemBuilder: (context, idx) {
        final s = _schedules[idx];
        final st = _statusStyle((s['status'] ?? 'scheduled').toString());
        final stColor = st['color'] as Color;
        final childName = (s['child_alias'] ?? 'Anak Asuh').toString();
        final donorName = (s['donor_name'] ?? 'Donatur').toString();
        final notes = (s['notes'] ?? '').toString();
        final adminNotes = (s['admin_notes'] ?? '').toString();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        childName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: stColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        st['label'] as String,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Donatur: $donorName', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('Waktu UTC: ${(s['scheduled_at_utc'] ?? '').toString()}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Topik: $notes', style: const TextStyle(fontSize: 12)),
                ],
                if (adminNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Catatan Panti: $adminNotes', style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton(
                      onPressed: () => _updateScheduleStatus(s, 'approved'),
                      child: const Text('Setujui', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton(
                      onPressed: () => _updateScheduleStatus(s, 'rescheduled'),
                      child: const Text('Jadwal Ulang', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton(
                      onPressed: () => _updateScheduleStatus(s, 'completed'),
                      child: const Text('Selesai', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool isAdmin = auth.userRole == 'admin_panti';
    final utcTime = _selectedDateTime.toUtc();

    final formBody = SafeArea(
      child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 48.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAdmin
                                ? 'Jadwal Pembuatan & Audit Laporan Keuangan'
                                : 'Pilih Waktu Video Call Ramah Anak',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isAdmin
                                ? 'Sinkronisasi tenggat waktu pembuatan dan audit laporan keuangan panti asuhan secara serentak ke 4 zona waktu (WIB, WITA, WIT, London BST) untuk transparansi donatur global & lokal.'
                                : 'Jadwal akan otomatis dikonversi ke 4 zona waktu (WIB, WITA, WIT, London) agar donatur lintas negara dapat berkoordinasi dengan tepat.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Divider(height: 24),

                          if (isAdmin) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _reportCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Jenis Laporan Keuangan',
                                prefixIcon: const Icon(
                                  Icons.receipt_long,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                helperText: 'Pilih agenda penyusunan laporan keuangan panti',
                              ),
                              items: _reportCategories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat,
                                  child: Text(
                                    cat,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _reportCategory = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _reportTarget,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Target Divisi / Anak Asuh',
                                prefixIcon: const Icon(
                                  Icons.people_alt_outlined,
                                  color: AppColors.secondary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                helperText:
                                    'Fokus anak asuh atau umum panti asuhan',
                              ),
                              items: _sponsoredChildren.map((t) {
                                return DropdownMenuItem<String>(
                                  value: t,
                                  child: Text(
                                    t,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _reportTarget = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _topicController,
                              decoration: InputDecoration(
                                labelText: 'Catatan / Fokus Audit Laporan',
                                hintText: 'Contoh: Rekapitulasi nota belanja seragam & audit gizi',
                                prefixIcon: const Icon(
                                  Icons.notes,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ] else ...[
                            if (_sponsoredChildren.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.amber.shade300,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Anda belum memiliki anak asuh. Buka menu Sponsor untuk memilih anak asuh terlebih dahulu.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_sponsoredChildren.length >= 2)
                              DropdownButtonFormField<String>(
                                initialValue: _selectedChild,
                                decoration: InputDecoration(
                                  labelText:
                                      'Pilih Anak Asuh (${_sponsoredChildren.length} Anak Asuh)',
                                  prefixIcon: const Icon(
                                    Icons.face,
                                    color: AppColors.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  helperText: 'Pilih salah satu anak asuh yang ingin Anda jadwalkan',
                                ),
                                items: _sponsoredChildren.map((name) {
                                  return DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedChild = val);
                                },
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.face,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Anak Asuh Terpilih',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          _selectedChild ??
                                              _sponsoredChildren.first,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Chip(
                                      label: Text(
                                        '1 Anak Asuh',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      backgroundColor: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _topicController,
                              decoration: InputDecoration(
                                labelText: 'Topik Panggilan Video',
                                hintText: 'Contoh: Sesi Belajar & Bincang Inspirasi Masa Depan',
                                prefixIcon: const Icon(
                                  Icons.videocam_outlined,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          InkWell(
                            onTap: _pickDateTime,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Waktu Lokal Anda (WIB/Perangkat)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat(
                                            'EEEE, dd MMMM yyyy • HH:mm',
                                          ).format(_selectedDateTime),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'Konversi Sinkronisasi 4 Zona Waktu Serentak',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._zoneOffsets.entries.map((entry) {
                    final isLondon = entry.key.contains('London');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLondon
                                ? Colors.indigo.shade200
                                : AppColors.primary.withValues(alpha: 0.2),
                          ),
                          color: isLondon
                              ? Colors.indigo.shade50.withValues(alpha: 0.3)
                              : Colors.white,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isLondon
                                    ? Colors.indigo.shade100
                                    : AppColors.surfaceLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isLondon ? Icons.public : Icons.access_time,
                                color: isLondon
                                    ? Colors.indigo
                                    : AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isLondon
                                          ? Colors.indigo.shade900
                                          : AppColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimeInZone(entry.value),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Waktu jadwal dalam format UTC (untuk referensi): ${DateFormat('yyyy-MM-dd HH:mm:ss').format(utcTime)} UTC',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: _saveScheduleAndShowPopup,
                    icon: Icon(
                      isAdmin
                          ? Icons.assignment_turned_in
                          : Icons.notifications_active,
                    ),
                    label: Text(
                      isAdmin
                          ? 'Tetapkan Jadwal Laporan Keuangan'
                          : 'Simpan & Pasang Pengingat',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    ),
                    if (!isAdmin) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Status Pengajuan Video Call',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      if (_schedules.isEmpty)
                        const Text(
                          'Belum ada pengajuan video call yang tercatat.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        )
                      else
                        ..._schedules.map((s) {
                          final st = _statusStyle((s['status'] ?? 'scheduled').toString());
                          final stColor = st['color'] as Color;
                          final adminNotes = (s['admin_notes'] ?? '').toString();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              title: Text((s['child_alias'] ?? 'Anak Asuh').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((s['scheduled_at_utc'] ?? '').toString(), style: const TextStyle(fontSize: 11)),
                                  if (adminNotes.isNotEmpty)
                                    Text('Pesan Panti: $adminNotes', style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: stColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  st['label'] as String,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: stColor),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                    const SizedBox(height: 32),
                ],
              ),
              ),
            );

    if (isAdmin) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: const Text('Koordinasi Jadwal & Audit'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: const TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(text: 'Antrean Jadwal Donatur'),
                Tab(text: 'Pengingat Audit Kas'),
              ],
            ),
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(
                  children: [
                    _buildAdminQueueTab(),
                    formBody,
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Jadwal Video Call 4 Zona Waktu'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : formBody,
    );
  }
}
