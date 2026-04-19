# 🚗 Garasi Pintar

Aplikasi "Asisten Pribadi" berbasis mobile untuk manajemen kendaraan, pengingat servis cerdas, dan analisis finansial perawatan kendaraan. Dibangun menggunakan **Flutter** dan **Firebase**.

## ✨ Fitur Utama

- **Manajemen Multi-Kendaraan:** Simpan data mobil dan motor dalam satu garasi digital.
- **Smart Service Predictor 🔧:** - Kalkulasi status kesehatan komponen secara dinamis.
  - Perbandingan sisa umur komponen berdasarkan Jarak (KM) vs Waktu (Tanggal).
  - Indikator warna kesehatan (Hijau/Kuning/Merah).
- **Pengingat Pajak Cerdas 🔔:** - *Push Notification* otomatis ke sistem HP.
  - Pengaturan *custom reminder* (H-30, H-14, H-7, atau Hari H) sesuai preferensi pengguna.
- **Laporan Keuangan (Financial Dashboard) 💰:**
  - Visualisasi *Pie Chart* untuk riwayat pengeluaran.
  - Kalkulasi total investasi perawatan, rata-rata biaya per servis, dan rekam jejak servis termahal.

## 🛠️ Teknologi yang Digunakan

- **Framework:** [Flutter](https://flutter.dev/)
- **Database/Backend:** Firebase Cloud Firestore & Firebase Auth
- **Local Notifications:** `flutter_local_notifications`
- **Charting:** `fl_chart`
- **State Management:** `setState` (Native)

## 🚀 Cara Menjalankan Project (Local Development)

1. Clone repository ini:
   ```bash
   git clone [https://github.com/FajarHadi1/garasi-pintar.git](https://github.com/FajarHadi1/garasi-pintar.git)
   ```

2. Dapatkan *dependencies*:
   ```bash
   flutter pub get
   ```

3. **Penting:** Project ini menggunakan Firebase. Anda harus membuat project di [Firebase Console](https://console.firebase.google.com/), lalu unduh file `google-services.json` dan letakkan di `android/app/`.

4. Jalankan aplikasi:
   ```bash
   flutter run
   ```

---
*Didesain dan dikembangkan oleh Farras Fajar Hadi*