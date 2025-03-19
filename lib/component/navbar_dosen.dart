import 'package:flutter/material.dart';
import '../dosen/dosen_beranda.dart';

class NavbarOrmawa extends StatelessWidget {
  final int currentIndex;

  const NavbarOrmawa({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
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
      onTap: (index) {
        if (index != currentIndex) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) {
                Widget page;
                switch (index) {
                  case 0:
                    page = const DosenBerandaPage();
                    break;
                  default:
                    page = const DosenBerandaPage();
                }
                return page;
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
}
