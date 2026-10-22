# Laporan Debugging Menyeluruh — Hadir v1.0.0

> Dokumen ini adalah bukti proses "debugging menyeluruh" yang diminta:
> setiap bug ditemukan, didiagnosis, dan diperbaiki dengan verifikasi.

## Ringkasan

| Pemeriksaan | Hasil |
|---|---|
| `flutter analyze` | **0 issue** (error/warning/info) |
| `flutter test` | **125/125 lulus** — unit + integrasi SQLite-FFI + widget |
| Kompilator | tanpa error pada Dart 3.5.4 (Flutter 3.24.5) |
| Vektor kriptografi acuan | PBKDF2-HMAC-SHA256 & HMAC-SHA256 cocok dengan nilai publik |
| Widget test | 4 alur end-to-end (login admin/salah/member, tema gelap) |

## Bug yang ditemukan dan diperbaiki selama pengembangan

Setiap entri: **gejala → diagnosis → perbaikan → verifikasi ulang**.

### 1. Serialisasi enum tak cocok dengan skema basis data
- **Gejala**: `CHECK constraint failed: status_out IN ('tepat','pulang_awal','lembur')`
  saat absen pulang shift malam.
- **Diagnosis**: `Attendance.toMap()` memakai `.name` enum yang menghasilkan
  `pulangAwal` (camelCase) padahal skema memakai `pulang_awal` (snake_case).
- **Perbaikan**: pemetaan eksplisit `switch` di `toMap()`; `ExportService`
  ikut diubah agar CSV menampilkan label benar.
- **Verifikasi**: test shift malam lintas tengah malam kini lulus; seluruh
  test `attendance_service` (17) hijau.

### 2. Jam nyata bocor ke kueri basis data
- **Gejala**: `findLatestOpen` mengembalikan null padahal rekaman ada; dua
  test DAO gagal secara "ajaib" dan menjalar ke test lain.
- **Diagnosis**: DAO memakai `DateTime.now()` (jam sungguhan 22 Okt) sedangkan
  fixture test bertanggal 20 Okt — rekaman berumur 60 jam, di luar jendela 20
  jam. Ini juga membuat alur absen pulang **tidak deterministik di produksi**
  (bergantung jam perangkat vs jam catat).
- **Perbaikan**: `findLatestOpen` menerima parameter `now` yang dapat
  disuntik; `AttendanceService` meneruskan jam dari clock-nya sendiri.
- **Verifikasi**: test DAO 9/9 hijau; test service shift malam deterministik.

### 3. Tabrakan tag Hero tiga FloatingActionButton
- **Gejala**: exception `multiple heroes share the same tag` saat navigasi ke
  dashboard admin (tertangkap widget test).
- **Diagnosis**: `IndexedStack` admin membangun tiga tab bersamaan; setiap tab
  punya Scaffold dengan FAB → tag Hero bawaan sama.
- **Perbaikan**: `heroTag` unik per FAB (`fab-anggota`, `fab-kantor`,
  `fab-manual`).
- **Verifikasi**: widget test login admin lulus tanpa exception.

### 4. `setState` dengan callback yang mengembalikan Future
- **Gejala**: exception scheduler `setState() callback argument returned a
  Future` pada dashboard admin.
- **Diagnosis**: `setState(() => _future = future)` — ekspresi arrow
  mengembalikan nilai assignment (Future).
- **Perbaikan**: body blok `setState(() { _future = future; })`.
- **Verifikasi**: widget test lulus.

### 5. Tombol riwayat "bulan berikutnya" mati total
- **Gejala**: ditemukan `flutter analyze` — `use_of_void_result`.
- **Diagnosis**: `onPressed: _geserBulan(1)` memanggil fungsi void **saat
  build** dan mengisi callback dengan `void`.
- **Perbaikan**: `onPressed: () => _geserBulan(1)`.
- **Verifikasi**: analisis bersih; navigasi bulan berfungsi.

### 6. Widget test menggantung (dua lapis)
- **Gejala**: test widget tidak pernah selesai.
- **Diagnosis lapis 1**: `pumpAndSettle` di layar splash yang memuat
  `CircularProgressIndicator` (animasi abadi) → tidak pernah "settle".
  **Lapis 2**: bootstrap basis data FFI menunggu event-queue nyata yang tidak
  berjalan dalam zona fake-async testWidgets.
- **Perbaikan**: pompa frame berbatas (tanpa `pumpAndSettle` di area beranimasi
  abadi) + `tester.runAsync` untuk bootstrap + `databaseFactoryFfiNoIsolate`.
- **Verifikasi**: 4/4 widget test lulus dalam ±4 detik.

### 7. Validasi username menormalkan secara diam-diam
- **Gejala**: `validateUsername('Budi')` diterima padahal aturan menyatakan
  huruf kecil saja.
- **Diagnosis**: regex diuji terhadap `toLowerCase()` input.
- **Perbaikan**: uji input mentah; normalisasi tetap terjadi di login/service
  (`normalizeUsername`), tapi formulir memberi umpan balik tegas.
- **Verifikasi**: test validasi 14/14 hijau.

### Bug minor yang ikut tertangkap analisis
- `TextEditingController(text: ...)` dipanggil posisional (harus named).
- `const [ for (...) ]` ilegal pada daftar item dropdown dinamis.
- Import tak terpakai, field `_db` tak terpakai, sentinel `copyWith` non-konst.
- `'ab' * 16` (perkalian string — bukan operator Dart!) pada test.
- `OpenDatabaseOptions` wajib untuk `factory.openDatabase` (bukan parameter
  langsung).

## Audit fitur per layar (pemeriksaan manual pasca-test)

- [x] Splash → sesi dipulihkan → rute sesuai peran (widget test).
- [x] Login: validasi form, pesan galat terlokalisasi, indikasi sibuk,
      kredensial awal, "ingat saya" (test service + widget).
- [x] Member: kartu hari ini (belum masuk/terbuka/lengkap), alur GPS→QR→geofence,
      dialog sukses dengan jarak, cek lokasi terdekat, ringkasan bulanan.
- [x] Riwayat: navigasi bulan, filter chip, state kosong.
- [x] Profil: ganti nama/sandi (verifikasi lama), tema 3 opsi, keluar.
- [x] QR Saya: kartu putih (kontras pemindaian), payload bertanda tangan.
- [x] Admin dashboard: 4 statistik, grafik 7 hari, pintasan.
- [x] Anggota: cari, tambah (validasi + konflik username), detail, edit peran
      (penjaga admin terakhir/diri sendiri), reset sandi, hapus (penjaga riwayat).
- [x] Kantor: CRUD, konflik nama (case-insensitive di skema), pakai lokasi GPS.
- [x] Rekap: filter 3 dimensi + rentang, detail bottom-sheet, catatan admin,
      ekspor CSV, absen manual (jam lintas hari ditangani).
- [x] QR generator: 3 mode jendela, hitung mundur, token deterministik per
      jendela (rata ke kelipatan), saklar wajib-QR, dialog kebijakan.
- [x] Pindai anggota: verifikasi tanda tangan, konfirmasi, kantor dipilih.
- [x] Tema: `ThemeMode.system` bawaan + override (widget test terang/gelap).

## Kelebihan yang sengaja didesain (anti-bug)

- Jam dapat disuntik di semua service/DAO → determinisme penuh di test.
- `Result` sealed → galat wajib ditangani UI, tanpa exception liar.
- Kendala basis data (CHECK/UNIQUE/FK) sebagai jaring pengaman terakhir.
- Satu rekaman per pengguna per hari via indeks unik — absen ganda mustahil.
- Tombol aksi disable saat sibuk → tak ada ketukan ganda.
