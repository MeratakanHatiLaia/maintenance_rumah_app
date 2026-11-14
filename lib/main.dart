import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MaintenanceRumahApp());
}

// 1. Model Data untuk Firestore
class MaintenanceModel {
  String? id; // Menggunakan String? karena ID dokumen Firestore berupa string acak
  String title;
  String category;
  String date;
  int rawCost;
  String technician;
  String description;

  MaintenanceModel({
    this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.rawCost,
    required this.technician,
    required this.description,
  });

  // Konversi Objek ke Map untuk disimpan ke Firestore
  Map<String, dynamic> toMap() => {
    'title': title,
    'category': category,
    'date': date,
    'rawCost': rawCost,
    'technician': technician,
    'description': description,
  };

  // Membuat Objek dari DocumentSnapshot Firestore
  factory MaintenanceModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MaintenanceModel(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '',
      date: data['date'] ?? '',
      rawCost: data['rawCost'] ?? 0,
      technician: data['technician'] ?? '-',
      description: data['description'] ?? '-',
    );
  }
}

// 2. Helper Service untuk Firebase Firestore (Mendukung Offline-First bawaan SDK)
class FirestoreService {
  final CollectionReference maintenanceCollection =
  FirebaseFirestore.instance.collection('maintenance');

  // Tambah Data
  Future<void> insertData(MaintenanceModel model) async {
    await maintenanceCollection.add(model.toMap());
  }

  // Ambil Semua Data (Stream untuk real-time update & offline cache)
  Stream<List<MaintenanceModel>> getAllData() {
    return maintenanceCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return MaintenanceModel.fromFirestore(doc);
      }).toList();
    });
  }

  // Update Data
  Future<void> updateData(MaintenanceModel model) async {
    if (model.id != null) {
      await maintenanceCollection.doc(model.id).update(model.toMap());
    }
  }

  // Hapus Data
  Future<void> deleteData(String id) async {
    await maintenanceCollection.doc(id).delete();
  }
}

class MaintenanceRumahApp extends StatelessWidget {
  const MaintenanceRumahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Maintenance Rumah',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const MainAppScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _selectedIndex = 0;
  List<MaintenanceModel> _maintenanceList = [];
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _listenToDatabase();
  }

  // Mendengarkan perubahan data secara real-time dari Firestore (mendukung mode offline)
  void _listenToDatabase() {
    _firestoreService.getAllData().listen((data) {
      if (mounted) {
        setState(() {
          _maintenanceList = data;
        });
      }
    });
  }

  void _addMaintenance(
      String title, String category, String cost, String technician, String description) async {
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    final newModel = MaintenanceModel(
      title: title,
      category: category,
      date: dateStr,
      rawCost: int.tryParse(cost) ?? 0,
      technician: technician.isEmpty ? '-' : technician,
      description: description.isEmpty ? '-' : description,
    );

    await _firestoreService.insertData(newModel);

    setState(() {
      _selectedIndex = 0;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data maintenance berhasil disimpan ke Firestore!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeTab(
        list: _maintenanceList,
        onRefresh: () {}, // Firestore sudah real-time otomatis
        onNavigateTab: (int index) => setState(() => _selectedIndex = index),
      ),
      TambahScreen(
        onSaved: _addMaintenance,
        onBack: () => setState(() => _selectedIndex = 0),
      ),
      RiwayatTab(
        list: _maintenanceList,
        onRefresh: () {},
        onBack: () => setState(() => _selectedIndex = 0),
      ),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) => setState(() => _selectedIndex = index),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle, size: 32), label: 'Tambah'),
          BottomNavigationBarItem(icon: Icon(Icons.description), label: 'Riwayat'),
        ],
      ),
    );
  }
}

// ================= 1. TAB HOME =================
class HomeTab extends StatelessWidget {
  final List<MaintenanceModel> list;
  final VoidCallback onRefresh;
  final Function(int) onNavigateTab;

  const HomeTab(
      {super.key,
        required this.list,
        required this.onRefresh,
        required this.onNavigateTab});

  @override
  Widget build(BuildContext context) {
    int totalCost = list.fold(0, (sum, item) => sum + item.rawCost);
    double avgCost = list.isEmpty ? 0 : totalCost / list.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'MAINTENANCE RUMAH',
              style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
            IconButton(
              icon: const Icon(Icons.cloud_sync, color: Colors.blue),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data tersinkronisasi otomatis dengan Firestore'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selamat datang kembali 👋',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const Text('Kelola biaya rumah lebih mudah.',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total pengeluaran bulan ini',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('Rp $totalCost',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('November 2026',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total maintenance',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('${list.length}',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('aktivitas tercatat',
                            style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rata-rata biaya',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('Rp ${avgCost.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('per aktivitas',
                            style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Aktivitas terbaru',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => onNavigateTab(2),
                  child: const Text('Semua', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            list.isEmpty
                ? const Center(
                child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('Belum ada data maintenance.')))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length > 3 ? 3 : list.length,
              itemBuilder: (BuildContext ctx, int index) {
                final item = list[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 4),
                          Text('${item.date} • ${item.category}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      Text('Rp ${item.rawCost}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ================= 2. TAB TAMBAH =================
class TambahScreen extends StatefulWidget {
  final Function(String, String, String, String, String) onSaved;
  final VoidCallback onBack;

  const TambahScreen({super.key, required this.onSaved, required this.onBack});

  @override
  State<TambahScreen> createState() => _TambahScreenState();
}

class _TambahScreenState extends State<TambahScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _costController = TextEditingController();
  final TextEditingController _technicianController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final FocusNode _titleFocus = FocusNode();
  final FocusNode _costFocus = FocusNode();
  final FocusNode _technicianFocus = FocusNode();
  final FocusNode _descFocus = FocusNode();

  String _selectedCategory = 'Elektronik';
  final List<String> _categoryOptions = [
    'Elektronik',
    'Plumbing',
    'Pengecatan',
    'Listrik',
    'Lainnya'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _costController.dispose();
    _technicianController.dispose();
    _descController.dispose();
    _titleFocus.dispose();
    _costFocus.dispose();
    _technicianFocus.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  void _submitData() {
    if (_titleController.text.isNotEmpty && _costController.text.isNotEmpty) {
      widget.onSaved(
        _titleController.text,
        _selectedCategory,
        _costController.text,
        _technicianController.text,
        _descController.text,
      );
      _titleController.clear();
      _costController.clear();
      _technicianController.clear();
      _descController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama maintenance dan Biaya wajib diisi!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Tambah Maintenance',
            style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catat pengeluaran baru',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              focusNode: _titleFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_costFocus),
              decoration: InputDecoration(
                labelText: 'Nama maintenance *',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Kategori *',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _categoryOptions.map((String category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _costController,
              focusNode: _costFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_technicianFocus),
              decoration: InputDecoration(
                labelText: 'Biaya (Angka) *',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _technicianController,
              focusNode: _technicianFocus,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_descFocus),
              decoration: InputDecoration(
                labelText: 'Teknisi',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              focusNode: _descFocus,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submitData(),
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitData,
                child: const Text('Simpan Maintenance',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= 3. TAB RIWAYAT =================
class RiwayatTab extends StatefulWidget {
  final List<MaintenanceModel> list;
  final VoidCallback onRefresh;
  final VoidCallback onBack;

  const RiwayatTab(
      {super.key,
        required this.list,
        required this.onRefresh,
        required this.onBack});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<RiwayatTab> {
  String _searchQuery = '';
  final FirestoreService _firestoreService = FirestoreService();

  void _showEditDialog(BuildContext parentContext, MaintenanceModel item) {
    final TextEditingController titleController =
    TextEditingController(text: item.title);
    final TextEditingController costController =
    TextEditingController(text: item.rawCost.toString());
    final TextEditingController technicianController =
    TextEditingController(text: item.technician);
    final TextEditingController descController =
    TextEditingController(text: item.description);
    String selectedCategory = item.category;

    final List<String> categoryOptions = [
      'Elektronik',
      'Plumbing',
      'Pengecatan',
      'Listrik',
      'Lainnya'
    ];

    if (!categoryOptions.contains(selectedCategory)) {
      selectedCategory = 'Elektronik';
    }

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Maintenance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration:
                  const InputDecoration(labelText: 'Nama maintenance'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: categoryOptions.map((cat) {
                    return DropdownMenuItem(value: cat, child: Text(cat));
                  }).toList(),
                  onChanged: (val) => selectedCategory = val!,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Biaya (Angka)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: technicianController,
                  decoration: const InputDecoration(labelText: 'Teknisi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Deskripsi'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    costController.text.isNotEmpty) {
                  item.title = titleController.text;
                  item.category = selectedCategory;
                  item.rawCost =
                      int.tryParse(costController.text) ?? item.rawCost;
                  item.technician = technicianController.text;
                  item.description = descController.text;

                  await _firestoreService.updateData(item);

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                          content: Text('Data berhasil diperbarui!'),
                          backgroundColor: Colors.blue),
                    );
                  }
                }
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = widget.list.where((item) {
      return item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Maintenance',
            style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: widget.onBack,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Catatan perawatan rumah (Cloud Firestore)',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Cari maintenance...',
                prefixIcon: const Icon(Icons.search),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text('${filteredList.length} catatan ditemukan',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Expanded(
              child: filteredList.isEmpty
                  ? const Center(child: Text('Tidak ada riwayat ditemukan.'))
                  : ListView.builder(
                itemCount: filteredList.length,
                itemBuilder: (BuildContext ctx, int index) {
                  final item = filteredList[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('${item.date} • ${item.category}',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                              if (item.technician.isNotEmpty &&
                                  item.technician != '-') ...[
                                const SizedBox(height: 2),
                                Text('Teknisi: ${item.technician}',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Rp ${item.rawCost}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87)),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blue, size: 20),
                              onPressed: () =>
                                  _showEditDialog(context, item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 20),
                              onPressed: () async {
                                if (item.id != null) {
                                  await _firestoreService
                                      .deleteData(item.id!);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
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