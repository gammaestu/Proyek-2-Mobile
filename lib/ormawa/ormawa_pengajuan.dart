import 'package:flutter/material.dart';
import '../component/navbar_ormawa.dart';
import '../services/document_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

// Test
class OrmawaPengajuanPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const OrmawaPengajuanPage({super.key, this.userData});

  @override
  State<OrmawaPengajuanPage> createState() => _OrmawaPengajuanPageState();
}

class _OrmawaPengajuanPageState extends State<OrmawaPengajuanPage> {
  final int _selectedIndex = 1;
  final _formKey = GlobalKey<FormState>();
  final _documentService = DocumentService();

  final _nomorSuratController = TextEditingController();
  final _halController = TextEditingController();
  final _catatanController = TextEditingController();

  PlatformFile? _selectedFile;
  bool _isLoading = false;

  // Tambahan untuk dropdown
  String? _selectedTujuan;
  List<Map<String, dynamic>> _dosenList = [];
  List<Map<String, dynamic>> _kemahasiswaanList = [];
  String? _selectedDosenId;
  String? _selectedKemahasiswaanId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      print('Loading dosen data...'); // Debug print
      final dosenResult = await _documentService.getDosenList();
      print('Dosen result: $dosenResult'); // Debug print

      if (dosenResult['success']) {
        final dosenData = List<Map<String, dynamic>>.from(dosenResult['data']);
        print('Parsed dosen data: $dosenData'); // Debug print

        setState(() {
          _dosenList = dosenData;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(dosenResult['message'] ?? 'Gagal memuat data dosen'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5), // Show error longer
              action: SnackBarAction(
                label: 'Coba Lagi',
                textColor: Colors.white,
                onPressed: _loadData,
              ),
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Coba Lagi',
              textColor: Colors.white,
              onPressed: _loadData,
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true, // This ensures we get the file bytes
      );

      if (result != null) {
        final file = result.files.first;

        // Check file size (max 10MB)
        if (file.size > 10 * 1024 * 1024) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran file tidak boleh lebih dari 10MB'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      print('Error picking file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih dokumen terlebih dahulu'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedTujuan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih tujuan pengajuan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedTujuan == 'Dosen' && _selectedDosenId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih dosen tujuan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Verify file bytes exist
    if (_selectedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File tidak valid, silakan pilih ulang'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String tujuanPengajuan = '';
      if (_selectedTujuan == 'Dosen' && _selectedDosenId != null) {
        // Cari nama dosen dari ID yang dipilih
        final selectedDosen = _dosenList.firstWhere(
          (dosen) => dosen['id'].toString() == _selectedDosenId,
          orElse: () => {'nama': 'Unknown'},
        );
        tujuanPengajuan = selectedDosen['nama'] ?? '';
      } else if (_selectedTujuan == 'Kemahasiswaan' &&
          _selectedKemahasiswaanId != null) {
        tujuanPengajuan = 'Kemahasiswaan';
      }

      final result = await _documentService.submitDocument(
        nomorSurat: _nomorSuratController.text,
        tujuanPengajuan: tujuanPengajuan,
        hal: _halController.text,
        fileBytes: _selectedFile!.bytes!,
        fileName: _selectedFile!.name,
        catatan: _catatanController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        // Reset form
        _formKey.currentState!.reset();
        setState(() {
          _selectedFile = null;
          _selectedTujuan = null;
          _selectedDosenId = null;
          _selectedKemahasiswaanId = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error submitting form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Surat'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FORMULIR PENGAJUAN',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomorSuratController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Surat',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nomor surat tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                enabled: false,
                initialValue:
                    widget.userData?['namaMahasiswa'] ?? 'Nama Pengaju',
                decoration: const InputDecoration(
                  labelText: 'Nama Pengaju',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                enabled: false,
                initialValue: widget.userData?['namaOrmawa'] ?? 'Nama Ormawa',
                decoration: const InputDecoration(
                  labelText: 'Nama Ormawa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedTujuan,
                decoration: const InputDecoration(
                  labelText: 'Tujuan Pengajuan',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Dosen',
                    child: Text('Dosen'),
                  ),
                  DropdownMenuItem(
                    value: 'Kemahasiswaan',
                    child: Text('Kemahasiswaan'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTujuan = value;
                    _selectedDosenId = null;
                    _selectedKemahasiswaanId = null;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Silakan pilih tujuan pengajuan';
                  }
                  return null;
                },
              ),
              if (_selectedTujuan == 'Dosen') ...[
                const SizedBox(height: 16),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          if (_dosenList.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Tidak ada data dosen. ',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  TextButton(
                                    onPressed: _loadData,
                                    child: const Text('Coba Lagi'),
                                  ),
                                ],
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedDosenId,
                              decoration: const InputDecoration(
                                labelText: 'Pilih Dosen',
                                border: OutlineInputBorder(),
                                hintText: 'Pilih dosen tujuan',
                              ),
                              items: _dosenList.map((dosen) {
                                print(
                                    'Creating dropdown item for dosen: $dosen'); // Debug print
                                return DropdownMenuItem(
                                  value: dosen['id'].toString(),
                                  child: Text(
                                      dosen['nama'] ?? 'Nama tidak tersedia'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedDosenId = value;
                                  print(
                                      'Selected dosen ID: $value'); // Debug print
                                });
                              },
                              validator: (value) {
                                if (_selectedTujuan == 'Dosen' &&
                                    (value == null || value.isEmpty)) {
                                  return 'Silakan pilih dosen';
                                }
                                return null;
                              },
                            ),
                        ],
                      ),
              ],
              if (_selectedTujuan == 'Kemahasiswaan') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedKemahasiswaanId,
                  decoration: const InputDecoration(
                    labelText: 'Pilih Kemahasiswaan',
                    border: OutlineInputBorder(),
                  ),
                  items: _kemahasiswaanList.map((kemahasiswaan) {
                    return DropdownMenuItem(
                      value: kemahasiswaan['id'].toString(),
                      child: Text(kemahasiswaan['nama']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedKemahasiswaanId = value;
                    });
                  },
                  validator: (value) {
                    if (_selectedTujuan == 'Kemahasiswaan' &&
                        (value == null || value.isEmpty)) {
                      return 'Silakan pilih kemahasiswaan';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _halController,
                decoration: const InputDecoration(
                  labelText: 'Hal',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Hal tidak boleh kosong';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unggah Dokumen'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedFile?.name ?? 'Tidak ada file dipilih',
                          style: TextStyle(
                            color: _selectedFile != null
                                ? Colors.black
                                : Colors.grey,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _pickFile,
                        child: const Text('Pilih File'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _catatanController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Ajukan'),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavbarOrmawa(
        currentIndex: _selectedIndex,
        userData: widget.userData,
      ),
    );
  }

  @override
  void dispose() {
    _nomorSuratController.dispose();
    _halController.dispose();
    _catatanController.dispose();
    super.dispose();
  }
}
