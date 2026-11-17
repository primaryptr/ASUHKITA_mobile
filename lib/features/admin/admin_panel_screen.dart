import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_colors.dart';
import '../../core/dio_client.dart';
import '../../data/local_db.dart';
import '../../services/gemini_service.dart';
import '../home/home_screen.dart';
import '../sponsor/sponsor_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _localDb = LocalDatabase();
  final _picker = ImagePicker();

  List<Map<String, dynamic>> _children = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  String _formatRupiah(num val) {
    return 'Rp ${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  Future<void> _loadChildren() async {
    setState(() => _isLoading = true);
    try {

      List<Map<String, dynamic>> apiChildren = [];
      bool isApiConnected = false;
      try {
        final res = await DioClient().dio.get('/children');
        if (res.statusCode == 200) {
          final data = res.data;
          if (data is List) {
            apiChildren = List<Map<String, dynamic>>.from(data);
          } else if (data is Map && data['data'] is List) {
            apiChildren = List<Map<String, dynamic>>.from(data['data']);
          }
          isApiConnected = true;
        }
      } catch (_) {}


      final localDonations = await _localDb.getCachedDonations();
      final allDonations = List<Map<String, dynamic>>.from(localDonations);
      try {
        final donRes = await DioClient().dio.get('/donations');
        if (donRes.statusCode == 200) {
          List<dynamic> apiDonations = [];
          if (donRes.data is List) {
            apiDonations = donRes.data as List;
          } else if (donRes.data is Map && donRes.data['data'] is List) {
            apiDonations = donRes.data['data'] as List;
          }
          for (var ad in apiDonations) {
            final id = ad['id']?.toString() ?? '';
            if (!allDonations.any((d) => d['id']?.toString() == id)) {
              allDonations.add(Map<String, dynamic>.from(ad));
            }
          }
        }
      } catch (_) {}


      final receipts = await _localDb.getReceipts();


      final Map<String, Map<String, dynamic>> map = {};

      if (isApiConnected && apiChildren.isNotEmpty) {
        for (var k in apiChildren) {
          final name = (k['alias'] ?? k['name'] ?? '').toString();
          if (name.isNotEmpty) {
            map[name.toLowerCase()] = {
              'id': k['id'],
              'name': name,
              'alias': name,
              'age': k['age'] ?? 8,
              'gender': k['gender'] ?? 'Laki-laki',
              'city': k['orphanage_city'] ?? k['city'] ?? '',
              'urgentNeeds': k['need_category'] ?? k['urgentNeeds'] ?? 'Pendidikan',
              'story': k['story_summary'] ?? k['story'] ?? '',
              'photo': k['avatar'] ?? k['photo'] ?? '',
              'target': (k['target'] is num) ? (k['target'] as num).toDouble() : 500000.0,
              'dream': k['dream'] ?? '',
              'hobby': k['hobby'] ?? '',
              'category_budgets': k['category_budgets'] ?? k['categoryBudgets'] ?? '',
            };
          }
        }
        await _localDb.cacheChildren(apiChildren);
      } else {

        final cached = await _localDb.getCachedChildren();
        final newKids = await _localDb.getNewChildren();
        for (var k in cached) {
          final name = (k['alias'] ?? k['name'] ?? '').toString();
          if (name.isNotEmpty) map[name.toLowerCase()] = Map<String, dynamic>.from(k);
        }
        for (var k in newKids) {
          final name = (k['name'] ?? k['alias'] ?? '').toString();
          if (name.isNotEmpty && !map.containsKey(name.toLowerCase())) {
            map[name.toLowerCase()] = Map<String, dynamic>.from(k);
          }
        }
      }


      for (var key in map.keys) {
        final child = map[key]!;
        final cName = (child['name'] ?? child['alias'] ?? '').toString().toLowerCase();


        final childDonations = allDonations.where((d) {
          final alias = (d['child_alias'] ?? '').toString().toLowerCase();
          return alias == cName;
        }).toList();

        int totalCollected = 0;
        final donorsSet = <String>{};
        for (var cd in childDonations) {
          final amt = (cd['amount_idr'] is num) ? (cd['amount_idr'] as num).toInt() : 0;
          totalCollected += amt;
          final dName = (cd['donor_name'] ?? cd['donor_email'] ?? cd['sponsorship_id'] ?? '').toString().trim();
          if (dName.isNotEmpty) {
            donorsSet.add(dName.toLowerCase());
          }
        }


        final childReceipts = receipts.where((r) {
          final rName = (r['childName'] ?? r['child_name'] ?? '').toString().toLowerCase();
          return rName == cName;
        }).toList();

        int totalSpent = 0;
        for (var cr in childReceipts) {
          final amt = (cr['amount'] is num) ? (cr['amount'] as num).toInt() : 0;
          totalSpent += amt;
        }


        Map<String, double> catBudgets = {};
        final rawCatBudgets = child['category_budgets'] ?? child['categoryBudgets'];
        if (rawCatBudgets != null && rawCatBudgets.toString().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawCatBudgets.toString());
            if (decoded is Map) {
              decoded.forEach((k, v) {
                catBudgets[k.toString()] = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
              });
            }
          } catch (_) {}
        }
        if (catBudgets.isEmpty) {
          final needsStr = (child['urgentNeeds'] ?? child['need_category'] ?? 'Pendidikan').toString();
          final parts = needsStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          final targetTotal = (child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0;
          final perCat = parts.isNotEmpty ? (targetTotal / parts.length) : targetTotal;
          for (var p in parts) {
            catBudgets[p] = perCat;
          }
        }

        child['totalDonations'] = totalCollected;
        child['donorCount'] = donorsSet.isNotEmpty ? donorsSet.length : (childDonations.isNotEmpty ? 1 : 0);
        child['totalSpent'] = totalSpent;
        child['categoryBudgetsMap'] = catBudgets;
        child['childDonationsList'] = childDonations;
      }

      if (mounted) {
        setState(() {
          _children = map.values.toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _children = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredChildren {
    if (_searchQuery.isEmpty) return _children;
    return _children.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final city = (c['city'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || city.contains(query);
    }).toList();
  }

  Future<void> _showAddChildDialog() async {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    final dreamCtrl = TextEditingController();
    final hobbyCtrl = TextEditingController();
    final storyCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Peduli Anak Lombok');
    String selectedGender = 'Laki-laki';
    String? base64Image;
    String? nameError;
    String? ageError;
    String? storyError;
    String? formGeneralError;


    final availableCategories = [
      'Pendidikan',
      'Nutrisi & Makanan',
      'Kesehatan',
      'Pakaian & Tempat Tinggal',
      'Perlengkapan Ibadah',
      'Pengembangan Bakat',
    ];
    final Set<String> selectedNeeds = {'Pendidikan'};
    final Map<String, TextEditingController> budgetControllers = {
      'Pendidikan': TextEditingController(text: '1500000'),
    };

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {

          double totalBudgetCalculated = 0;
          for (var cat in selectedNeeds) {
            final ctrl = budgetControllers[cat];
            if (ctrl != null) {
              totalBudgetCalculated += double.tryParse(ctrl.text.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
            }
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tambah Data Anak Asuh Baru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Text(
                    'Pilih kategori kebutuhan anak, masukkan nominal budget, dan lengkapi data profilnya.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final XFile? photo = await _picker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 500,
                          maxHeight: 500,
                          imageQuality: 50,
                        );
                        if (photo != null) {
                          final bytes = await photo.readAsBytes();
                          setModalState(() {
                            base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                          });
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: base64Image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.memory(
                                  base64Decode(base64Image!.split(',').last),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, color: AppColors.primary, size: 30),
                                  SizedBox(height: 4),
                                  Text('Foto Anak', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    onChanged: (v) {
                      if (nameError != null || formGeneralError != null) {
                        setModalState(() {
                          nameError = null;
                          formGeneralError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Nama Samaran Anak *',
                      hintText: 'Contoh: Arfa / Ayra / Rangga',
                      helperText: nameError == null ? 'Sesuai Child Protection Policy, gunakan nama samaran (alias)' : null,
                      errorText: nameError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            if (ageError != null || formGeneralError != null) {
                              setModalState(() {
                                ageError = null;
                                formGeneralError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Usia (Tahun) *',
                            hintText: 'Contoh: 8',
                            errorText: ageError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedGender,
                          items: ['Laki-laki', 'Perempuan']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setModalState(() => selectedGender = v ?? 'Laki-laki'),
                          decoration: InputDecoration(
                            labelText: 'Jenis Kelamin',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),


                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Kategori Kebutuhan (Pilih Kategori):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedNeeds.length} Dipilih',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCategories.map((cat) {
                      final isSelected = selectedNeeds.contains(cat);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: AppColors.surfaceLight,
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              selectedNeeds.add(cat);
                              budgetControllers.putIfAbsent(cat, () => TextEditingController(text: '1000000'));
                            } else {
                              if (selectedNeeds.length > 1) {
                                selectedNeeds.remove(cat);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Paling sedikit 1 kategori kebutuhan harus dipilih')),
                                );
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),


                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.payments_outlined, color: AppColors.primary, size: 18),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Input Nominal Budget Per Kategori:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...selectedNeeds.map((cat) {
                          final ctrl = budgetControllers.putIfAbsent(cat, () => TextEditingController(text: '1000000'));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: 'Rp ',
                                labelText: 'Nominal Kebutuhan: $cat',
                                hintText: 'Contoh: 1500000',
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                              ),
                            ),
                          );
                        }),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Target Kebutuhan:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              _formatRupiah(totalBudgetCalculated),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: storyCtrl,
                    maxLines: 3,
                    onChanged: (v) {
                      if (storyError != null || formGeneralError != null) {
                        setModalState(() {
                          storyError = null;
                          formGeneralError = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Cerita Singkat / Latar Belakang Anak *',
                      hintText: 'Tuliskan latar belakang, kondisi, dan cerita anak asuh...',
                      errorText: storyError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'Asal Panti / Kota',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dreamCtrl,
                    decoration: InputDecoration(
                      labelText: 'Cita-Cita Anak (Opsional)',
                      hintText: 'Contoh: Guru, Arsitek, Dokter',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hobbyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hobi & Minat (Opsional)',
                      hintText: 'Contoh: Menggambar, Membaca, Sains',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (formGeneralError != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formGeneralError!,
                              style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                              final name = nameCtrl.text.trim();
                              final ageStr = ageCtrl.text.trim();
                              final age = int.tryParse(ageStr);
                              final story = storyCtrl.text.trim();

                              bool hasError = false;
                              String? newNameError;
                              String? newAgeError;
                              String? newStoryError;
                              String? newGeneralError;

                              if (name.isEmpty) {
                                newNameError = 'Nama samaran anak wajib diisi!';
                                hasError = true;
                                newGeneralError ??= newNameError;
                              }

                              if (ageStr.isEmpty) {
                                newAgeError = 'Usia anak wajib diisi!';
                                hasError = true;
                                newGeneralError ??= newAgeError;
                              } else if (age == null || age <= 0) {
                                newAgeError = 'Usia harus angka valid (> 0)!';
                                hasError = true;
                                newGeneralError ??= newAgeError;
                              }

                              if (selectedNeeds.isEmpty) {
                                newGeneralError ??= 'Paling sedikit 1 kategori kebutuhan wajib dipilih!';
                                hasError = true;
                              }

                              if (story.isEmpty) {
                                newStoryError = 'Cerita singkat anak wajib diisi!';
                                hasError = true;
                                newGeneralError ??= newStoryError;
                              }

                              if (hasError) {
                                setModalState(() {
                                  nameError = newNameError;
                                  ageError = newAgeError;
                                  storyError = newStoryError;
                                  formGeneralError = newGeneralError;
                                });
                                return;
                              }

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }


                              if (!mounted) return;
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (dCtx) => PopScope(
                                  canPop: false,
                                  child: Dialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    backgroundColor: Colors.white,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3.5),
                                          ),
                                          SizedBox(height: 20),
                                          Text(
                                            'Menyimpan Data Anak...',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'Mengirim ke Supabase & menyinkronkan data untuk donatur...',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );


                              final Map<String, double> catBudgetsMap = {};
                              for (var cat in selectedNeeds) {
                                final ctrl = budgetControllers[cat];
                                final val = double.tryParse(ctrl?.text.replaceAll('.', '').replaceAll(',', '') ?? '0') ?? 500000.0;
                                catBudgetsMap[cat] = val;
                              }
                              final totalTarget = catBudgetsMap.values.fold<double>(0.0, (sum, val) => sum + val);



                              String serverChildId = 'child_${DateTime.now().millisecondsSinceEpoch}';
                              try {
                                final res = await DioClient().dio.post(
                                  '/children',
                                  data: {
                                    'alias': name,
                                    'age': age,
                                    'gender': selectedGender == 'Perempuan' ? 'P' : 'L',
                                    'need_category': selectedNeeds.join(', '),
                                    'story_summary': story,
                                    'avatar': base64Image ?? '',
                                    'orphanage_city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                                    'orphanage_name': 'Peduli Anak Foundation',
                                    'target': totalTarget > 0 ? totalTarget : 500000.0,
                                    'dream': dreamCtrl.text.trim(),
                                    'hobby': hobbyCtrl.text.trim(),
                                    'category_budgets': jsonEncode(catBudgetsMap),
                                  },
                                );

                                if (res.data is Map && res.data['data'] != null && res.data['data']['id'] != null) {
                                  serverChildId = res.data['data']['id'].toString();
                                }
                              } catch (_) {

                              }

                              final savedKid = {
                                'id': serverChildId,
                                'name': name,
                                'alias': name,
                                'age': age,
                                'gender': selectedGender,
                                'city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                                'orphanage_city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                                'orphanage_name': 'Peduli Anak Foundation',
                                'urgentNeeds': selectedNeeds.join(', '),
                                'need_category': selectedNeeds.join(', '),
                                'category_budgets': jsonEncode(catBudgetsMap),
                                'story': story,
                                'story_summary': story,
                                'photo': base64Image ?? '',
                                'avatar': base64Image ?? '',
                                'target': totalTarget > 0 ? totalTarget : 500000.0,
                                'dream': dreamCtrl.text.trim(),
                                'hobby': hobbyCtrl.text.trim(),
                                'createdAt': DateTime.now().toIso8601String(),
                                'status': 'Tersedia',
                              };


                              await _localDb.insertChild(savedKid);


                              SponsorScreen.refreshNotifier.value++;


                              if (mounted) {
                                Navigator.of(context, rootNavigator: true).pop();
                              }

                              await _loadChildren();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle, color: Colors.white),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text('Data anak "$name" berhasil ditambahkan!'),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green.shade700,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Submit Data Anak Asuh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
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


  void _showEditChildDialog(Map<String, dynamic> child) {
    final nameCtrl = TextEditingController(text: (child['name'] ?? child['alias'] ?? '').toString());
    final ageCtrl = TextEditingController(text: (child['age'] ?? 8).toString());
    final cityCtrl = TextEditingController(text: (child['city'] ?? child['orphanage_city'] ?? 'PeduliAnak Lombok').toString());
    final dreamCtrl = TextEditingController(text: (child['dream'] ?? '').toString());
    final hobbyCtrl = TextEditingController(text: (child['hobby'] ?? '').toString());
    final storyCtrl = TextEditingController(text: (child['story'] ?? child['story_summary'] ?? '').toString());
    String selectedGender = child['gender']?.toString() ?? 'Laki-laki';
    String? base64Image = child['photo'] ?? child['photo_url'] ?? child['avatar'];

    final availableCategories = AppColors.needCategories.where((c) => c != 'Semua').toList();
    final rawNeeds = (child['urgentNeeds'] ?? child['need_category'] ?? 'Pendidikan').toString();
    final List<String> selectedNeeds = rawNeeds.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (selectedNeeds.isEmpty) selectedNeeds.add('Pendidikan');

    final Map<String, TextEditingController> budgetControllers = {};
    final catBudgetsMap = (child['categoryBudgetsMap'] as Map<String, double>?) ?? {};
    for (var cat in selectedNeeds) {
      final b = catBudgetsMap[cat] ?? (child['target'] is num ? (child['target'] as num).toDouble() : 1000000.0);
      budgetControllers[cat] = TextEditingController(text: b.toInt().toString());
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          double totalBudgetCalculated = 0;
          for (var cat in selectedNeeds) {
            final ctrl = budgetControllers[cat];
            final val = double.tryParse(ctrl?.text.replaceAll('.', '').replaceAll(',', '') ?? '0') ?? 0.0;
            totalBudgetCalculated += val;
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.90,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.edit, color: AppColors.primary, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Edit Data Anak Asuh',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const Text(
                    'Perbarui profil anak, kategori kebutuhan, dan alokasi target donasi.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final XFile? photo = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                        if (photo != null) {
                          final bytes = await photo.readAsBytes();
                          setModalState(() {
                            base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                          });
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                        child: base64Image != null && base64Image!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: _buildChildImage(base64Image!, 100, 100),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.add_a_photo, color: AppColors.primary, size: 30),
                                  SizedBox(height: 4),
                                  Text('Ganti Foto', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap Anak',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Usia (Tahun)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selectedGender,
                          items: ['Laki-laki', 'Perempuan']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setModalState(() => selectedGender = v ?? 'Laki-laki'),
                          decoration: InputDecoration(
                            labelText: 'Jenis Kelamin',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),


                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Kategori Kebutuhan (Bisa Pilih > 1):',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${selectedNeeds.length} Dipilih',
                          style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableCategories.map((cat) {
                      final isSelected = selectedNeeds.contains(cat);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: AppColors.surfaceLight,
                        onSelected: (bool selected) {
                          setModalState(() {
                            if (selected) {
                              selectedNeeds.add(cat);
                              budgetControllers.putIfAbsent(cat, () => TextEditingController(text: '1000000'));
                            } else {
                              if (selectedNeeds.length > 1) {
                                selectedNeeds.remove(cat);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Paling sedikit 1 kategori kebutuhan harus dipilih')),
                                );
                              }
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),


                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.payments_outlined, color: AppColors.primary, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Target Budget Per Kategori:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...selectedNeeds.map((cat) {
                          final ctrl = budgetControllers.putIfAbsent(cat, () => TextEditingController(text: '1000000'));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                prefixText: 'Rp ',
                                labelText: 'Budget: $cat',
                                filled: true,
                                fillColor: Colors.white,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          );
                        }),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Target Seluruh Kebutuhan:',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                            Text(
                              _formatRupiah(totalBudgetCalculated),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: cityCtrl,
                    decoration: InputDecoration(
                      labelText: 'Asal Panti / Kota',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dreamCtrl,
                    decoration: InputDecoration(
                      labelText: 'Cita-Cita',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hobbyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Hobi & Minat',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: storyCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Kisah / Latar Belakang Anak',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama anak wajib diisi')),
                          );
                          return;
                        }

                        final Map<String, double> updatedBudgetsMap = {};
                        for (var cat in selectedNeeds) {
                          final ctrl = budgetControllers[cat];
                          final val = double.tryParse(ctrl?.text.replaceAll('.', '').replaceAll(',', '') ?? '0') ?? 500000.0;
                          updatedBudgetsMap[cat] = val;
                        }
                        final totalTarget = updatedBudgetsMap.values.fold<double>(0.0, (sum, val) => sum + val);

                        final updatedKid = {
                          'id': child['id']?.toString() ?? 'child_${DateTime.now().millisecondsSinceEpoch}',
                          'name': nameCtrl.text.trim(),
                          'age': int.tryParse(ageCtrl.text) ?? 8,
                          'gender': selectedGender,
                          'city': cityCtrl.text.trim().isEmpty ? 'Peduli Anak Lombok' : cityCtrl.text.trim(),
                          'urgentNeeds': selectedNeeds.join(', '),
                          'category_budgets': jsonEncode(updatedBudgetsMap),
                          'story': storyCtrl.text,
                          'photo': base64Image ?? '',
                          'target': totalTarget > 0 ? totalTarget : 500000.0,
                          'dream': dreamCtrl.text,
                          'hobby': hobbyCtrl.text,
                        };

                        await _localDb.updateChild(updatedKid);


                        try {
                          await DioClient().dio.put('/children/${updatedKid['id']}', data: {
                            'alias': updatedKid['name'],
                            'age': updatedKid['age'],
                            'gender': updatedKid['gender'],
                            'need_category': updatedKid['urgentNeeds'],
                            'story_summary': updatedKid['story'],
                            'avatar': updatedKid['photo'],
                            'orphanage_city': updatedKid['city'],
                            'target': updatedKid['target'],
                            'dream': updatedKid['dream'],
                            'hobby': updatedKid['hobby'],
                            'category_budgets': updatedKid['category_budgets'],
                          });
                        } catch (_) {}

                        if (ctx.mounted) Navigator.pop(ctx);
                        _loadChildren();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Data anak "${nameCtrl.text}" berhasil diperbarui & disinkronkan!'),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                      child: const Text('Simpan Perubahan Data Anak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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


  Future<void> _confirmDeleteChild(Map<String, dynamic> child) async {
    final cName = (child['name'] ?? child['alias'] ?? 'Anak Asuh').toString();
    final childId = child['id']?.toString() ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Hapus Data Anak Asuh?')),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data "$cName"? '
          'Data anak akan dihapus dari sistem SQLite dan Supabase, serta tidak lagi ditampilkan ke donatur.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Data'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _localDb.deleteChild(childId, cName);
      try {
        await DioClient().dio.delete('/children/$childId');
      } catch (_) {}
      _loadChildren();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data anak "$cName" berhasil dihapus dari sistem.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _showPublishReportModal(Map<String, dynamic> child) async {
    final childId = (child['id'] ?? '').toString();
    final childName = (child['alias'] ?? child['name'] ?? 'Anak Asuh').toString();
    final messenger = ScaffoldMessenger.maybeOf(context);

    final published = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PublishReportDialog(
        childId: childId,
        childName: childName,
        picker: _picker,
        localDb: _localDb,
      ),
    );

    if (published == true && mounted) {
      HomeScreen.refreshNotifier.value++;
      if (messenger != null && messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ Kabar $childName berhasil dipublikasikan!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _showChildDetailAndReceiptDialog(Map<String, dynamic> child) {
    final childName = (child['name'] ?? child['alias'] ?? 'Anak Asuh').toString();
    final catBudgetsMap = (child['categoryBudgetsMap'] as Map<String, double>?) ?? {};
    final totalDonations = (child['totalDonations'] as int?) ?? 0;
    final totalTarget = ((child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0);
    final donorCount = (child['donorCount'] as int?) ?? 0;
    final childDonations = (child['childDonationsList'] as List<dynamic>?) ?? [];
    final percentOverall = (totalTarget > 0 ? (totalDonations / totalTarget * 100) : 0.0).clamp(0.0, 100.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // FIX 3: wlKey untuk trigger rebuild FutureBuilder wishlist
        int wlKey = 0;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _buildChildImage(child['photo'] ?? child['photo_url'] ?? child['avatar'] ?? '', 90, 90),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  childName,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Usia: ${child['age'] ?? '-'} Tahun • ${child['city'] ?? child['orphanage_city'] ?? ''}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Kebutuhan: ${child['urgentNeeds'] ?? child['need_category'] ?? 'Pendidikan'}',
                                    style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Cita-cita: ${(child['dream']?.toString().trim().isNotEmpty == true) ? child['dream'] : '-'} | Hobi: ${(child['hobby']?.toString().trim().isNotEmpty == true) ? child['hobby'] : '-'}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        child['story'] ?? child['story_summary'] ?? 'Belum ada kisah latar belakang.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                      const Divider(height: 28),


                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Status Pendanaan Anak',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '👥 $donorCount Donatur Mendampingi',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Terkumpul: ${_formatRupiah(totalDonations)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                  ),
                                Text(
                                  'Target: ${_formatRupiah(totalTarget)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: percentOverall / 100,
                                minHeight: 8,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${percentOverall.toStringAsFixed(1)}% Terpenuhi',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),


                      const Text(
                        'Rincian Budget & Status Per Kategori:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Donatur dapat mendanai lebih dari 2 orang sampai target kategori terpenuhi.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      if (catBudgetsMap.isEmpty)
                        const Text('Tidak ada rincian kategori.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                      else
                        Column(
                          children: catBudgetsMap.entries.map((entry) {
                            final catName = entry.key;
                            final catTarget = entry.value;


                            int catCollected = 0;
                            int catDonorCount = 0;
                            for (var d in childDonations) {
                              final pkg = (d['package_name'] ?? d['need_category'] ?? '').toString();
                              if (pkg.toLowerCase().contains(catName.toLowerCase()) || catBudgetsMap.length == 1) {
                                catCollected += ((d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0);
                                catDonorCount++;
                              }
                            }
                            if (catBudgetsMap.length > 1 && catCollected == 0 && totalDonations > 0) {

                              catCollected = (totalDonations * (catTarget / totalTarget)).toInt();
                            }

                            final isFulfilled = catCollected >= catTarget;
                            final remaining = (catTarget - catCollected).clamp(0, catTarget.toInt());

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isFulfilled ? Colors.green.shade50 : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isFulfilled ? Colors.green.shade300 : AppColors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // FIX 2: Wrap agar tidak overflow — chip di baris bawah jika tidak muat
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        catName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isFulfilled ? Colors.green.shade800 : AppColors.textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isFulfilled ? Colors.green : Colors.orange,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isFulfilled
                                              ? '✅ Terpenuhi'
                                              : 'Kurang ${_formatRupiah(remaining)}',
                                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Target: ${_formatRupiah(catTarget)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      Text('Terkumpul: ${_formatRupiah(catCollected)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: catTarget > 0 ? (catCollected / catTarget).clamp(0.0, 1.0) : 0.0,
                                      minHeight: 6,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: AlwaysStoppedAnimation<Color>(isFulfilled ? Colors.green : AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),


                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Riwayat Donatur ($donorCount Donatur):',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (childDonations.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada donatur yang memberikan dana untuk anak ini.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: childDonations.map((d) {
                            final dName = (d['donor_name'] ?? d['donor_email'] ?? 'Donatur Peduli').toString();
                            final amt = (d['amount_idr'] is num) ? (d['amount_idr'] as num).toInt() : 0;
                            final date = (d['created_at'] ?? '').toString();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                    child: const Icon(Icons.volunteer_activism, size: 14, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(dName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        Text(date.isNotEmpty ? date.substring(0, date.length > 16 ? 16 : date.length) : '-', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatRupiah(amt),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showPublishReportModal(child),
                              icon: const Icon(Icons.campaign_outlined, size: 18),
                              label: const Text('Bagikan Kabar Anak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wishlist Kebutuhan Anak',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                Text(
                                  'Daftar kebutuhan spesifik yang bisa didanai donatur',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            // FIX 3: pass setModalState & wlKey agar list refresh setelah tambah
                            onPressed: () async {
                              await _showAddWishlistDialog(
                                child,
                                onDone: () => setModalState(() => wlKey++),
                              );
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Tambah Wishlist', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        // FIX 3: key berubah setiap operasi wishlist → FutureBuilder rebuild
                        key: ValueKey(wlKey),
                        future: _loadWishlistsForChild(
                          childId: (child['id'] ?? '').toString(),
                          childName: childName,
                        ),
                        builder: (context, wlSnap) {
                          // PBI 2: Filter out deleted items
                          final wishlists = (wlSnap.data ?? [])
                              .where((w) => (w['status'] ?? 'open').toString() != 'deleted')
                              .toList();
                          if (wishlists.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: Text('Belum ada wishlist kebutuhan anak.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            );
                          }
                          return Column(
                            children: wishlists.map((w) {
                              final status = (w['status'] ?? 'open').toString();
                              final est = (w['estimated_idr'] is num)
                                  ? (w['estimated_idr'] as num).toDouble()
                                  : double.tryParse(w['estimated_idr']?.toString() ?? '0') ?? 0.0;
                              final itemName = (w['item_name'] ?? 'Kebutuhan').toString();

                              // Warna status
                              Color statusColor;
                              String statusLabel;
                              IconData statusIcon;
                              if (status == 'fulfilled') {
                                statusColor = Colors.green;
                                statusLabel = 'Sudah Disalurkan';
                                statusIcon = Icons.check_circle_outline;
                              } else if (status == 'funded') {
                                statusColor = Colors.blue;
                                statusLabel = 'Dana Terpenuhi';
                                statusIcon = Icons.paid_outlined;
                              } else {
                                statusColor = Colors.orange;
                                statusLabel = 'Butuh Dukungan';
                                statusIcon = Icons.radio_button_unchecked;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(statusIcon, size: 14, color: statusColor),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(itemName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(statusLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_formatRupiah(est), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark)),
                                    // Tombol aksi berdasarkan status
                                    if (status != 'fulfilled') ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          // FIX 3: semua callback wishlist bawa onDone → setModalState refresh
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              onPressed: () async {
                                                await _markWishlistFulfilled(
                                                  context, child, w,
                                                  onDone: () => setModalState(() => wlKey++),
                                                );
                                              },
                                              icon: const Icon(Icons.check_circle_outline, size: 14),
                                              label: const Text('Tandai Disalurkan', style: TextStyle(fontSize: 11)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.green.shade700,
                                                side: BorderSide(color: Colors.green.shade300),
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (status == 'funded')
                                            OutlinedButton.icon(
                                              onPressed: () => _showAddReceiptDialog(child, wishlistItem: w),
                                              icon: const Icon(Icons.receipt_outlined, size: 14),
                                              label: const Text('Input Nota', style: TextStyle(fontSize: 11)),
                                              style: OutlinedButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          if (status == 'open') ...[
                                            const SizedBox(width: 4),
                                            IconButton(
                                              onPressed: () async {
                                                await _deleteWishlistItem(
                                                  context, w,
                                                  onDone: () => setModalState(() => wlKey++),
                                                );
                                              },
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                              tooltip: 'Hapus Item',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const Divider(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Laporan Pengeluaran & Nota',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                              ),
                              Text(
                                'Transparansi belanja khusus untuk anak ini',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
    ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            icon: const Icon(Icons.add_photo_alternate, size: 16),
                            label: const Text('Input Nota', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              _showAddReceiptDialog(child);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadReceiptsForChild(childName),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primary)));
                          }
                          final receipts = snapshot.data ?? [];
                          if (receipts.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long_outlined, size: 40, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    const Text('Belum ada nota/laporan belanja diinputkan untuk anak ini.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: receipts.map((r) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (r['receiptImage'] != null && (r['receiptImage'] as String).isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: _buildChildImage(r['receiptImage'], 60, 60),
                                      )
                                    else
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceLight,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.receipt, color: AppColors.primary),
                                      ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r['title'] ?? 'Belanja Kebutuhan',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                                          ),
                                          Text(
                                            'Nominal: Rp ${r['amount']}',
                                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          Text(
                                            'Tanggal: ${r['date'] ?? '-'}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Kode Nota: ${r['id'] ?? '-'}',
                                              style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey[700]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
          );
        }, // end StatefulBuilder builder
        ); // end StatefulBuilder
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadWishlistsForChild({
    required String childId,
    required String childName,
  }) async {
    try {
      final res = await DioClient().dio.get('/wishlists', queryParameters: {
        if (childId.isNotEmpty) 'child_id': childId,
      });
      if (res.statusCode == 200 && res.data is Map && res.data['data'] is List) {
        final remote = List<Map<String, dynamic>>.from(
          (res.data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)),
        );
        if (remote.isNotEmpty) {
          await _localDb.cacheWishlists(remote);
          return remote;
        }
      }
    } catch (_) {}
    return _localDb.getCachedWishlists(childId: childId, childAlias: childName);
  }

  // PBI 2: Dialog konfirmasi penyaluran
  Future<void> _markWishlistFulfilled(
    BuildContext context,
    Map<String, dynamic> child,
    Map<String, dynamic> wishlistItem, {
    VoidCallback? onDone, // FIX 3: callback untuk refresh UI bottom sheet
  }) async {
    final childName = (child['alias'] ?? child['name'] ?? 'Anak Asuh').toString();
    final itemName = (wishlistItem['item_name'] ?? 'Kebutuhan').toString();
    final wlId = (wishlistItem['id'] ?? '').toString();
    final noteCtrl = TextEditingController();
    String? receiptBase64;
    bool isProcessing = false;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tandai Disalurkan',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"$itemName" untuk $childName',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    hintText: 'Misal: Dibeli di toko Maju Jaya tgl 15 Nov',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                // Upload struk opsional
                GestureDetector(
                  onTap: () async {
                    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 70);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      setDlgState(() {
                        receiptBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                      });
                    }
                  },
                  child: Container(
                    height: 72,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), style: BorderStyle.solid),
                    ),
                    child: receiptBase64 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(base64Decode(receiptBase64!.split(',').last), fit: BoxFit.cover),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 6),
                              Text('Upload Struk (Opsional)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
            ElevatedButton.icon(
              onPressed: isProcessing
                  ? null
                  : () async {
                      setDlgState(() => isProcessing = true);
                      // Update wishlist status ke fulfilled
                      if (wlId.isNotEmpty) {
                        try {
                          await DioClient().dio.patch('/wishlists/$wlId/fulfill', data: {
                            'receipt_url': receiptBase64 ?? '',
                            'notes': noteCtrl.text.trim(),
                          });
                        } catch (_) {}
                        await _localDb.cacheWishlists([
                          {
                            ...wishlistItem,
                            'status': 'fulfilled',
                            'receipt_url': receiptBase64 ?? '',
                          }
                        ]);
                      }
                      // Simpan nota jika ada struk
                      if (receiptBase64 != null) {
                        final receipt = {
                          'id': 'rec_${DateTime.now().millisecondsSinceEpoch}',
                          'childName': childName,
                          'title': 'Penyaluran: $itemName',
                          'amount': (wishlistItem['estimated_idr'] is num)
                              ? (wishlistItem['estimated_idr'] as num).toDouble()
                              : 0.0,
                          'date': DateTime.now().toString().split(' ')[0],
                          'receiptImage': receiptBase64,
                          'description': noteCtrl.text.trim(),
                          'hash': '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
                        };
                        await _localDb.insertReceipt(receipt);
                        try {
                          await DioClient().dio.post('/ledger/receipts', data: receipt);
                        } catch (_) {}
                      }
                      HomeScreen.refreshNotifier.value++;
                      FocusManager.instance.primaryFocus?.unfocus();
                      if (dCtx.mounted) Navigator.pop(dCtx);
                      if (messenger.mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('✅ "$itemName" berhasil ditandai sebagai Sudah Disalurkan!'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      }
                      // FIX 3: refresh FutureBuilder di bottom sheet
                      onDone?.call();
                    },
              icon: const Icon(Icons.check_circle, size: 16),
              label: Text(isProcessing ? 'Menyimpan...' : 'Konfirmasi Disalurkan'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
    noteCtrl.dispose();
  }

  // PBI 2: Hapus item wishlist yang masih open
  Future<void> _deleteWishlistItem(
    BuildContext context,
    Map<String, dynamic> wishlistItem, {
    VoidCallback? onDone, // FIX 3
  }) async {
    final itemName = (wishlistItem['item_name'] ?? 'Kebutuhan').toString();
    final wlId = (wishlistItem['id'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Item Wishlist?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Text('Item "$itemName" akan dihapus dari daftar kebutuhan anak.', style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    // Hapus via API jika ada ID
    if (wlId.isNotEmpty) {
      try {
        await DioClient().dio.delete('/wishlists/$wlId');
      } catch (_) {}
    }
    // Tandai sebagai deleted di local dengan status 'deleted' (filter di UI)
    await _localDb.cacheWishlists([
      {
        ...wishlistItem,
        'status': 'deleted',
      }
    ]);
    HomeScreen.refreshNotifier.value++;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item "$itemName" dihapus.'), backgroundColor: Colors.red.shade700),
      );
    }
    // FIX 3: refresh FutureBuilder di bottom sheet
    onDone?.call();
  }

  Future<void> _showAddWishlistDialog(
    Map<String, dynamic> child, {
    VoidCallback? onDone, // FIX 3
  }) async {
    final childId = (child['id'] ?? '').toString();
    final childName = (child['name'] ?? child['alias'] ?? 'Anak Asuh').toString();
    final itemCtrl = TextEditingController();
    final estCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: Text('Tambah Wishlist $childName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Kebutuhan (mis. Sepatu Sekolah)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: estCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimasi Biaya (Rp)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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

    final itemName = itemCtrl.text.trim();
    final estNum = double.tryParse(estCtrl.text.trim()) ?? 0.0;
    itemCtrl.dispose();
    estCtrl.dispose();

    if (confirmed != true || itemName.isEmpty || estNum <= 0) return;

    final payload = {
      'id': 'wl_${DateTime.now().millisecondsSinceEpoch}',
      'child_id': childId,
      'child_alias': childName,
      'item_name': itemName,
      'estimated_idr': estNum,
      'status': 'open',
      'created_at': DateTime.now().toIso8601String(),
    };
    try {
      final res = await DioClient().dio.post('/wishlists', data: payload);
      if (res.statusCode == 201 && res.data is Map && res.data['data'] is Map) {
        payload['id'] = res.data['data']['id']?.toString() ?? payload['id']!;
      }
    } catch (_) {}
    await _localDb.cacheWishlists([payload]);

    if (mounted) {
      // FIX 3: JANGAN pop bottom sheet, cukup panggil onDone untuk refresh list
      onDone?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wishlist "$itemName" ditambahkan untuk $childName'), backgroundColor: AppColors.primary),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadReceiptsForChild(String childName) async {
    final allReceipts = await _localDb.getReceipts();
    return allReceipts.where((r) => (r['childName'] ?? '').toString().toLowerCase() == childName.toLowerCase()).toList();
  }

  Future<void> _showAddReceiptDialog(Map<String, dynamic> child, {Map<String, dynamic>? wishlistItem}) async {
    final titleCtrl = TextEditingController(
      text: wishlistItem != null ? 'Pembelian ${wishlistItem['item_name'] ?? 'Kebutuhan'}' : '',
    );
    final amountCtrl = TextEditingController(
      text: wishlistItem != null && wishlistItem['estimated_idr'] != null
          ? (wishlistItem['estimated_idr'] is num
              ? (wishlistItem['estimated_idr'] as num).toInt().toString()
              : wishlistItem['estimated_idr'].toString())
          : '',
    );
    final descCtrl = TextEditingController();
    String? receiptBase64;
    final childName = child['name'] ?? child['alias'] ?? 'Anak Asuh';

    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Input Nota untuk $childName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final XFile? photo = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 600);
                    if (photo != null) {
                      final bytes = await photo.readAsBytes();
                      setDialogState(() {
                        receiptBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                      });
                    }
                  },
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary, strokeAlign: BorderSide.strokeAlignInside),
                    ),
                    child: receiptBase64 != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(base64Decode(receiptBase64!.split(',').last), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, color: AppColors.primary, size: 28),
                              const SizedBox(height: 4),
                              const Text('Upload Bukti Struk/Nota', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(labelText: 'Peruntukan (Contoh: Beli Buku & Seragam)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Nominal Biaya (Rp)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(labelText: 'Keterangan Toko / Tanggal', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (titleCtrl.text.isEmpty || amountCtrl.text.isEmpty) {
                  return;
                }
                final newReceipt = {
                  'id': 'rec_${DateTime.now().millisecondsSinceEpoch}',
                  'childName': childName,
                  'title': titleCtrl.text.trim(),
                  'amount': double.tryParse(amountCtrl.text) ?? 0.0,
                  'date': DateTime.now().toString().split(' ')[0],
                  'receiptImage': receiptBase64 ?? '',
                  'description': descCtrl.text.trim(),
                  'hash': '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}sha256',
                };
                await _localDb.insertReceipt(newReceipt);


                try {
                  await DioClient().dio.post('/ledger/receipts', data: newReceipt);
                } catch (_) {}

                if (wishlistItem != null && (wishlistItem['id'] ?? '').toString().isNotEmpty) {
                  final wlId = wishlistItem['id'].toString();
                  try {
                    await DioClient().dio.patch('/wishlists/$wlId/fulfill', data: {'receipt_url': receiptBase64 ?? ''});
                  } catch (_) {}
                  await _localDb.cacheWishlists([
                    {
                      ...wishlistItem,
                      'status': 'fulfilled',
                      'receipt_url': receiptBase64 ?? '',
                    }
                  ]);
                }

                if (dCtx.mounted) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.pop(dCtx);
                }
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nota berhasil disimpan dan dibagikan untuk transparansi donatur!'), backgroundColor: AppColors.primary),
                  );
                }
              },
              child: const Text('Simpan Nota'),
            ),
          ],
        ),
      ),
    );
    titleCtrl.dispose();
    amountCtrl.dispose();
    descCtrl.dispose();
  }

  Widget _buildChildImage(String url, double width, double height) {
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(bytes, width: width, height: height, fit: BoxFit.cover);
      } catch (_) {}
    }
    if (url.startsWith('assets/')) {
      return Image.asset(url, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: width, height: height, color: AppColors.surfaceLight, child: const Icon(Icons.person, color: AppColors.primary)));
    }
    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          color: AppColors.surfaceLight,
          child: const Icon(Icons.person, color: AppColors.primary),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person, color: AppColors.primary),
    );
  }

  Future<void> _confirmResetAllChildren() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset Semua Data Anak?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Tindakan ini akan mengosongkan SELURUH data anak asuh baik di database Supabase maupun di penyimpanan lokal HP sehingga Anda dapat memulai input dari 0 lagi.\n\nApakah Anda yakin ingin melanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Semua'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red),
                SizedBox(height: 18),
                Text('Mengosongkan Data Anak...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 6),
                Text('Menghapus data di Supabase & SQLite lokal...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      try {
        await DioClient().dio.delete('/children');
      } catch (_) {}

      await _localDb.clearAllChildrenCache();
      SponsorScreen.refreshNotifier.value++;
      await _loadChildren();

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua data anak asuh berhasil dihapus. Database kini bersih (0 data)!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal reset: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Panel Kelola Panti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Builder(
            builder: (btnCtx) => IconButton(
              tooltip: 'Broadcast Kabar ke Donatur',
              icon: const Icon(Icons.campaign_outlined),
              // PBI 4: gunakan btnCtx dari Builder agar context selalu valid
              onPressed: () => showAdminBroadcastDialog(btnCtx),
            ),
          ),
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh),
            onPressed: _loadChildren,
          ),
          IconButton(
            tooltip: 'Reset Semua Data Anak',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _confirmResetAllChildren,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Anak Asuh'),
        onPressed: _showAddChildDialog,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Cari nama anak atau asal panti...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Terdaftar: ${_filteredChildren.length} Anak',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const Text(
                        'Klik kartu untuk input nota belanja',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_filteredChildren.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care, size: 64, color: AppColors.primary.withValues(alpha: 0.4)),
                          const SizedBox(height: 16),
                          const Text('Belum ada data anak asuh.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          const Text('Tekan tombol + untuk menambah anak asuh baru.', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                        ],
                      ),
                    ),
                  )
                else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filteredChildren.length,
                    itemBuilder: (ctx, idx) {
                      final child = _filteredChildren[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 1.5,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showChildDetailAndReceiptDialog(child),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildChildImage(child['photo'] ?? child['photo_url'] ?? child['avatar'] ?? '', 70, 70),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        child['name'] ?? child['alias'] ?? 'Anak Asuh',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Usia ${child['age'] ?? '-'} Thn • ${child['city'] ?? child['orphanage_city'] ?? ''}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLight,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                            ),
                                            child: Text(
                                              child['urgentNeeds'] ?? child['need_category'] ?? 'Pendidikan',
                                              style: const TextStyle(fontSize: 10, color: AppColors.primaryDark, fontWeight: FontWeight.bold),
                                            ),
                                          ),

                                          Builder(
                                            builder: (_) {
                                              final totalDonations = (child['totalDonations'] as int?) ?? 0;
                                              final target = ((child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0);
                                              final isFulfilled = totalDonations >= target && target > 0;
                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isFulfilled ? Colors.green.shade50 : Colors.amber.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: isFulfilled ? Colors.green.shade400 : Colors.amber.shade400),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isFulfilled ? Icons.check_circle : Icons.hourglass_top,
                                                      size: 10,
                                                      color: isFulfilled ? Colors.green.shade800 : Colors.amber.shade900,
                                                    ),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      isFulfilled ? 'Sudah Terpenuhi' : 'Belum Terpenuhi',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isFulfilled ? Colors.green.shade800 : Colors.amber.shade900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '👥 ${child['donorCount'] ?? 0} Donatur',
                                              style: const TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            'Terkumpul: ${_formatRupiah((child['totalDonations'] as int?) ?? 0)}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Target: ${_formatRupiah(((child['target'] is num) ? (child['target'] as num).toDouble() : 500000.0))}',
                                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),

                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                                      tooltip: 'Edit Data Anak',
                                      onPressed: () => _showEditChildDialog(child),
                                    ),
                                    const SizedBox(height: 8),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                      tooltip: 'Hapus Data Anak',
                                      onPressed: () => _confirmDeleteChild(child),
                                    ),
                                    const SizedBox(height: 8),
                                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textHint),
                                  ],
                                ),
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
    );
  }
}

class _PublishReportDialog extends StatefulWidget {
  final String childId;
  final String childName;
  final ImagePicker picker;
  final LocalDatabase localDb;

  const _PublishReportDialog({
    required this.childId,
    required this.childName,
    required this.picker,
    required this.localDb,
  });

  @override
  State<_PublishReportDialog> createState() => _PublishReportDialogState();
}

class _PublishReportDialogState extends State<_PublishReportDialog> {
  final _titleCtrl = TextEditingController();
  final _summaryCtrl = TextEditingController();
  final _statusCtrl = TextEditingController();

  String _selectedCategory = 'Prestasi';
  String _evidenceUrl = '';
  bool _isPolishing = false;
  bool _isSaving = false;
  String? _validationError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  Future<void> _handlePolishStory() async {
    final raw = _summaryCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _validationError = 'Tulis cerita perkembangan terlebih dahulu sebelum dirapikan AI.');
      return;
    }
    setState(() {
      _isPolishing = true;
      _validationError = null;
    });
    final polished = await GeminiService().polishReportStory(
      childName: widget.childName,
      category: _selectedCategory,
      rawStory: raw,
    );
    if (!mounted) return;
    setState(() {
      if (polished.isNotEmpty) {
        _summaryCtrl.text = polished;
      }
      _isPolishing = false;
    });
  }

  Future<void> _handlePublish() async {
    final title = _titleCtrl.text.trim();
    final summary = _summaryCtrl.text.trim();
    final dailyStatus = _statusCtrl.text.trim();
    if (title.isEmpty && summary.isEmpty) {
      setState(() => _validationError = 'Judul atau cerita perkembangan wajib diisi.');
      return;
    }
    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      final payload = <String, dynamic>{
        'id': 'rep_${DateTime.now().millisecondsSinceEpoch}',
        'child_id': widget.childId,
        'child_alias': widget.childName,
        'title': title,
        'category': _selectedCategory,
        'period': DateTime.now().toIso8601String().substring(0, 7),
        'summary': summary,
        'evidence_url': _evidenceUrl,
        'author_name': 'Pengurus Panti',
        'created_at': DateTime.now().toIso8601String(),
        'daily_status': dailyStatus,
      };
      try {
        final res = await DioClient()
            .dio
            .post('/reports', data: payload)
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 201 && res.data is Map && res.data['data'] is Map) {
          payload['id'] = res.data['data']['id']?.toString() ?? payload['id'];
        }
      } catch (_) {}

      if (dailyStatus.isNotEmpty) {
        final childKey = widget.childId.isNotEmpty ? widget.childId : widget.childName;
        if (widget.childId.isNotEmpty) {
          try {
            await DioClient()
                .dio
                .patch('/children/${widget.childId}/daily-status', data: {'daily_status': dailyStatus})
                .timeout(const Duration(seconds: 5));
          } catch (_) {}
        }
        try {
          await widget.localDb.updateChildDailyStatusLocal(childKey, dailyStatus);
        } catch (_) {}
      }

      try {
        await widget.localDb.cacheProgressReports([payload]);
      } catch (_) {}
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Bagikan Kabar ${widget.childName}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategori Kabar',
                border: OutlineInputBorder(),
              ),
              items: const ['Prestasi', 'Karya Anak', 'Kesehatan', 'Kegiatan']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _isSaving ? null : (val) => setState(() => _selectedCategory = val ?? 'Prestasi'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _statusCtrl,
              enabled: !_isSaving,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: '📢 Status Harian (1 baris singkat)',
                hintText: 'Contoh: Hari ini Ani belajar mengaji dengan semangat 🌟',
                border: const OutlineInputBorder(),
                helperText: 'Muncul sebagai status terbaru di halaman donatur',
                helperStyle: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleCtrl,
              enabled: !_isSaving,
              decoration: const InputDecoration(
                labelText: 'Judul Kabar',
                hintText: 'Contoh: Juara Lomba Mewarnai',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _summaryCtrl,
              enabled: !_isSaving,
              minLines: 3,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Cerita Perkembangan',
                hintText: 'Ceritakan momen baik anak hari ini...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: (_isPolishing || _isSaving) ? null : _handlePolishStory,
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                _isPolishing ? 'Merapikan...' : 'Rapikan Kalimat dengan AI',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () async {
                      final picked = await widget.picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 800,
                        imageQuality: 65,
                      );
                      if (picked != null && mounted) {
                        final bytes = await picked.readAsBytes();
                        if (!mounted) return;
                        setState(() {
                          _evidenceUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
                        });
                      }
                    },
              icon: const Icon(Icons.photo_camera_outlined, size: 16),
              label: Text(
                _evidenceUrl.isEmpty ? 'Lampirkan Foto / Karya (Opsional)' : 'Foto Terlampir ✓',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 10),
              Text(
                _validationError!,
                style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pop(false);
                },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handlePublish,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _isSaving
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text('Mempublikasikan...'),
                  ],
                )
              : const Text('Publikasikan'),
        ),
      ],
    );
  }
}

Future<void> showAdminBroadcastDialog(BuildContext context) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AdminBroadcastDialog(),
  );

  if (result != null && messenger != null && messenger.mounted) {
    final success = result['success'] == true;
    final feedback = (result['feedback'] ?? '📡 Broadcast tercatat, akan dikirim saat terhubung.').toString();
    messenger.showSnackBar(
      SnackBar(
        content: Text(feedback),
        backgroundColor: success ? const Color(0xFF388E3C) : Colors.blueGrey.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

class _AdminBroadcastDialog extends StatefulWidget {
  const _AdminBroadcastDialog();

  @override
  State<_AdminBroadcastDialog> createState() => _AdminBroadcastDialogState();
}

class _AdminBroadcastDialogState extends State<_AdminBroadcastDialog> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  bool _isSending = false;
  String? _validationError;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _validationError = '⚠️ Judul dan isi pesan wajib diisi.');
      return;
    }

    setState(() {
      _isSending = true;
      _validationError = null;
    });

    String feedback = '📡 Broadcast tercatat, akan dikirim saat terhubung.';
    bool success = false;
    try {
      final res = await DioClient().dio.post(
        '/notifications/broadcast',
        data: {'title': title, 'body': body},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200 || res.statusCode == 201) {
        feedback = '✅ Broadcast berhasil dikirim ke seluruh donatur!';
        success = true;
      }
    } catch (_) {
      // Offline fallback feedback applies
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) {
        Navigator.of(context).pop({'success': success, 'feedback': feedback});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.campaign, color: Color(0xFF388E3C), size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Broadcast Kabar ke Donatur',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF388E3C)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pesan akan dikirim sebagai notifikasi ke semua donatur aktif.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _titleCtrl,
              enabled: !_isSending,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Judul Notifikasi',
                hintText: 'Contoh: Laporan & Kabar Terbaru Anak Asuh',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bodyCtrl,
              enabled: !_isSending,
              maxLines: 4,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Isi Pesan Broadcast',
                hintText: 'Tulis pengumuman atau ucapan terima kasih untuk seluruh donatur...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message_outlined),
              ),
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _validationError!,
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSending
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context).pop();
                },
          child: const Text('Batal'),
        ),
        ElevatedButton.icon(
          onPressed: _isSending ? null : _handleSend,
          icon: _isSending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(_isSending ? 'Mengirim...' : 'Kirim Broadcast'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF388E3C),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}


