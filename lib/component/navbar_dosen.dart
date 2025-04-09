import 'package:flutter/material.dart';
import '../dosen/dosen_beranda.dart';
import '../dosen/pengesahan_dosen.dart';
import '../dosen/riwayat_dosen.dart';
import '../dosen/dosen_profile.dart';
import '../services/auth_service.dart';

class NavbarDosen extends StatelessWidget {
  final int currentIndex;
  final Map<String, dynamic>? userData;

  const NavbarDosen({
    super.key,
    required this.currentIndex,
    this.userData,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.checklist),
          label: 'Pengesahan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
      onTap: (index) async {
        if (index != currentIndex) {
          if (!context.mounted) return;

          // Ambil ulang userData jika null
          Map<String, dynamic>? finalUserData = userData;
          if (finalUserData == null) {
            final authService = AuthService();
            finalUserData = await authService.getUser();
          }

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                return _buildPage(index, finalUserData);
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
