import 'package:flutter/material.dart';
import 'ormawa/ormawa_login.dart';
import './dosen/dosen_login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 150), // Menambah jarak atas agar logo turun
          // SIGNIX Logo Text
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'S',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'IGNI',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'X',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(
              flex: 3), // Memberikan ruang lebih besar di atas konten login
          // Konten login di tengah
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masuk Sebagai',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Login Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrmawaLoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Ormawa',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DosenLoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Dosen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 50), // Mengurangi jarak dengan widget biru
          // Widget biru melengkung
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to show the server configuration dialog
  void _showServerConfigDialog(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    String currentIp = ApiConfig.baseIp;
    String currentPort = ApiConfig.port;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Konfigurasi Server'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Masalah Koneksi Timeout?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pastikan:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '• HP dan laptop terhubung ke jaringan WiFi yang sama',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    '• Server Laravel berjalan di laptop Anda',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Text(
                    '• Firewall tidak memblokir koneksi',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Masukkan alamat IP server:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: currentIp,
                    decoration: const InputDecoration(
                      labelText: 'IP Address',
                      hintText: 'contoh: 192.168.1.5',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      currentIp = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: currentPort,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: 'contoh: 8000',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      currentPort = value;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () async {
                  if (currentIp.isNotEmpty && currentPort.isNotEmpty) {
                    // Update ApiConfig
                    ApiConfig.updateConfig(ip: currentIp, portNum: currentPort);

                    // Reset custom URL jika ada
                    AuthService.resetCustomUrl();

                    // Simpan ke SharedPreferences untuk persistensi
                    await prefs.setString('api_ip', currentIp);
                    await prefs.setString('api_port', currentPort);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Server diubah ke ${ApiConfig.baseUrl}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        });
      },
    );
  }
}
