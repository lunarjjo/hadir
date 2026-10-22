/// Format tanggal/jam/durasi dalam bahasa Indonesia — tanpa intl,
/// deterministik dan mudah diuji.
library;

const List<String> kHari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

const List<String> kBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

const List<String> kBulanSingkat = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

String _pad2(int n) => n.toString().padLeft(2, '0');

/// `Kamis, 17 Oktober 2024`
String formatTanggal(DateTime d) =>
    '${kHari[d.weekday - 1]}, ${d.day} ${kBulan[d.month - 1]} ${d.year}';

/// `17 Okt 2024`
String formatTanggalSingkat(DateTime d) =>
    '${d.day} ${kBulanSingkat[d.month - 1]} ${d.year}';

/// `Oktober 2024`
String formatBulanTahun(DateTime d) => '${kBulan[d.month - 1]} ${d.year}';

/// `08:04`
String formatJam(DateTime d) => '${_pad2(d.hour)}:${_pad2(d.minute)}';

/// `08:04:07`
String formatJamDetik(DateTime d) =>
    '${_pad2(d.hour)}:${_pad2(d.minute)}:${_pad2(d.second)}';

/// `17 Okt 2024 08:04`
String formatTanggalJam(DateTime d) =>
    '${formatTanggalSingkat(d)} ${formatJam(d)}';

/// Durasi dari menit: `45 m`, `8 j 12 m`, `—` untuk negatif/null.
String formatDurasi(int? minutes) {
  if (minutes == null || minutes < 0) return '—';
  if (minutes < 60) return '$minutes m';
  final jam = minutes ~/ 60;
  final sisa = minutes % 60;
  if (jam >= 24) {
    final hari = jam ~/ 24;
    final sisaJam = jam % 24;
    return '$hari h $sisaJam j $sisa m';
  }
  return sisa == 0 ? '$jam j' : '$jam j $sisa m';
}

/// Waktu relatif singkat: `baru saja`, `5 menit lalu`, `2 jam lalu`,
/// lebih lama dari itu jatuh ke `17 Okt 08:04`.
String formatRelatif(DateTime at, DateTime now) {
  final delta = now.difference(at);
  if (delta.isNegative) return formatTanggalJam(at);
  if (delta.inSeconds < 60) return 'baru saja';
  if (delta.inMinutes < 60) {
    return '${delta.inMinutes} menit lalu';
  }
  if (delta.inHours < 24) return '${delta.inHours} jam lalu';
  return formatTanggalJam(at);
}
