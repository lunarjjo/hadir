/// Validasi isian formulir — semua mengembalikan null bila valid,
/// atau pesan galat bahasa Indonesia.
library;

final RegExp _usernameRe = RegExp(r'^[a-z0-9._-]{3,24}$');

/// Normalisasi username: trim + huruf kecil.
String normalizeUsername(String raw) => raw.trim().toLowerCase();

String? validateUsername(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Username wajib diisi.';
  if (!_usernameRe.hasMatch(v)) {
    return '3–24 karakter: huruf kecil, angka, titik, garis bawah, strip.';
  }
  return null;
}

String? validatePassword(String? value) {
  final v = value ?? '';
  if (v.isEmpty) return 'Kata sandi wajib diisi.';
  if (v.length < 6) return 'Kata sandi minimal 6 karakter.';
  if (v.length > 72) return 'Kata sandi maksimal 72 karakter.';
  return null;
}

String? validateDisplayName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Nama tampilan wajib diisi.';
  if (v.length < 2) return 'Nama terlalu pendek (minimal 2 karakter).';
  if (v.length > 48) return 'Nama terlalu panjang (maksimal 48 karakter).';
  return null;
}

double? tryParseDouble(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

String? validateLatitude(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Latitude wajib diisi.';
  final lat = tryParseDouble(v);
  if (lat == null) return 'Latitude harus berupa angka.';
  if (lat < -90 || lat > 90) return 'Latitude harus di rentang -90 s.d. 90.';
  return null;
}

String? validateLongitude(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Longitude wajib diisi.';
  final lng = tryParseDouble(v);
  if (lng == null) return 'Longitude harus berupa angka.';
  if (lng < -180 || lng > 180) {
    return 'Longitude harus di rentang -180 s.d. 180.';
  }
  return null;
}

String? validateRadiusMeters(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Radius wajib diisi.';
  final r = int.tryParse(v);
  if (r == null) return 'Radius harus bilangan bulat (meter).';
  if (r < 10 || r > 5000) return 'Radius 10–5000 meter.';
  return null;
}

String? validateOfficeName(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Nama kantor wajib diisi.';
  if (v.length < 2) return 'Nama kantor terlalu pendek.';
  if (v.length > 64) return 'Nama kantor maksimal 64 karakter.';
  return null;
}
