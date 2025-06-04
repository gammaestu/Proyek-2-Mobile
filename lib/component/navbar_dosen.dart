import 'package:flutter/material.dart';
import '../dosen/dosen_beranda.dart';
import '../dosen/pengesahan_dosen.dart';
import '../dosen/riwayat_dosen.dart';
import '../dosen/dosen_profile.dart';
import '../services/auth_service.dart';

class NavbarDosen extends StatefulWidget {
  final int currentIndex;
  final Map<String, dynamic>? userData;

  const NavbarDosen({
    super.key,
    required this.currentIndex,
    this.userData,
  });

  @override
  State<NavbarDosen> createState() => _NavbarDosenState();
}

class _NavbarDosenState extends State<NavbarDosen> {
  DateTime? _lastPressedAt; // Untuk double tap exit
  final List<int> _navigationStack = [
    0
  ]; // Stack untuk menyimpan history navigasi
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    if (!_navigationStack.contains(widget.currentIndex)) {
      _navigationStack.add(widget.currentIndex);
    }
  }

  Future<bool> _onWillPop() async {
    if (_navigationStack.length > 1) {
      // Hapus halaman saat ini dari stack
      _navigationStack.removeLast();
      // Ambil halaman sebelumnya
      final previousIndex = _navigationStack.last;

      // Ambil data user terbaru
      final userData = await _authService.getUser();
      if (userData == null) {
        Navigator.pushReplacementNamed(context, '/login');
        return false;
      }

      // Navigasi ke halaman sebelumnya
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return _buildPage(previousIndex, userData);
          },
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      return false;
    }

    // Jika di halaman utama, tanyakan konfirmasi keluar
    if (_lastPressedAt == null ||
        DateTime.now().difference(_lastPressedAt!) >
            const Duration(seconds: 2)) {
      // Update waktu terakhir ditekan
      _lastPressedAt = DateTime.now();

      // Tampilkan toast
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tekan sekali lagi untuk keluar'),
          duration: Duration(seconds: 2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Beranda',
            activeIcon: Icon(Icons.home, color: Colors.blue),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist),
            label: 'Pengesahan',
            activeIcon: Icon(Icons.checklist, color: Colors.blue),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Riwayat',
            activeIcon: Icon(Icons.history, color: Colors.blue),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
            activeIcon: Icon(Icons.person, color: Colors.blue),
          ),
        ],
        onTap: (index) async {
          if (index != widget.currentIndex) {
            if (!context.mounted) return;

            // Ambil data user terbaru
            final userData = await _authService.getUser();
            if (userData == null) {
              Navigator.pushReplacementNamed(context, '/login');
              return;
            }

            // Tambahkan halaman baru ke stack
            setState(() {
              _navigationStack.add(index);
            });

            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  return _buildPage(index, userData);
                },
                transitionDuration: const Duration(milliseconds: 300),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildPage(int index, Map<String, dynamic>? userData) {
    switch (index) {
      case 0:
        return DosenBerandaPage(userData: userData);
      case 1:
        return DosenPengesahanPage(userData: userData);
      case 2:
        return DosenRiwayatPage(userData: userData);
      case 3:
        return DosenProfilePage(userData: userData);
      default:
        return DosenBerandaPage(userData: userData);
    }
  }
}
