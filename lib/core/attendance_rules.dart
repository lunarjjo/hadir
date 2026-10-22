/// Aturan bisnis absensi: status masuk/pulang, lembur, kunci hari.
library;

/// Status absen masuk.
enum CheckInStatus { tepat, terlambat }

/// Status absen pulang.
enum CheckOutStatus { tepat, pulangAwal, lembur }

/// Kebijakan jam kerja.
class WorkPolicy {
  /// Menit sejak tengah malam, mis. 480 = 08:00.
  final int workStartMinutes;

  /// Menit sejak tengah malam, mis. 1020 = 17:00.
  final int workEndMinutes;

  /// Tenggang keterlambatan (menit) setelah jam mulai.
  final int lateGraceMinutes;

  /// Tenggang pulang awal (menit) sebelum jam pulang.
  final int earlyLeaveGraceMinutes;

  /// Tambahan menit di atas hari penuh sebelum disebut lembur.
  final int overtimeExtraMinutes;

  const WorkPolicy({
    this.workStartMinutes = 480,
    this.workEndMinutes = 1020,
    this.lateGraceMinutes = 15,
    this.earlyLeaveGraceMinutes = 15,
    this.overtimeExtraMinutes = 30,
  });

  int get fullDayMinutes => workEndMinutes - workStartMinutes;
}

int _secondsOfDay(DateTime t) => t.hour * 3600 + t.minute * 60 + t.second;

bool _sameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Status absen masuk pada jam [at] dengan kebijakan [policy].
CheckInStatus evaluateCheckIn(DateTime at, WorkPolicy policy) {
  final batasTerlambat =
      (policy.workStartMinutes + policy.lateGraceMinutes) * 60;
  return _secondsOfDay(at) > batasTerlambat
      ? CheckInStatus.terlambat
      : CheckInStatus.tepat;
}

/// Status absen pulang. Mendukung shift lintas tengah malam: bila pulang
/// terjadi di hari yang berbeda dengan masuk, status ditentukan dari durasi
/// kerja (bukan dari jam dinding).
CheckOutStatus evaluateCheckOut(
  DateTime checkIn,
  DateTime checkOut,
  WorkPolicy policy,
) {
  final workedMinutes = checkOut.difference(checkIn).inMinutes;
  final ambangPulangAwal =
      (policy.workEndMinutes - policy.earlyLeaveGraceMinutes) * 60;
  final ambangLembur = policy.fullDayMinutes + policy.overtimeExtraMinutes;

  if (workedMinutes < 0) return CheckOutStatus.pulangAwal;

  if (!_sameLocalDay(checkIn, checkOut)) {
    if (workedMinutes >= ambangLembur) return CheckOutStatus.lembur;
    if (workedMinutes < policy.fullDayMinutes - policy.earlyLeaveGraceMinutes) {
      return CheckOutStatus.pulangAwal;
    }
    return CheckOutStatus.tepat;
  }

  if (_secondsOfDay(checkOut) < ambangPulangAwal) {
    return CheckOutStatus.pulangAwal;
  }
  if (workedMinutes >= ambangLembur) return CheckOutStatus.lembur;
  return CheckOutStatus.tepat;
}

/// Status gabungan sebuah hari (string yang disimpan ke basis data).
///
/// Prioritas: terlambat > pulang_awal > lembur > hadir.
String overallStatus(CheckInStatus? checkIn, CheckOutStatus? checkOut) {
  if (checkIn == CheckInStatus.terlambat) return 'terlambat';
  if (checkOut == CheckOutStatus.pulangAwal) return 'pulang_awal';
  if (checkOut == CheckOutStatus.lembur) return 'lembur';
  return 'hadir';
}

/// Kunci hari lokal `YYYY-MM-DD` (nol-diisi).
String dayKey(DateTime local) {
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parse kunci hari `YYYY-MM-DD` menjadi DateTime lokal tengah malam;
/// null bila format salah.
DateTime? parseDayKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(y, m, d);
}
