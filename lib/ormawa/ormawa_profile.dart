import 'package:flutter/material.dart';
import '../component/navbar_ormawa.dart';
import '../component/appbar_ormawa.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  // Controller untuk form
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _noHpController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    Map<String, dynamic>? userData;
    if (widget.userData != null) {
      userData = widget.userData;
    } else {
      userData = await _authService.getUser();
    }
    if (mounted && userData != null) {
      setState(() {
        _userData = userData;
        _isLoading = false;
        _namaController.text = userData!['namaMahasiswa'] ?? '';
        _emailController.text = userData!['email'] ?? '';
        _noHpController.text = userData!['noHp'] ?? '';
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    final res = await _authService.updateProfile(
      namaMahasiswa: _namaController.text,
      email: _emailController.text,
      noHp: _noHpController.text,
    );
    setState(() => _isLoading = false);
    if (res['success'] == true) {
      // Simpan data user terbaru ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(res['data']));
      setState(() {
        _userData = res['data']; // Update state agar AppBar langsung refresh
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profil berhasil diupdate'),
            backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Gagal update profil'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _savePassword() async {
    setState(() => _isLoading = true);
    final res = await _authService.updatePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );
    setState(() => _isLoading = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password berhasil diubah'),
            backgroundColor: Colors.green),
      );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Gagal update password'),
            backgroundColor: Colors.red),
      );
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
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/login');
        return false;
      },
      child: Scaffold(
        appBar: AppBarOrmawa(userData: _userData),
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
                          _userData?['namaMahasiswa'] != null &&
                                  _userData!['namaMahasiswa'].isNotEmpty
                              ? _userData!['namaMahasiswa'][0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _namaController,
                        decoration: const InputDecoration(labelText: 'Nama'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noHpController,
                        decoration:
                            const InputDecoration(labelText: 'No. Telepon'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        enabled: false,
                        decoration: InputDecoration(
                          labelText: 'NIM',
                          hintText: _userData?['nim'] ?? '-',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          child: const Text('Simpan Perubahan'),
                        ),
                      ),
                      const Divider(height: 40),
                      const Text('Update Password',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _currentPasswordController,
                        decoration:
                            const InputDecoration(labelText: 'Password Lama'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPasswordController,
                        decoration:
                            const InputDecoration(labelText: 'Password Baru'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPasswordController,
                        decoration: const InputDecoration(
                            labelText: 'Konfirmasi Password Baru'),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _savePassword,
                          child: const Text('Update Password'),
                        ),
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
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailController.dispose();
    _noHpController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
