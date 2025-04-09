import 'package:flutter/material.dart';
import 'login_page.dart';
import 'ormawa/ormawa_login.dart';
import 'ormawa/ormawa_beranda.dart';
import 'ormawa/ormawa_pengajuan.dart';
import 'ormawa/ormawa_riwayat.dart';
import 'ormawa/ormawa_profile.dart';

import 'dosen/dosen_login.dart';
import 'dosen/dosen_beranda.dart';
import 'dosen/pengesahan_dosen.dart';
import 'dosen/riwayat_dosen.dart';
import 'dosen/dosen_profile.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signix',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      onGenerateRoute: (settings) {
        if (settings.name == '/ormawa_beranda') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => OrmawaBerandaPage(userData: args),
          );
        }

        // Tambahkan case lain jika perlu kirim arguments ke page lain
        switch (settings.name) {
          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginPage());
          case '/Ormawa':
            return MaterialPageRoute(builder: (_) => const OrmawaLoginPage());
          case '/pengajuan':
            return MaterialPageRoute(builder: (_) => const OrmawaPengajuanPage());
          case '/riwayat ormawa':
            return MaterialPageRoute(builder: (_) => const OrmawaRiwayatPage());
          case '/profil ormawa':
            return MaterialPageRoute(builder: (_) => const OrmawaProfilePage());
          case '/dosen':
            return MaterialPageRoute(builder: (_) => const DosenLoginPage());
          case '/dosen/beranda':
            return MaterialPageRoute(builder: (_) => const DosenBerandaPage());
          case '/dosen/pengesahan':
            return MaterialPageRoute(builder: (_) => const DosenPengesahanPage());
          
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('404 - Page not found')),
              ),
            );
        }
      },
      routes: {
        '/login': (context) => const LoginPage(),
        '/Ormawa': (context) => const OrmawaLoginPage(),
        //'/ormawa_beranda': (context) => const OrmawaBerandaPage(),
        '/pengajuan': (context) => const OrmawaPengajuanPage(),
        '/riwayat ormawa': (context) => const OrmawaRiwayatPage(),
        '/profil ormawa': (context) => const OrmawaProfilePage(),

        '/dosen': (context) => const DosenLoginPage(),
        '/dosen/beranda': (context) => const DosenBerandaPage(),
        '/dosen/pengesahan': (context) => const DosenPengesahanPage(),
        '/dosen/riwayat': (context) => const DosenRiwayatPage(),
        '/dosen/profil': (context) => const DosenProfilePage(),
      },
    );
  }
}
