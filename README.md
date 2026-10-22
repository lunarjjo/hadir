# Hadir 📱

**Aplikasi absensi Android native (Flutter) — admin & anggota dalam satu APK.**

[![CI](https://github.com/lunarjjo/hadir/actions/workflows/ci.yml/badge.svg)](https://github.com/lunarjjo/hadir/actions/workflows/ci.yml)
[![Rilis](https://img.shields.io/badge/rilis-v1.0.0-blue)](https://github.com/lunarjjo/hadir/releases)
[![Lisensi](https://img.shields.io/badge/lisensi-MIT-green)](LICENSE)
[![Android](https://img.shields.io/badge/Android-5.0%2B%20(API%2021)-3ddc84?logo=android&logoColor=white)](https://developer.android.com/about/versions/lollipop)

> Penerus native dari [mooncheck](https://github.com/lunarjjo/mooncheck) (v0.1.0,
> berbasis web-WebView) — dibangun ulang penuh dengan **Flutter/Dart** sesuai
> arahan: *profesional, framework Android, bukan pembungkus web*.

## Fitur

### Bersama
- **Login** dengan kunci akun: PBKDF2-HMAC-SHA256 (12.000 iterasi, salt acak
  per pengguna), **lockout otomatis** (5 kegagalan → terkunci 15 menit),
  sesi berkedaluwarsa (12 jam / 30 hari "ingat saya"), perbandingan konstan-waktu.
- **Tema ikut perangkat**: terang/gelap otomatis (DayNight + Material 3),
  bisa dioverride manual di profil.
- Satu aplikasi, dua peran: admin dan anggota masuk dari layar yang sama.

### Anggota
- **Absen masuk/pulang** satu tombol: aplikasi mengambil GPS → memverifikasi
  **geofence** (jarak haversine ke kantor, radius dapat diatur) → memindai
  **QR token admin** (bila diwajibkan) → rekaman tersimpan dengan status
  otomatis: *tepat waktu / terlambat / pulang awal / lembur*.
- **Riwayat** per bulan dengan filter status + ringkasan bulanan.
- **QR identitas pribadi** untuk absen manual oleh admin.
- Profil: ganti nama tampilan & kata sandi (verifikasi sandi lama).

### Admin
- **Dashboard**: hadir/terlambat/belum pulang/tidak hadir hari ini +
  grafik batang 7 hari (CustomPainter sendiri).
- **QR Absen**: token ber-HMAC dengan tiga mode — **rotasi 60 detik**
  (sinkron lintas perangkat), sesi 5 menit, seharian; lengkap dengan hitung
  mundur. Verifikasi: tanda tangan + jendela waktu (toleransi 30 detik) +
  kecocokan kantor.
- **Pindai QR anggota** → konfirmasi → absen manual.
- **Kelola anggota**: tambah/edit peran/reset sandi/nonaktifkan/hapus
  (penjaga: admin terakhir & diri sendiri tidak bisa diturunkan).
- **Kelola kantor**: CRUD + ambil koordinat langsung dari GPS.
- **Rekap absensi**: filter rentang waktu/anggota/kantor/status, detail
  lengkap per rekaman (jarak, validitas token, durasi), sunting catatan,
  **ekspor CSV** (RFC 4180 + BOM, siap Excel).
- **Absen manual** dengan jam kustom (mendukung koreksi & shift malam).
- **Pengaturan kebijakan**: jam kerja, tenggang telat/pulang awal, ambang
  lembur, wajib/tidak QR, verifikasi GPS saat pulang.

## Keamanan

| Aspek | Mekanisme |
|---|---|
| Sandi | PBKDF2-HMAC-SHA256, 12.000 iterasi, salt 16-byte acak per user |
| Brute force | Lockout 15 menit setelah 5 kegagalan + mitigasi timing |
| Token QR | HMAC-SHA256 terpotong 128-bit, rahasia acak 256-bit per basis data |
| Sesi | Token acak 256-bit + kedaluwarsa; disimpan hanya di basis data lokal |
| Basis data | SQLite lokal (tanpa server), parameterized query penuh |
| APK | Ditandatangani kunci PKCS#12 milik repo (self-signed) |

> ⚠️ **Catatan kunci penandatanganan**: untuk kemudahan rilis otomatis,
> kunci self-signed disimpan di dalam repo (`android/app/hadir-release.jks`
> + `android/app/key.properties`). Ini layak untuk pemakaian pribadi/uji.
> Untuk distribusi publik, buat kunci baru dengan `keytool` dan rahasiakan.

## Kompatibilitas

- **Android 5.0 (API 21) ke atas** — mencakup ±99% perangkat aktif.
- APK universal: `armeabi-v7a`, `arm64-v8a`, `x86_64`.
- **Tanpa Google Play Services**: pemindai QR memakai ML Kit model *bundled*,
  lokasi memakai `LocationManager` framework — bekerja di perangkat mana pun.

## Mencoba

1. Unduh `app-release.apk` dari [Rilis](https://github.com/lunarjjo/hadir/releases).
2. Pasang (izinkan "sumber tidak dikenal").
3. Login awal: **admin / admin123** → segera ganti sandi di Profil.
4. Tambah anggota, atur kantor (tekan "Gunakan lokasi saat ini" saat berada
   di tempat kerja), lalu tampilkan **QR Absen** untuk anggota.

## Arsitektur

```
lib/
├── core/          # Logika murni (100% teruji unit): PBKDF2/HMAC, haversine,
│                  # token QR, aturan status absensi, sesi, CSV, validasi,
│                  # format tanggal Indonesia
├── data/          # SQLite: db.dart (skema+PRAGMA FK), 4 DAO, seed, 4 model
├── services/      # Auth (lockout/sesi), Absensi (geofence+token), Admin,
│                  # Lokasi (geolocator), Ekspor CSV
├── state/         # Provider (ChangeNotifier) ×4 + AppBootstrap (composition root)
└── ui/            # 15 layar Material 3 + widget bersama (badge, grafik, dll.)
```

**Skema basis data**: `users` (hash sandi, lockout), `offices` (koordinat +
radius), `attendance` (satu baris per pengguna per hari — kendala unik;
jarak & validitas GPS/token tercatat), `settings` (kebijakan + rahasia QR).
Semua tabel ber-`CHECK`/`UNIQUE`/FK dan diaktifkan `PRAGMA foreign_keys`.

**Protokol token QR**: `HADIR|T|<officeId>|<issuedUnix>|<window>|<sig128bit-hex>`
untuk absen dan `HADIR|U|<userId>|<username>|<sig>` untuk identitas anggota.
`issuedUnix` diratakan ke kelipatan jendela agar token identik di semua
perangkat admin dalam satu jendela waktu.

## Pengembangan

```bash
flutter pub get
flutter analyze      # 0 issue
flutter test         # 100+ test (unit, integrasi SQLite-FFI, widget)
flutter build apk --release
```

- Versi Flutter terkunci: **3.24.5** (lihat CI). Dependensi versi pin eksak.
- Ikon launcher dapat diregenerasi: `python3 tools/gen_icons.py`.
- CI: analisis statis → seluruh test (SQLite via FFI) → build APK rilis +
  debug → verifikasi `aapt dump badging` → unggah artefak → rilis otomatis
  saat tag `v*`.

## Testing

Rencana & hasil pengujian terdokumentasi di
[DEBUG_REPORT.md](DEBUG_REPORT.md) — termasuk daftar bug yang ditemukan dan
diperbaiki selama pengembangan.

## Lisensi

MIT © 2026 lunarjjo — lihat [LICENSE](LICENSE).
