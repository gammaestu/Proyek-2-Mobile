  import 'package:flutter/material.dart';
  import '../component/navbar_dosen.dart';
  import 'dart:convert';
  import 'package:http/http.dart' as http;

  class DosenPengesahanPage extends StatelessWidget {
    final Map<String, dynamic>? userData;

    const DosenPengesahanPage({super.key, this.userData});

    Future<List<dynamic>> fetchDokumen(int? dosenId) async {
      final response = await http.get(Uri.parse('http://localhost:8000/api/dosen/$dosenId/documents'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data']; // pastikan backend mengirim key 'data'
      } else {
        throw Exception('Gagal memuat data dokumen');
      }
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.blue,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "SIGNIX",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Text(
                    userData?['nama'] ?? "Dosen",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(width: 10),
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 16,
                    child: Icon(
                      Icons.person,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Perlu Pengesahan",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: fetchDokumen(userData?['id']), // Panggil fungsi ambil data
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Tidak ada dokumen'));
                    } else {
                      final dokumenList = snapshot.data!;
                      return ListView.builder(
                        itemCount: dokumenList.length,
                        itemBuilder: (context, index) {
                          final dokumen = dokumenList[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Nomor: ${dokumen['nomor_surat']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text("Pengirim: ${dokumen['pengirim']}"),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        contentPadding: const EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text("Detail Dokumen", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 12),
                                              
                                              // Kotak PDF Placeholder
                                              Container(
                                                width: double.infinity,
                                                height: 150,
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.blue),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Center(
                                                  child: Icon(Icons.picture_as_pdf, size: 50, color: Colors.grey),
                                                ),
                                              ),

                                              const SizedBox(height: 16),

                                              // Informasi dokumen
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text("Nomor Surat:\n${dokumen['nomor_surat']}", style: const TextStyle(fontSize: 12)),
                                                  Text("Status:\n${dokumen['status'] ?? 'Diajukan'}", style: const TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text("Tanggal Pengajuan:\n${dokumen['tanggal_pengajuan']}", style: const TextStyle(fontSize: 12)),
                                                  Text("Keterangan:\n${dokumen['keterangan']}", style: const TextStyle(fontSize: 12)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text("Perihal:\n${dokumen['perihal']}", style: const TextStyle(fontSize: 12)),
                                              ),

                                              const SizedBox(height: 16),

                                              // Tombol aksi
                                              Column(
                                                children: [
                                                  // Tombol atas: Lihat & Revisi
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                    children: [
                                                      ElevatedButton(
                                                        onPressed: () {},
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.orange,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                        child: const Text("Lihat"),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      ElevatedButton(
                                                        onPressed: () {},
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.red,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                        child: const Text("Revisi"),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),

                                                  // Tombol bawah: Download & Bubuhkan QR
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.start,
                                                    children: [
                                                      ElevatedButton(
                                                        onPressed: () {},
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.blue,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                        child: const Text("Download"),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      ElevatedButton(
                                                        onPressed: () {},
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: Colors.green,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                        child: const Text("Bubuhkan QR"),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),

                                                  // Tombol Tutup kanan
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: ElevatedButton(
                                                      onPressed: () => Navigator.pop(context),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.grey,
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      ),
                                                      child: const Text("Tutup"),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  child: const Text("Lihat Detail", style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),

            ],
          ),
        ),
        bottomNavigationBar: NavbarDosen(currentIndex: 1, userData: userData),
      );
    }
  }
