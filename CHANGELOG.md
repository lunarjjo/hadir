# Changelog

Semua perubahan penting proyek ini didokumentasikan di sini.
Format mengikuti [Keep a Changelog](https://keepachangelog.com/id-ID/1.1.0/)
dan versi mengikuti [Semantic Versioning](https://semver.org).

## [1.0.0] — 2026-10-23

### Ditambahkan

- Aplikasi absensi Android native Flutter — **admin & member dalam satu APK**.
- **Autentikasi**: login username/sandi (PBKDF2-HMAC-SHA256, 12.000 iterasi,
  salt acak per pengguna), lockout 5 percobaan gagal (15 menit), sesi dengan
  kedaluwarsa (12 jam / 30 hari "ingat saya"), verifikasi konstan-waktu.
- **Absensi**: check-in/check-out dengan status otomatis — tepat waktu,
  terlambat (dengan masa tenggang), pulang awal, lembur; dukungan shift
  lintas tengah malam; satu rekaman per pengguna per hari (kendala unik).
- **QR**: token absen ber-HMAC-SHA256 (rotasi 60 detik / sesi 5 menit /
  seharian) yang ditampilkan admin dan dipindai anggota lewat kamera
  (ML Kit berjalan tanpa Play Services); QR identitas anggota untuk absen
  manual oleh admin; verifikasi tanda tangan + jendela waktu + kecocokan
  kantor, toleransi selisih jam 30 detik.
- **Location check**: geofence haversine terhadap kantor (radius dapat
  diatur), jarak ditampilkan pada rekaman; izin GPS ditangani penuh
  termasuk "ditolak permanen" (tautan ke pengaturan).
- **Admin**: dashboard statistik + grafik 7 hari, kelola anggota (CRUD,
  reset sandi, nonaktifkan, penjaga admin terakhir & diri sendiri),
  kelola kantor (CRUD + ambil koordinat dari GPS), rekap dengan filter
  (rentang tanggal/anggota/kantor/status), absen manual, ekspor CSV,
  pengaturan jam kerja & kebijakan QR.
- **Member**: beranda status hari ini, pindai QR, riwayat dengan filter,
  profil (ganti nama/sandi), QR identitas pribadi.
- **UI**: Material 3 lengkap, **tema mengikuti preferensi perangkat**
  (terang/gelap otomatis + override manual), seluruh layar dengan state
  kosong / memuat / galat.
- **Kompatibilitas**: minSdk 21 (Android 5.0+), tanpa Play Services,
  APK universal armeabi-v7a / arm64-v8a / x86_64.
- **Keamanan APK**: rilis ditandatangani kunci PKCS#12 milik repo
  (self-signed, lihat README).
- **Testing**: 100+ unit test & integrasi (SQLite via FFI) + widget test
  alur login; CI GitHub Actions: analyze → test → build APK → rilis otomatis
  saat tag `v*`.

### Catatan

- `hadir` adalah penerus native dari [mooncheck](https://github.com/lunarjjo/mooncheck)
  (v0.1.0, berbasis web dalam WebView) sesuai arahan pemilik: aplikasi harus
  dibangun dengan framework Android asli, bukan pembungkus web.
