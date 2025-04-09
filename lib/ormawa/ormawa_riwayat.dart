import 'package:flutter/material.dart';
import '../component/navbar_ormawa.dart';

class OrmawaRiwayatPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const OrmawaRiwayatPage({super.key, this.userData});

  @override
  State<OrmawaRiwayatPage> createState() => _OrmawaRiwayatPageState();
}

class _OrmawaRiwayatPageState extends State<OrmawaRiwayatPage> {
  final int _selectedIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat'),
        backgroundColor: Colors.blue,
      ),
      body: const Center(
        child: Text('Halaman Riwayat'),
      ),
      bottomNavigationBar: NavbarOrmawa(
        currentIndex: _selectedIndex,
        userData: widget.userData,
      ),
    );
  }
}
