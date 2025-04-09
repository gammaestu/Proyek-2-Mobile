import 'package:flutter/material.dart';
import '../ormawa/ormawa_beranda.dart';
import '../ormawa/ormawa_pengajuan.dart';
import '../ormawa/ormawa_riwayat.dart';
import '../ormawa/ormawa_profile.dart';
import '../services/auth_service.dart';

class NavbarOrmawa extends StatelessWidget {
  final int currentIndex;
  final Map<String, dynamic>? userData;

  const NavbarOrmawa({
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
          icon: Icon(Icons.edit_document),
          label: 'Pengajuan',
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

          // Jika userData null, coba ambil dari AuthService
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
        return OrmawaBerandaPage(userData: userData);
      case 1:
        return OrmawaPengajuanPage(userData: userData);
      case 2:
        return OrmawaRiwayatPage(userData: userData);
      case 3:
        return OrmawaProfilePage(userData: userData);
      default:
        return OrmawaBerandaPage(userData: userData);
    }
  }
}
