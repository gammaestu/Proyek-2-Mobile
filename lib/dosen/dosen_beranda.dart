import 'package:flutter/material.dart';
import '../component/navbar_dosen.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';

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
      final result = await _documentService.getDocumentStatsForDosen(); // pastikan fungsi ini ada
      if (mounted) {
        setState(() {
          _documentStats = result['data'];
          _isLoading = false;
        });
        print('Document Stats Dosen: $_documentStats');
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
      return 'Dosen';
    }
    final nama = _userData!['namaDosen']?.toString() ?? 'Dosen';
    return nama;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SIGNIX"),
        backgroundColor: Colors.blue,
        automaticallyImplyLeading: false,
        actions: [
          Row(
            children: [
              Text(
                _displayName,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 10),
              const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.blue),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
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
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusCard(Icons.description, "Diajukan Ormawa", _documentStats?['diajukan'] ?? 0, Colors.amber),
                      _statusCard(Icons.verified, "Tertanda", _documentStats?['tertanda'] ?? 0, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statusCard(Icons.warning, "Perlu Direvisi", _documentStats?['direvisi'] ?? 0, Colors.red),
                      _statusCard(Icons.edit, "Sudah Direvisi", _documentStats?['sudahDirevisi'] ?? 0, Colors.blue),
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
  }

  Widget _statusCard(IconData icon, String title, int count, Color color) {
    return Container(
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
    );
  }
}