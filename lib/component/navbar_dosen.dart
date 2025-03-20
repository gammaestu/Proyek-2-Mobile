import 'package:flutter/material.dart';
import '../dosen/dosen_beranda.dart';
import '../dosen/pengesahan_dosen.dart';
import '../dosen/riwayat_dosen.dart';


class NavbarDosen extends StatelessWidget {
  final int currentIndex;

  const NavbarDosen({super.key, required this.currentIndex});

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
                  case 1:
                    page = const DosenPengesahanPage();
                    break;
                  case 2:
                    page = const DosenRiwayatPage();
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
