import 'package:flutter/material.dart';
import '../component/navbar_ormawa.dart';
import '../services/document_service.dart';
import '../services/auth_service.dart';

class OrmawaBerandaPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const OrmawaBerandaPage({super.key, this.userData});

  @override
  State<OrmawaBerandaPage> createState() => _OrmawaBerandaPageState();
}

class _OrmawaBerandaPageState extends State<OrmawaBerandaPage> {
  final int _selectedIndex = 0;
  final _documentService = DocumentService();
  final _authService = AuthService();
  Map<String, dynamic>? _documentStats;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDocumentStats();
  }

  Future<void> _loadUserData() async {
    Map<String, dynamic>? userData;

    // Coba ambil dari widget.userData dulu
    if (widget.userData != null) {
      userData = widget.userData;
      print('Data dari widget: $userData');
    } else {
      // Jika tidak ada, coba ambil dari penyimpanan
      userData = await _authService.getUser();
      print('Data dari penyimpanan: $userData');
    }

    if (mounted && userData != null) {
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
      print('Data pengguna yang digunakan: $_userData');
    }
  }

  Future<void> _loadDocumentStats() async {
    try {
      final result = await _documentService.getDocumentStats();
      if (mounted) {
        setState(() {
          _documentStats = result['data'];
          _isLoading = false;
        });
        print('Document Stats: $_documentStats'); // Debug print
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  String get _displayName {
    if (_userData == null) {
      print('Data pengguna kosong');
      return 'User';
    }

    // Ambil nama dari field namaMahasiswa
    final nama = _userData!['namaMahasiswa']?.toString() ?? 'User';
    print('Data pengguna lengkap: $_userData');
    print('Nama yang akan ditampilkan: $nama');
    return nama;
  }

  String get _userInitial {
    final name = _displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            // TODO: Navigate to filtered document list
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIGNIX'),
        backgroundColor: Colors.blue,
        actions: [
          CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
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
                  'Selamat Datang, $_displayName!',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Riwayat Dokumen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _buildStatCard(
                    'Surat Telah Diajukan',
                    _documentStats?['submitted'] ?? 0,
                    Colors.orange,
                    Icons.description_outlined,
                  ),
                  _buildStatCard(
                    'Surat Sudah Ditandatangani',
                    _documentStats?['signed'] ?? 0,
                    Colors.green,
                    Icons.check_circle_outline,
                  ),
                  _buildStatCard(
                    'Surat Perlu Direvisi',
                    _documentStats?['need_revision'] ?? 0,
                    Colors.red,
                    Icons.warning_outlined,
                  ),
                  _buildStatCard(
                    'Surat Sudah Direvisi',
                    _documentStats?['revised'] ?? 0,
                    Colors.blue,
                    Icons.edit_document,
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'FAQ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('FAQ Content'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavbarOrmawa(
        currentIndex: _selectedIndex,
        userData: _userData,
      ),
    );
  }
}
