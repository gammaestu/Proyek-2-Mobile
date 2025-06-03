import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import '../component/appbar_dosen.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import './pengesahan_dosen.dart';
import './riwayat_dosen.dart';

class DosenBerandaPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const DosenBerandaPage({super.key, this.userData});

  @override
  State<DosenBerandaPage> createState() => _DosenBerandaPageState();
}

class _DosenBerandaPageState extends State<DosenBerandaPage> {
  final int _selectedIndex = 0;
  final _authService = AuthService();
  final _documentService = DocumentService();

  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _documentStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDocumentStats();
  }

  Future<void> _loadUserData() async {
    Map<String, dynamic>? userData;

    if (widget.userData != null) {
      userData = widget.userData;
      print('Data dari widget: $userData');
    } else {
      userData = await _authService.getUser();
      print('Data dari penyimpanan: $userData');
    }

    if (mounted && userData != null) {
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
      print('Data dosen yang digunakan: $_userData');
    }
  }

  Future<void> _loadDocumentStats() async {
    try {
      print('Mulai mengambil statistik dokumen'); // Debug print
      setState(() => _isLoading = true);
      
      final result = await _documentService.getDocumentStatsForDosen();
      print('Hasil statistik: $result'); // Debug print
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _documentStats = result['data'];
            _isLoading = false;
          });
          print('Stats berhasil diupdate: $_documentStats');
        } else {
          throw Exception(result['message'] ?? 'Gagal mengambil statistik');
        }
      }
    } catch (e) {
      print('Error: $e'); // Debug print
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat statistik: ${e.toString()}')),
        );
      }
    }
  }

  String get _displayName {
    if (_userData == null) {
      return 'Dosen';
    }
    final nama = _userData!['namaDosen']?.toString() ?? 'Dosen';
    return nama;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarDosen(
        userData: _userData,
      ),
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadUserData(),
            _loadDocumentStats(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Selamat Datang, $_displayName!",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Status Dokumen",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusCard(
                        icon: Icons.description,
                        title: "Diajukan Ormawa",
                        count: _documentStats?['diajukan'] ?? 0,
                        color: Colors.amber,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DosenPengesahanPage(
                              userData: _userData,
                              initialStatusFilter: 'diajukan',
                            ),
                          ),
                        ),
                      ),
                      _statusCard(
                        icon: Icons.verified,
                        title: "Disahkan",
                        count: _documentStats?['disahkan'] ?? 0,
                        color: Colors.green,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DosenRiwayatPage(
                              userData: _userData,
                              initialStatusFilter: 'disahkan',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusCard(
                        icon: Icons.warning,
                        title: "Perlu Direvisi",
                        count: _documentStats?['butuh revisi'] ?? 0,
                        color: Colors.red,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DosenRiwayatPage(
                              userData: _userData,
                              initialStatusFilter: 'butuh revisi',
                            ),
                          ),
                        ),
                      ),
                      _statusCard(
                        icon: Icons.edit,
                        title: "Sudah Direvisi",
                        count: _documentStats?['sudah direvisi'] ?? 0,
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DosenPengesahanPage(
                              userData: _userData,
                              initialStatusFilter: 'sudah direvisi',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                const Text(
                  "FAQ",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavbarDosen(
        currentIndex: _selectedIndex,
        userData: _userData,
      ),
    );
  }  Widget _statusCard({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(
              "$count",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}