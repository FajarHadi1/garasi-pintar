import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart'; // Alat GPS Waktu
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // File rahasia yang baru saja kamu buat
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// --- 1. MENYIAPKAN ASISTEN NOTIFIKASI GLOBAL ---
final FlutterLocalNotificationsPlugin asistenNotifikasi =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- 1. NYALAKAN MESIN ZONA WAKTU ---
  tz.initializeTimeZones();

  // --- 2. DETEKSI LOKASI HP (Contoh: Asia/Jakarta) ---
  final zonaWaktu = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(
    tz.getLocation(zonaWaktu.identifier),
  ); // Ambil 'identifier' dari dalam kotaknya

  const AndroidInitializationSettings pengaturanAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings pengaturanAwal = InitializationSettings(
    android: pengaturanAndroid,
  );

  await asistenNotifikasi.initialize(settings: pengaturanAwal);

  runApp(const AplikasiPengingatku());
}

class AplikasiPengingatku extends StatelessWidget {
  const AplikasiPengingatku({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Garasi Pintar',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        textTheme: GoogleFonts.poppinsTextTheme(
          // Ganti semua font jadi Poppins!
          Theme.of(context).textTheme,
        ),
      ),
      debugShowCheckedModeBanner: false,

      // --- KODE BARU: POS SATPAM PENGECEKAN TIKET ---
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Jika Firebase masih loading mengecek status...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Jika ada data user (berarti tiketnya valid / sudah login)
          if (snapshot.hasData) {
            return const HalamanUtama();
          }

          // Jika tidak ada data user (belum login)
          return const HalamanLogin();
        },
      ),
      // ----------------------------------------------
    );
  }
}

class HalamanUtama extends StatefulWidget {
  const HalamanUtama({super.key});

  @override
  State<HalamanUtama> createState() => _HalamanUtamaState();
}

class _HalamanUtamaState extends State<HalamanUtama> {
  // --- KODE DIPERBARUI: TAMBAHKAN ORDER BY ---
  final Stream<QuerySnapshot> _aliranKendaraan = FirebaseFirestore.instance
      .collection('kendaraan')
      .where('uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
      .orderBy(
        'dibuat_pada',
        descending: true,
      ) // <--- KODE BARU INI TAMBAHKAN DI SINI
      .snapshots();

  final TextEditingController alatTulis = TextEditingController();
  DateTime? tanggalTerpilih;

  @override
  void initState() {
    super.initState();
    _mintaIzinNotifikasi();
  }

  // --- 3. MINTA IZIN KE PENGGUNA (UNTUK ANDROID 13+) ---
  void _mintaIzinNotifikasi() {
    asistenNotifikasi
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // --- 4. FUNGSI UNTUK MEMBUNYIKAN ALARM SEKARANG ---
  Future<void> _tesBunyikanNotifikasi() async {
    const AndroidNotificationDetails detailAndroid = AndroidNotificationDetails(
      'saluran_garasi',
      'Peringatan Garasi Pintar',
      channelDescription: 'Saluran untuk pengingat pajak dan service',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails detailNotifikasi = NotificationDetails(
      android: detailAndroid,
    );

    // PERBAIKAN 2: Kita beri nama id, title, body, dan notificationDetails
    await asistenNotifikasi.show(
      id: 0,
      title: 'Peringatan Garasi!',
      body: 'Ini adalah tes dari Asisten Garasi Pintar. Notifikasi berhasil!',
      notificationDetails: detailNotifikasi,
    );
  }

  // --- FUNGSI BARU: PENJADWAL ALARM OTOMATIS (H-7) ---
  Future<void> _jadwalkanPengingatPajak(
    String namaKendaraan,
    DateTime tglPajak,
    int offsetHari, // Pastikan parameter ini ada
  ) async {
    DateTime sekarang = DateTime.now();
    DateTime jadwalBunyi;

    // 1. GUNAKAN VARIABEL USER (Bukan angka 7 yang dikunci)
    // Jika tglPajak 17 Agustus & offsetHari 30, maka jadwalBunyi jadi 18 Juli
    jadwalBunyi = tglPajak.subtract(Duration(days: offsetHari));

    // Set jamnya agar sopan (jam 8 pagi)
    jadwalBunyi = DateTime(
      jadwalBunyi.year,
      jadwalBunyi.month,
      jadwalBunyi.day,
      8,
      0,
    );

    // 2. LOGIKA PENGAMAN (Mirip punyamu yang lama)
    // 2. LOGIKA PENGAMAN
    if (jadwalBunyi.isBefore(sekarang)) {
      // OPSI A: Jika ingin langsung muncul detik ini juga
      await asistenNotifikasi.show(
        id: namaKendaraan.hashCode + 1, // Pakai label 'id:'
        title:
            'Pajak $namaKendaraan Jatuh Tempo HARI INI!', // Pakai label 'title:'
        body:
            'Perhatian! Masa berlaku pajak Anda habis. Segera lakukan pembayaran.', // Pakai label 'body:'
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'saluran_pajak',
            'Pengingat Pajak Otomatis',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );

      // Tetap jadwalkan untuk besok pagi sebagai pengingat kedua
      jadwalBunyi = DateTime(
        sekarang.year,
        sekarang.month,
        sekarang.day + 1,
        8,
        0,
      );
    }

    // 3. CEK TERAKHIR: Jangan pasang alarm jika pajak memang sudah lewat tahunnya
    if (tglPajak.isBefore(sekarang)) return;

    // 4. EKSEKUSI (Gunakan kode zonedSchedule yang sudah diperbaiki kelengkapannya)
    await asistenNotifikasi.zonedSchedule(
      id: namaKendaraan.hashCode,
      title: 'Pajak $namaKendaraan Hampir Habis!',
      body:
          'Perhatian! Jatuh tempo dalam $offsetHari hari lagi (${tglPajak.day}/${tglPajak.month}).',
      scheduledDate: tz.TZDateTime.from(jadwalBunyi, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'saluran_pajak',
          'Pengingat Pajak Otomatis',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    ); // <--- Tutup langsung di siniÍ
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Garasi Pintar',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            onPressed: _tesBunyikanNotifikasi,
          ),
          // --- KODE BARU: TOMBOL LOGOUT ---
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              // Otomatis akan dilempar kembali ke Halaman Login oleh Pos Satpam!
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _aliranKendaraan,
        builder: (context, snapshot) {
          // Jika masih loading atau error
          if (snapshot.hasError)
            return const Center(child: Text('Terjadi kesalahan data.'));
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          // Ambil semua data dari Cloud!
          final dataKendaraan = snapshot.data!.docs;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- KOTAK TOTAL KENDARAAN ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.teal, Color.fromARGB(255, 33, 114, 106)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Kendaraan',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${dataKendaraan.length} Unit', // <-- SEKARANG MENGHITUNG DATA DARI CLOUD
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Text(
                  'Daftar Garasi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

              // --- LIST VIEW DAFTAR KENDARAAN ---
              Expanded(
                child: dataKendaraan.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.garage_outlined,
                              size: 100,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Garasimu Masih Kosong',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Ayo tambahkan kendaraan pertamamu\ndan mulai catat riwayat servisnya!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 25,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'Tambah Kendaraan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed:
                                  _tampilkanFormTambah, // Langsung buka form!
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: dataKendaraan.length,
                        itemBuilder: (context, index) {
                          var doc = dataKendaraan[index];
                          var kendaraan = doc.data() as Map<String, dynamic>;
                          String idDokumen = doc.id; // KTP unik dari Firebase
                          String jenis = kendaraan['jenis'] ?? 'Mobil';
                          IconData ikonKendaraan = jenis == 'Motor'
                              ? Icons.motorcycle
                              : Icons.directions_car;

                          // Hitung Sisa Hari Pajak
                          int sisaHari = 999;
                          if (kendaraan['pajak'] != null &&
                              kendaraan['pajak'] != 'Belum diset') {
                            try {
                              List<String> pecah = kendaraan['pajak']!.split(
                                '/',
                              );
                              DateTime tglPajak = DateTime(
                                int.parse(pecah[2]),
                                int.parse(pecah[1]),
                                int.parse(pecah[0]),
                              );
                              sisaHari = tglPajak
                                  .difference(DateTime.now())
                                  .inDays;
                            } catch (e) {}
                          }

                          Color warnaIkon = sisaHari < 0
                              ? Colors.red
                              : (sisaHari <= 30 ? Colors.orange : Colors.teal);
                          String statusTeks = sisaHari < 0
                              ? 'PAJAK MATI!'
                              : (sisaHari <= 30 ? 'PAJAK DEKAT' : 'Semua Aman');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Dismissible(
                              key: Key(idDokumen),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),

                                      icon: const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.red,
                                        size: 45,
                                      ), // Ikon ditaruh di tempat resminya
                                      title: const Text(
                                        'Hapus Kendaraan?',
                                        textAlign: TextAlign.center,
                                      ),
                                      content: Text(
                                        'Apakah Anda yakin ingin menghapus "${kendaraan['nama']}" beserta seluruh riwayat servisnya?\n\nData tidak dapat dikembalikan.',
                                        textAlign: TextAlign.center,
                                      ),
                                      actionsAlignment:
                                          MainAxisAlignment.center,
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(
                                                false,
                                              ), // Batal hapus (kembalikan kartu)
                                          child: const Text(
                                            'Batal',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                          onPressed: () => Navigator.of(
                                            context,
                                          ).pop(true), // Lanjut hapus
                                          child: const Text(
                                            'Hapus Permanen',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                              onDismissed: (direction) {
                                // HAPUS DATA DARI CLOUD FIRESTORE
                                FirebaseFirestore.instance
                                    .collection('kendaraan')
                                    .doc(idDokumen)
                                    .delete();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${kendaraan['nama']} berhasil dihapus dari Cloud!',
                                    ),
                                  ),
                                );
                              },
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HalamanDetail(
                                        kendaraan: kendaraan,
                                        docId:
                                            idDokumen, // Kirim KTP Firebase ke Halaman Detail
                                      ),
                                    ),
                                  );
                                },
                                child: Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: ListTile(
                                    leading: Hero(
                                      tag:
                                          'avatar_kendaraan_$idDokumen', // Tag penerbangan unik
                                      child: CircleAvatar(
                                        backgroundColor: warnaIkon.withOpacity(
                                          0.1,
                                        ),
                                        child: Icon(
                                          ikonKendaraan,
                                          color: warnaIkon,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      kendaraan['nama'] ?? 'Tanpa Nama',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      statusTeks,
                                      style: TextStyle(
                                        color: warnaIkon,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _tampilkanFormTambah,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _tampilkanFormTambah() {
    final alatTulis = TextEditingController();
    DateTime? tanggalTerpilih;
    String jenisTerpilih = 'Mobil';

    // --- VARIABEL BARU: Default Pengingat H-7 ---
    int hariPengingat = 7;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 25,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tambah ke Garasi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // 1. DROPDOWN JENIS
                DropdownButtonFormField<String>(
                  value: jenisTerpilih,
                  decoration: InputDecoration(
                    labelText: 'Jenis Kendaraan',
                    prefixIcon: const Icon(Icons.category, color: Colors.teal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Mobil', child: Text('Mobil 🚗')),
                    DropdownMenuItem(value: 'Motor', child: Text('Motor 🏍️')),
                  ],
                  onChanged: (value) {
                    if (value != null)
                      setModalState(() => jenisTerpilih = value);
                  },
                ),
                const SizedBox(height: 15),

                // 2. INPUT NAMA
                TextField(
                  controller: alatTulis,
                  decoration: InputDecoration(
                    labelText: 'Nama Kendaraan (Misal: NMAX, Avanza)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // 3. KALENDER PAJAK
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  tileColor: Colors.grey.shade100,
                  leading: const Icon(Icons.calendar_month, color: Colors.teal),
                  title: Text(
                    tanggalTerpilih == null
                        ? 'Pilih Tanggal Jatuh Tempo Pajak'
                        : '${tanggalTerpilih!.day}/${tanggalTerpilih!.month}/${tanggalTerpilih!.year}',
                  ),
                  onTap: () async {
                    final hasil = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate:
                          DateTime.now(), // Cegah pilih tanggal masa lalu
                      lastDate: DateTime(2030),
                    );
                    if (hasil != null)
                      setModalState(() => tanggalTerpilih = hasil);
                  },
                ),
                const SizedBox(height: 15),

                // --- 4. KODE BARU: DROPDOWN WAKTU PENGINGAT ---
                DropdownButtonFormField<int>(
                  value: hariPengingat,
                  decoration: InputDecoration(
                    labelText: 'Ingatkan Saya',
                    prefixIcon: const Icon(
                      Icons.notifications_active,
                      color: Colors.teal,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 30,
                      child: Text('1 Bulan Sebelum (H-30)'),
                    ),
                    DropdownMenuItem(
                      value: 14,
                      child: Text('2 Minggu Sebelum (H-14)'),
                    ),
                    DropdownMenuItem(
                      value: 7,
                      child: Text('1 Minggu Sebelum (H-7)'),
                    ),
                    DropdownMenuItem(
                      value: 3,
                      child: Text('3 Hari Sebelum (H-3)'),
                    ),
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Tepat pada Hari H'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null)
                      setModalState(() => hariPengingat = value);
                  },
                ),
                // ----------------------------------------------
                const SizedBox(height: 25),

                // 5. TOMBOL SIMPAN
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      if (alatTulis.text.isNotEmpty &&
                          tanggalTerpilih != null) {
                        String tglPajakString =
                            '${tanggalTerpilih!.day}/${tanggalTerpilih!.month}/${tanggalTerpilih!.year}';
                        final String uidPengguna =
                            FirebaseAuth.instance.currentUser!.uid;

                        // Simpan ke Firestore
                        FirebaseFirestore.instance.collection('kendaraan').add({
                          'nama': alatTulis.text,
                          'pajak': tglPajakString,
                          'riwayat': [],
                          'dokumen': [],
                          'dibuat_pada': FieldValue.serverTimestamp(),
                          'uid': uidPengguna,
                          'jenis': jenisTerpilih,
                          'pengingat_pajak_hari':
                              hariPengingat, // <--- Simpan preferensi waktu
                        });

                        // Jadwalkan notifikasi dengan parameter tambahan
                        try {
                          _jadwalkanPengingatPajak(
                            alatTulis.text,
                            tanggalTerpilih!,
                            hariPengingat,
                          );
                        } catch (e) {
                          print("Gagal set alarm: $e");
                        }

                        Navigator.pop(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Harap isi Nama Kendaraan dan Tanggal Pajak!',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Simpan Kendaraan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// KELAS HALAMAN DETAIL & DOKUMEN TETAP SAMA SEPERTI SEBELUMNYA
// (Tolong paste-kan class HalamanDetail dan HalamanDokumen milikmu
// di bagian bawah ini agar kodenya tidak terpotong)
// ======================================================================

class HalamanDetail extends StatefulWidget {
  final Map<String, dynamic> kendaraan;
  final String docId;
  const HalamanDetail({
    super.key,
    required this.kendaraan,
    required this.docId,
  });

  @override
  State<HalamanDetail> createState() => _HalamanDetailState();
}

class _HalamanDetailState extends State<HalamanDetail> {
  double get totalBiaya {
    List riwayat = widget.kendaraan['riwayat'] ?? [];
    double total = 0;
    for (var item in riwayat) {
      total += double.tryParse(item['biaya'].toString()) ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    List riwayat = widget.kendaraan['riwayat'] ?? [];
    String jenis = widget.kendaraan['jenis'] ?? 'Mobil';
    IconData ikonKendaraan = jenis == 'Motor'
        ? Icons.motorcycle
        : Icons.directions_car;
    String? targetKm = widget.kendaraan['target_km_berikutnya'];
    String? targetTgl = widget.kendaraan['target_tgl_berikutnya'];
    String kmSekarang = widget.kendaraan['km_terakhir'] ?? '0';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kendaraan['nama']),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_document),
            tooltip: 'Edit Kendaraan',
            onPressed: () =>
                _tampilFormEdit(context), // Kita akan buat fungsinya di bawah
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Hero(
                    tag: 'avatar_kendaraan_${widget.docId}',
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.teal.withOpacity(0.1),
                      child: Icon(
                        ikonKendaraan,
                        size: 40,
                        color: Colors.teal,
                      ), // <--- UBAH DI SINI
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (targetKm != null || targetTgl != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.teal.shade100),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (targetKm != null)
                            Column(
                              children: [
                                const Text(
                                  'Sisa Jarak',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '${int.parse(targetKm) - int.parse(kmSekarang)} KM',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          if (targetTgl != null)
                            Column(
                              children: [
                                const Text(
                                  'Target Tanggal',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  targetTgl,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  if (widget.kendaraan['riwayat'].isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: PieChart(
                        PieChartData(
                          sections: _generateChartData(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // --- TOMBOL UX BARU: PERPANJANG 1 TAHUN ---
                  Center(
                    child: ActionChip(
                      elevation: 2,
                      backgroundColor: Colors.teal.shade50,
                      side: const BorderSide(color: Colors.teal),
                      avatar: const Icon(Icons.update, color: Colors.teal),
                      label: const Text(
                        'Perpanjang Pajak (1 Tahun)',
                        style: TextStyle(
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () =>
                          _perpanjangPajakOtomatis(), // Panggil fungsi ajaib kita
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Total Investasi Perawatan',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Rp ${totalBiaya.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buatMenuKecil(
                    Icons.build_circle,
                    'Service',
                    Colors.orange,
                    () => _tampilkanStatusKesehatan(),
                  ),
                  _buatMenuKecil(
                    Icons.account_balance_wallet,
                    'Uang',
                    Colors.blue,
                    () => _tampilkanLaporanKeuangan(),
                  ),
                  _buatMenuKecil(
                    Icons.speed,
                    'Update KM',
                    Colors.purple,
                    () => _tampilFormKM(context),
                  ),

                  // --- TOMBOL MENU LACI DOKUMEN ---
                  _buatMenuKecil(
                    Icons.document_scanner,
                    'Dokumen',
                    Colors.red,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              HalamanDokumen(kendaraan: widget.kendaraan),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.history, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Riwayat Perawatan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            riwayat.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: Text('Belum ada catatan servis.')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: riwayat.length,
                    itemBuilder: (context, index) {
                      final item = riwayat[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          onLongPress: () => _konfirmasiHapusRiwayat(
                            index,
                          ), // Tekan lama untuk hapus
                          onTap: () => _tampilFormEditRiwayat(
                            index,
                            item,
                          ), // Ketuk untuk edit
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(
                              Icons.build,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item['pekerjaan'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'KM: ${item['km']} | Rp ${item['biaya']}',
                          ),
                          trailing: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _tampilFormCatatServisCepat(),
        label: const Text(
          'Catat Service',
          style: TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.add_task, color: Colors.white),
        backgroundColor: Colors.teal,
      ),
    );
  }

  Widget _buatMenuKecil(
    IconData ikon,
    String judul,
    Color warna,
    VoidCallback aksiKlik,
  ) {
    return InkWell(
      onTap: aksiKlik,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 75,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, size: 28, color: warna),
            const SizedBox(height: 5),
            Text(
              judul,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _tampilFormKM(BuildContext context) {
    final kmSekarangCtl = TextEditingController(
      text: widget.kendaraan['km_sekarang'] ?? '',
    );
    final kmTargetCtl = TextEditingController(
      text: widget.kendaraan['km_target'] ?? '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.speed, color: Colors.purple),
            SizedBox(width: 10),
            Text('Update KM'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kmSekarangCtl,
              decoration: const InputDecoration(
                labelText: 'KM di Speedometer saat ini',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: kmTargetCtl,
              decoration: const InputDecoration(
                labelText: 'Target KM Service Selanjutnya',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              setState(() {
                widget.kendaraan['km_sekarang'] = kmSekarangCtl.text;
                widget.kendaraan['km_target'] = kmTargetCtl.text;
              });
              _simpanPerubahanKeBrankas();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI BARU: POP-UP EDIT PROFIL KENDARAAN ---
  void _tampilFormEdit(BuildContext context) {
    // 1. Siapkan alat tulis dan isikan dengan nama yang sekarang
    final namaCtl = TextEditingController(text: widget.kendaraan['nama']);
    DateTime? tglTerpilih;

    // 2. Coba baca tanggal lama agar kalendernya tidak mulai dari nol
    if (widget.kendaraan['pajak'] != null &&
        widget.kendaraan['pajak'] != 'Belum diset') {
      try {
        List<String> pecah = widget.kendaraan['pajak'].split('/');
        tglTerpilih = DateTime(
          int.parse(pecah[2]),
          int.parse(pecah[1]),
          int.parse(pecah[0]),
        );
      } catch (e) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 25,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Profil Kendaraan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: namaCtl,
                decoration: InputDecoration(
                  labelText: 'Nama Kendaraan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                tileColor: Colors.grey[100],
                leading: const Icon(Icons.calendar_month, color: Colors.teal),
                title: Text(
                  tglTerpilih == null
                      ? 'Pilih Tanggal Pajak'
                      : '${tglTerpilih!.day}/${tglTerpilih!.month}/${tglTerpilih!.year}',
                ),
                onTap: () async {
                  final hasil = await showDatePicker(
                    context: context,
                    initialDate:
                        tglTerpilih ??
                        DateTime.now(), // Mulai dari tanggal lama
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (hasil != null) setModalState(() => tglTerpilih = hasil);
                },
              ),
              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () async {
                    if (namaCtl.text.isNotEmpty && tglTerpilih != null) {
                      // 1. Siapkan format tanggal baru
                      String tanggalBaru =
                          '${tglTerpilih!.day}/${tglTerpilih!.month}/${tglTerpilih!.year}';

                      // 2. Update tampilan di layar HP (agar langsung berubah tanpa nunggu internet)
                      setState(() {
                        widget.kendaraan['nama'] = namaCtl.text;
                        widget.kendaraan['pajak'] = tanggalBaru;
                      });

                      // 3. --- OPERASI JANTUNG: UPDATE LANGSUNG KE CLOUD ☁️ ---
                      // Kita tidak butuh lagi SharedPreferences, jsonDecode, atau indexWhere!
                      try {
                        await FirebaseFirestore.instance
                            .collection('kendaraan')
                            .doc(
                              widget.docId,
                            ) // Menggunakan KTP unik dari Firebase
                            .update({
                              'nama': namaCtl.text,
                              'pajak': tanggalBaru,
                            });
                        print("Data berhasil diupdate di Cloud!");
                      } catch (e) {
                        print("Gagal update Cloud: $e");
                      }

                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- FUNGSI: HAPUS RIWAYAT DENGAN KONFIRMASI ---
  void _konfirmasiHapusRiwayat(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Catatan?'),
        content: const Text(
          'Data servis ini akan dihapus permanen dari riwayat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                widget.kendaraan['riwayat'].removeAt(index);
              });
              _simpanPerubahanKeBrankas();
              Navigator.pop(context);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI: EDIT RIWAYAT YANG SUDAH ADA ---
  void _tampilFormEditRiwayat(int index, Map itemLama) {
    final kerjactl = TextEditingController(text: itemLama['pekerjaan']);
    final kmctl = TextEditingController(text: itemLama['km']);
    final biayaScale = TextEditingController(text: itemLama['biaya']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Detail Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: kerjactl,
              decoration: const InputDecoration(labelText: 'Pekerjaan'),
            ),
            TextField(
              controller: kmctl,
              decoration: const InputDecoration(labelText: 'Kilometer'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: biayaScale,
              decoration: const InputDecoration(labelText: 'Biaya'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                widget.kendaraan['riwayat'][index] = {
                  'tanggal': itemLama['tanggal'], // Tanggal tetap sama
                  'pekerjaan': kerjactl.text,
                  'km': kmctl.text,
                  'biaya': biayaScale.text,
                };
              });
              _simpanPerubahanKeBrankas();
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // --- FUNGSI BARU: PERPANJANG PAJAK 1-KLIK ---
  void _perpanjangPajakOtomatis() {
    // 1. Hitung tanggal saran (default +1 tahun dari tanggal saat ini di data)
    List<String> pecah = widget.kendaraan['pajak'].split('/');
    DateTime tglLama = DateTime(
      int.parse(pecah[2]),
      int.parse(pecah[1]),
      int.parse(pecah[0]),
    );
    DateTime tglSaran = DateTime(tglLama.year + 1, tglLama.month, tglLama.day);

    // Variabel untuk menyimpan tanggal yang dipilih (defaultnya adalah tglSaran)
    DateTime tglDipilih = tglSaran;
    TextEditingController biayaCtl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // Pakai StatefulBuilder agar modal bisa update tampilan saat ganti tanggal
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Perpanjang Pajak 🚀'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tanggal jatuh tempo berikutnya:'),
              const SizedBox(height: 10),

              // TANGGAL YANG BISA DIKLIK UNTUK DIUBAH
              InkWell(
                onTap: () async {
                  final hasil = await showDatePicker(
                    context: context,
                    initialDate: tglDipilih,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (hasil != null) {
                    setModalState(() => tglDipilih = hasil);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.teal),
                      const SizedBox(width: 10),
                      Text(
                        '${tglDipilih.day}/${tglDipilih.month}/${tglDipilih.year}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '*Klik tanggal di atas jika ingin mengubah',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),

              const SizedBox(height: 20),
              TextField(
                controller: biayaCtl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Biaya Pajak (Rp)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  prefixIcon: const Icon(Icons.payments),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                setState(() {
                  // A. Update ke tanggal yang dipilih (manual atau otomatis)
                  widget.kendaraan['pajak'] =
                      '${tglDipilih.day}/${tglDipilih.month}/${tglDipilih.year}';

                  // B. Catat ke riwayat
                  if (biayaCtl.text.isNotEmpty) {
                    widget.kendaraan['riwayat'].insert(0, {
                      'tanggal':
                          '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      'pekerjaan': 'Bayar Pajak Tahunan',
                      'km': '-',
                      'biaya': biayaCtl.text,
                    });
                  }
                });

                _simpanPerubahanKeBrankas();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pajak berhasil diperbarui! 🎉'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: const Text(
                'Simpan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- FUNGSI UX BARU: CATAT SERVIS CEPAT ---
  void _tampilFormCatatServisCepat() {
    final pekerjaanCtl = TextEditingController();
    final kmCtl = TextEditingController();
    final biayaCtl = TextEditingController();

    // --- VARIABEL BARU UNTUK PENGINGAT ---
    bool aktifkanPengingat = false;
    final targetKmCtl = TextEditingController();
    DateTime? targetTanggal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 25,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            // Tambahkan agar aman saat keyboard muncul
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Catat Servis & Pengingat',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: pekerjaanCtl,
                  decoration: InputDecoration(
                    labelText: 'Pekerjaan Servis',
                    prefixIcon: const Icon(Icons.build),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: kmCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'KM Saat Ini',
                          prefixIcon: const Icon(Icons.speed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: biayaCtl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Biaya (Rp)',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 40),

                // --- BAGIAN PENGINGAT CUSTOM ---
                SwitchListTile(
                  title: const Text(
                    'Ingatkan Servis Berikutnya',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Atur target KM atau tanggal servis'),
                  value: aktifkanPengingat,
                  activeColor: Colors.teal,
                  onChanged: (val) =>
                      setModalState(() => aktifkanPengingat = val),
                ),

                if (aktifkanPengingat) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: targetKmCtl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target KM Berikutnya (Custom)',
                      hintText: 'Misal: 12000',
                      prefixIcon: const Icon(Icons.event_repeat),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    leading: const Icon(
                      Icons.calendar_today,
                      color: Colors.teal,
                    ),
                    title: Text(
                      targetTanggal == null
                          ? 'Pilih Target Tanggal'
                          : 'Target: ${targetTanggal!.day}/${targetTanggal!.month}/${targetTanggal!.year}',
                    ),
                    onTap: () async {
                      final tgl = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 90),
                        ), // Default 3 bulan ke depan
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (tgl != null) setModalState(() => targetTanggal = tgl);
                    },
                  ),
                ],

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () async {
                      if (pekerjaanCtl.text.isNotEmpty &&
                          biayaCtl.text.isNotEmpty) {
                        // Data riwayat
                        Map<String, dynamic> riwayatBaru = {
                          'pekerjaan': pekerjaanCtl.text,
                          'km': kmCtl.text,
                          'biaya': biayaCtl.text,
                          'tanggal': DateTime.now().toIso8601String(),
                          // Simpan target jika aktif
                          'target_km': aktifkanPengingat
                              ? targetKmCtl.text
                              : null,
                          'target_tanggal':
                              aktifkanPengingat && targetTanggal != null
                              ? '${targetTanggal!.day}/${targetTanggal!.month}/${targetTanggal!.year}'
                              : null,
                        };

                        List riwayatSekarang =
                            widget.kendaraan['riwayat'] ?? [];
                        riwayatSekarang.add(riwayatBaru);

                        // Update Firestore
                        await FirebaseFirestore.instance
                            .collection('kendaraan')
                            .doc(widget.docId)
                            .update({
                              'riwayat': riwayatSekarang,
                              // Update juga status "KM Terakhir" kendaraan utamanya
                              'km_terakhir': kmCtl.text,
                              'target_km_berikutnya': aktifkanPengingat
                                  ? targetKmCtl.text
                                  : widget.kendaraan['target_km_berikutnya'],
                              'target_tgl_berikutnya':
                                  aktifkanPengingat && targetTanggal != null
                                  ? '${targetTanggal!.day}/${targetTanggal!.month}/${targetTanggal!.year}'
                                  : widget.kendaraan['target_tgl_berikutnya'],
                            });

                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      'Simpan & Atur Pengingat',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- KODE BARU: UPDATE DATA SPESIFIK KE CLOUD ☁️ ---
  Future<void> _simpanPerubahanKeBrankas() async {
    try {
      // Kita cari KTP kendaraannya (docId), lalu kita 'update' isinya
      await FirebaseFirestore.instance
          .collection('kendaraan')
          .doc(widget.docId) // Menggunakan ID KTP dari halaman sebelumnya
          .update({
            'riwayat':
                widget.kendaraan['riwayat'], // Kirim array riwayat terbaru
            'pajak': widget.kendaraan['pajak'], // Kirim tanggal pajak terbaru
          });
      print("Berhasil update riwayat ke Cloud!");
    } catch (e) {
      print("Gagal update ke Cloud: $e");
    }
  }

  List<PieChartSectionData> _generateChartData() {
    Map<String, double> kategoriBiaya = {};

    for (var item in widget.kendaraan['riwayat']) {
      String label = item['pekerjaan'].toString().toLowerCase();
      double biaya = double.tryParse(item['biaya'].toString()) ?? 0;

      // Pengelompokan sederhana
      String kategori = 'Lainnya';
      if (label.contains('pajak'))
        kategori = 'Pajak';
      else if (label.contains('oli'))
        kategori = 'Oli';
      else if (label.contains('servis') || label.contains('cvt'))
        kategori = 'Servis';
      else if (label.contains('ban') || label.contains('rem'))
        kategori = 'Sparepart';

      kategoriBiaya[kategori] = (kategoriBiaya[kategori] ?? 0) + biaya;
    }

    // Warna untuk setiap kategori
    List<Color> warna = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.red,
      Colors.purple,
    ];
    int i = 0;

    return kategoriBiaya.entries.map((entry) {
      final color = warna[i % warna.length];
      i++;
      return PieChartSectionData(
        color: color,
        value: entry.value,
        title: entry.key,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  void _tampilkanStatusKesehatan() {
    // Ambil data target dari dokumen kendaraan utama
    String? tglTargetStr = widget.kendaraan['target_tgl_berikutnya'];
    String? kmTargetStr = widget.kendaraan['target_km_berikutnya'];
    String? kmTerakhirStr = widget.kendaraan['km_terakhir'] ?? '0';

    if (tglTargetStr == null && kmTargetStr == null) {
      // Jika belum pernah set pengingat
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada target pengingat. Silakan catat servis terlebih dahulu.',
          ),
        ),
      );
      return;
    }

    // --- LOGIKA HITUNG SISA ---
    int kmSekarang = int.tryParse(kmTerakhirStr ?? '0') ?? 0;
    int kmTarget = int.tryParse(kmTargetStr ?? '0') ?? 0;
    int sisaKm = kmTarget - kmSekarang;

    // Hitung sisa hari
    int sisaHari = 0;
    if (tglTargetStr != null) {
      List<String> d = tglTargetStr.split('/');
      DateTime tglTarget = DateTime(
        int.parse(d[2]),
        int.parse(d[1]),
        int.parse(d[0]),
      );
      sisaHari = tglTarget.difference(DateTime.now()).inDays;
    }

    // Tampilkan dalam Bottom Sheet yang cantik
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Status Kesehatan Kendaraan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),

            // Indikator KM
            _barKesehatan(
              label: 'Berdasarkan Jarak',
              sisa: '$sisaKm KM lagi',
              persen: kmTarget == 0
                  ? 0
                  : (sisaKm / (kmTarget - (kmSekarang - 2000))).clamp(
                      0.0,
                      1.0,
                    ), // Estimasi interval 2k
              warna: sisaKm < 200
                  ? Colors.red
                  : (sisaKm < 500 ? Colors.orange : Colors.green),
            ),

            const SizedBox(height: 20),

            // Indikator Waktu
            _barKesehatan(
              label: 'Berdasarkan Waktu',
              sisa: sisaHari < 0
                  ? 'Sudah lewat ${sisaHari.abs()} hari'
                  : '$sisaHari hari lagi',
              persen: (sisaHari / 180).clamp(
                0.0,
                1.0,
              ), // Estimasi interval 6 bulan (180 hari)
              warna: sisaHari < 7
                  ? Colors.red
                  : (sisaHari < 30 ? Colors.orange : Colors.green),
            ),

            const SizedBox(height: 30),
            Text(
              (sisaKm < 200 || sisaHari < 7)
                  ? '⚠️ Waktunya Servis Sekarang!'
                  : '✅ Kendaraan dalam kondisi baik',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: (sisaKm < 200 || sisaHari < 7)
                    ? Colors.red
                    : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Widget bantuan untuk membuat progress bar
  Widget _barKesehatan({
    required String label,
    required String sisa,
    required double persen,
    required Color warna,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(
              sisa,
              style: TextStyle(color: warna, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: persen,
          backgroundColor: Colors.grey.shade200,
          color: warna,
          minHeight: 10,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }

  void _tampilkanLaporanKeuangan() {
    List riwayat = widget.kendaraan['riwayat'] ?? [];

    if (riwayat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada catatan pengeluaran untuk dianalisis.'),
        ),
      );
      return;
    }

    // --- KALKULASI DATA ---
    int totalBiaya = 0;
    int biayaTertinggi = 0;
    String pekerjaanTermahal = '-';

    for (var item in riwayat) {
      int biaya = int.tryParse(item['biaya'].toString()) ?? 0;
      totalBiaya += biaya;

      if (biaya > biayaTertinggi) {
        biayaTertinggi = biaya;
        pekerjaanTermahal = item['pekerjaan'] ?? 'Servis';
      }
    }

    int rataRata =
        totalBiaya ~/ riwayat.length; // Pembagian bulat (buang desimal)

    // Fungsi kecil untuk format Rupiah (biar rapi)
    String formatRp(int angka) {
      return 'Rp ${angka.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    }

    // --- TAMPILAN BOTTOM SHEET ---
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Analisis Keuangan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 25),

            // 1. Kartu Total Pengeluaran
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Investasi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    formatRp(totalBiaya),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // 2. Kartu Rata-rata & Termahal
            Row(
              children: [
                Expanded(
                  child: _kartuInfoKeuangan(
                    'Rata-rata / Servis',
                    formatRp(rataRata),
                    Icons.analytics,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _kartuInfoKeuangan(
                    'Termahal\n($pekerjaanTermahal)',
                    formatRp(biayaTertinggi),
                    Icons.warning_amber_rounded,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Widget bantuan untuk membuat kartu kecil agar kode lebih rapi
  Widget _kartuInfoKeuangan(
    String label,
    String nilai,
    IconData ikon,
    Color warna,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: warna, size: 24),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            nilai,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: warna,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// HALAMAN BARU: LACI DOKUMEN (GALERI MINI)
// ======================================================================
class HalamanDokumen extends StatefulWidget {
  final Map<String, dynamic> kendaraan;
  const HalamanDokumen({super.key, required this.kendaraan});

  @override
  State<HalamanDokumen> createState() => _HalamanDokumenState();
}

class _HalamanDokumenState extends State<HalamanDokumen> {
  final ImagePicker _alatKamera = ImagePicker(); // Memanggil asisten kamera

  Future<void> _ambilFoto(ImageSource sumber) async {
    // Meminta asisten kamera untuk mengambil gambar
    final XFile? foto = await _alatKamera.pickImage(source: sumber);

    if (foto != null) {
      setState(() {
        // Jika kamar dokumen belum ada, kita buatkan dulu
        if (widget.kendaraan['dokumen'] == null) {
          widget.kendaraan['dokumen'] = [];
        }
        // Masukkan alamat (path) foto tersebut ke dalam kamar dokumen
        widget.kendaraan['dokumen'].add(foto.path);
      });

      // Simpan alamat fotonya ke dalam brankas permanen
      final brankas = await SharedPreferences.getInstance();
      final String? dataMentah = brankas.getString('data_garasi_v2');
      if (dataMentah != null) {
        List<Map<String, dynamic>> daftarSemua =
            List<Map<String, dynamic>>.from(jsonDecode(dataMentah));
        int indexKita = daftarSemua.indexWhere(
          (k) => k['nama'] == widget.kendaraan['nama'],
        );
        if (indexKita != -1) {
          daftarSemua[indexKita] = widget.kendaraan;
          await brankas.setString('data_garasi_v2', jsonEncode(daftarSemua));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List dokumen = widget.kendaraan['dokumen'] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laci Dokumen'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: dokumen.isEmpty
          ? const Center(
              child: Text(
                'Belum ada foto dokumen.\nTekan tombol kamera untuk menambah!',
                textAlign: TextAlign.center,
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              // Mengatur agar fotonya berjejer rapi 2-2 seperti galeri
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: dokumen.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  // Jika ditekan lama, munculkan konfirmasi hapus
                  onLongPress: () => _konfirmasiHapusFoto(index),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(
                          File(dokumen[index]),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      // Tambahkan ikon tempat sampah kecil di pojok agar pengguna tahu bisa dihapus
                      Positioned(
                        right: 5,
                        top: 5,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black45,
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

      // Tombol untuk memunculkan pilihan: Kamera atau Galeri?
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Jepret dari Kamera'),
                  onTap: () {
                    Navigator.pop(context);
                    _ambilFoto(
                      ImageSource.camera,
                    ); // Panggil fungsi dengan sumber Kamera
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Pilih dari Galeri'),
                  onTap: () {
                    Navigator.pop(context);
                    _ambilFoto(
                      ImageSource.gallery,
                    ); // Panggil fungsi dengan sumber Galeri
                  },
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  // --- FUNGSI: KONFIRMASI HAPUS FOTO ---
  void _konfirmasiHapusFoto(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Foto?'),
        content: const Text(
          'Foto kwitansi/dokumen ini akan dibuang dari laci.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                // 1. Hapus dari daftar di layar
                widget.kendaraan['dokumen'].removeAt(index);
              });

              // 2. Simpan perubahan ke BrankasPermanen
              final brankas = await SharedPreferences.getInstance();
              final String? dataMentah = brankas.getString('data_garasi_v2');
              if (dataMentah != null) {
                List<Map<String, dynamic>> daftarSemua =
                    List<Map<String, dynamic>>.from(jsonDecode(dataMentah));
                int indexKita = daftarSemua.indexWhere(
                  (k) => k['nama'] == widget.kendaraan['nama'],
                );
                if (indexKita != -1) {
                  daftarSemua[indexKita] = widget.kendaraan;
                  await brankas.setString(
                    'data_garasi_v2',
                    jsonEncode(daftarSemua),
                  );
                }
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// KELAS BARU: HALAMAN LOGIN & REGISTER
// ==========================================
class HalamanLogin extends StatefulWidget {
  const HalamanLogin({super.key});

  @override
  State<HalamanLogin> createState() => _HalamanLoginState();
}

class _HalamanLoginState extends State<HalamanLogin> {
  bool modeLogin = true; // True = Mode Masuk, False = Mode Daftar
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passCtl = TextEditingController();
  bool prosesLoading = false;
  bool sembunyikanPassword = true; // --- VARIABEL BARU ---

  Future<void> _eksekusiAuth() async {
    setState(() => prosesLoading = true);
    try {
      if (modeLogin) {
        // Proses Masuk (Login)
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailCtl.text.trim(),
          password: passCtl.text.trim(),
        );
      } else {
        // Proses Daftar (Register)
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailCtl.text.trim(),
          password: passCtl.text.trim(),
        );
      }
      // Jika sukses, kita tidak perlu pindah halaman manual.
      // StreamBuilder di langkah selanjutnya akan otomatis mendeteksinya!
    } on FirebaseAuthException catch (e) {
      String pesanError = 'Terjadi kesalahan.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        pesanError = 'Email atau Password salah.';
      } else if (e.code == 'email-already-in-use') {
        pesanError = 'Email sudah terdaftar. Silakan Login.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pesanError), backgroundColor: Colors.red),
      );
    }
    if (mounted) {
      setState(() => prosesLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.garage, size: 60, color: Colors.teal),
                  const SizedBox(height: 10),
                  Text(
                    modeLogin ? 'Masuk Garasi' : 'Daftar Garasi Baru',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailCtl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  // --- KODE DIPERBARUI: TEXTFIELD PASSWORD ---
                  TextField(
                    controller: passCtl,
                    obscureText:
                        sembunyikanPassword, // <-- Gunakan variabel sakelar
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      // --- KODE BARU: TOMBOL MATA ---
                      suffixIcon: IconButton(
                        icon: Icon(
                          sembunyikanPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.teal,
                        ),
                        onPressed: () {
                          setState(() {
                            sembunyikanPassword =
                                !sembunyikanPassword; // Balikkan statusnya!
                          });
                        },
                      ),
                      // ------------------------------
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: prosesLoading ? null : _eksekusiAuth,
                      child: prosesLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              modeLogin ? 'MASUK' : 'DAFTAR',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => modeLogin = !modeLogin),
                    child: Text(
                      modeLogin
                          ? 'Belum punya akun? Daftar di sini'
                          : 'Sudah punya akun? Masuk di sini',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
