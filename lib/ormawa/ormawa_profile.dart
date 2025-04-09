import 'package:flutter/material.dart';
import '../component/navbar_ormawa.dart';
import '../services/auth_service.dart';

class OrmawaProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const OrmawaProfilePage({super.key, this.userData});

  @override
  State<OrmawaProfilePage> createState() => _OrmawaProfilePageState();
}

class _OrmawaProfilePageState extends State<OrmawaProfilePage> {
  final AuthService _authService = AuthService();
  final int _selectedIndex = 3;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
      print('Data profil yang digunakan: $_userData');
    }
  }

  Future<void> _handleLogout() async {
    final result = await _authService.logout();
    if (!mounted) return;

    if (result['success']) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.blue,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.blue,
                      child: Text(
                        _displayName.isNotEmpty
                            ? _displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _displayName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildProfileItem(
                      icon: Icons.person_outline,
                      title: 'NIM',
                      value: _userData?['nim']?.toString() ?? '-',
                    ),
                    _buildProfileItem(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: _userData?['email']?.toString() ?? '-',
                    ),
                    _buildProfileItem(
                      icon: Icons.phone_outlined,
                      title: 'No. Telepon',
                      value: _userData?['noHp']?.toString() ?? '-',
                    ),
                    _buildProfileItem(
                      icon: Icons.groups_outlined,
                      title: 'Organisasi',
                      value: _userData?['namaOrmawa']?.toString() ?? '-',
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleLogout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Keluar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: NavbarOrmawa(
        currentIndex: _selectedIndex,
        userData: _userData,
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
