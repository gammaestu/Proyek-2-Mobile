import 'package:flutter/material.dart';
import 'login_page.dart';
import 'ormawa/ormawa_login.dart';
import 'ormawa/ormawa_beranda.dart';
import 'ormawa/ormawa_pengajuan.dart';
import 'ormawa/ormawa_riwayat.dart';
import 'ormawa/ormawa_profile.dart';

import 'dosen/dosen_login.dart';
import 'dosen/dosen_beranda.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ormawa App',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginPage(),
        '/': (context) => const OrmawaLoginPage(),
        '/beranda': (context) => const OrmawaBerandaPage(),
        '/pengajuan': (context) => const OrmawaPengajuanPage(),
        '/riwayat': (context) => const OrmawaRiwayatPage(),
        '/profil': (context) => const OrmawaProfilPage(),

        '/dosen': (context) => const DosenLoginPage(),
        '/dosen/beranda': (context) => const DosenBerandaPage(),
      },
    );
  }
}
