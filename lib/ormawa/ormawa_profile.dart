import 'package:flutter/material.dart';
import '../component/navbar_ormawa.dart';

class OrmawaProfilPage extends StatelessWidget {
  const OrmawaProfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // App Bar
      appBar: AppBar(
        backgroundColor: Colors.blue,
        toolbarHeight: 75, // Standardize height
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SIGNIX',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                const Text(
                  'Mahasiswa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 15,
                  child: Icon(Icons.person, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ],
        ),
      ),

      // Body
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Picture Section
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue[100],
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.blue,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Form Fields
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileField('NIM', '', true),
                  const SizedBox(height: 16),
                  _buildProfileField('Nama', '', false),
                  const SizedBox(height: 16),
                  _buildProfileField('Alamat Email', '', true),
                  const SizedBox(height: 16),
                  _buildProfileField('Nomor Telepon', '', true),
                  const SizedBox(height: 16),
                  _buildProfileField('Ormawa', '', true),
                ],
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: const NavbarOrmawa(currentIndex: 3),
    );
  }

  Widget _buildProfileField(String label, String value, bool readOnly) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: value),
          readOnly: readOnly,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixIcon: !readOnly
                ? const Icon(
                    Icons.edit,
                    color: Colors.grey,
                    size: 20,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
