/// Kode galat aplikasi + pesan berbahasa Indonesia + tipe `Result`.
library;

/// Kode galat yang dipakai lintas service dan UI.
enum AppErrCode {
  invalidCredentials,
  inactive,
  locked,

  // Token QR
  needToken,
  badToken,
  tokenExpired,
  tokenNotYetValid,
  tokenOfficeMismatch,

  // Absensi
  outsideRadius,
  alreadyCheckedIn,
  alreadyCheckedOut,
  noOpenRecord,

  // Data
  usernameTaken,
  officeNameTaken,
  hasAttendance,
  lastAdmin,
  selfTarget,
  notFound,

  // Lokasi
  gpsPermissionDenied,
  gpsPermissionPermanent,
  gpsServiceOff,
  gpsTimeout,
  gpsUnavailable,

  // Lain-lain
  validation,
  storage,
  generic,
}

/// Exception aplikasi dengan kode galat + parameter konteks.
class AppException implements Exception {
  final AppErrCode code;
  final Map<String, Object?> params;

  const AppException(this.code, {this.params = const {}});

  /// Pesan siap-tampil dalam bahasa Indonesia.
  String get message {
    final menit = params['menit'];
    final jarak = params['jarak'];
    final radius = params['radius'];
    final nama = params['nama'];
    return switch (code) {
      AppErrCode.invalidCredentials => 'Username atau kata sandi salah.',
      AppErrCode.inactive => 'Akun ini sedang tidak aktif. Hubungi admin.',
      AppErrCode.locked =>
        'Akun terkunci sementara. Coba lagi dalam $menit menit.',
      AppErrCode.needToken =>
        'Sekarang wajib memindai QR dari admin untuk absen.',
      AppErrCode.badToken =>
        'QR tidak valid. Pastikan kamu memindai QR dari layar admin.',
      AppErrCode.tokenExpired =>
        'QR sudah kedaluwarsa. Minta admin menampilkan QR terbaru.',
      AppErrCode.tokenNotYetValid => 'QR belum berlaku (jam perangkat berbeda?).',
      AppErrCode.tokenOfficeMismatch =>
        'QR ini untuk kantor lain. Gunakan QR kantor tempat kamu berada.',
      AppErrCode.outsideRadius =>
        'Kamu berada $jarak dari $nama — di luar radius absen ($radius).',
      AppErrCode.alreadyCheckedIn => 'Kamu sudah absen masuk hari ini.',
      AppErrCode.alreadyCheckedOut => 'Kamu sudah absen pulang hari ini.',
      AppErrCode.noOpenRecord =>
        'Belum ada absen masuk yang masih terbuka (dalam 20 jam terakhir).',
      AppErrCode.usernameTaken => 'Username sudah dipakai orang lain.',
      AppErrCode.officeNameTaken => 'Nama kantor sudah dipakai.',
      AppErrCode.hasAttendance =>
        'Tidak bisa dihapus: masih punya riwayat absensi. Nonaktifkan saja.',
      AppErrCode.lastAdmin =>
        'Tindakan ini menghapus admin terakhir yang aktif — tidak diizinkan.',
      AppErrCode.selfTarget =>
        'Tindakan ini tidak bisa diterapkan ke akun kamu sendiri.',
      AppErrCode.notFound => 'Data tidak ditemukan.',
      AppErrCode.gpsPermissionDenied =>
        'Izin lokasi ditolak. Izinkan lokasi untuk absen.',
      AppErrCode.gpsPermissionPermanent =>
        'Izin lokasi ditolak permanen. Buka Pengaturan → Izin → Lokasi.',
      AppErrCode.gpsServiceOff =>
        'GPS perangkat sedang mati. Nyalakan lokasi lalu coba lagi.',
      AppErrCode.gpsTimeout =>
        'Tidak mendapat posisi GPS tepat waktu. Coba lagi di area terbuka.',
      AppErrCode.gpsUnavailable => 'Posisi GPS tidak tersedia saat ini.',
      AppErrCode.validation => 'Periksa kembali isian formulir.',
      AppErrCode.storage => 'Gagal menyimpan berkas. Coba lagi.',
      AppErrCode.generic => 'Terjadi kesalahan. Coba lagi.',
    };
  }

  @override
  String toString() => 'AppException($code): $message';
}

/// Hasil operasi: sukses dengan nilai atau gagal dengan [AppException].
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final AppException error;
  const Err(this.error);
}

/// Pabrik singkat: hasil sukses.
Result<T> ok<T>(T value) => Ok<T>(value);

/// Pabrik singkat: hasil gagal.
Result<T> err<T>(AppErrCode code, {Map<String, Object?> params = const {}}) =>
    Err<T>(AppException(code, params: params));
