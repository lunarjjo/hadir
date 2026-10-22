/// Pembangun CSV (RFC 4180) untuk ekspor rekap absensi.
library;

const String kBom = '\uFEFF';

/// Escape satu field CSV.
String csvEscape(String field) {
  final needsQuote =
      field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r');
  if (!needsQuote) return field;
  final escaped = field.replaceAll('"', '""');
  return '"$escaped"';
}

/// Bangun dokumen CSV: BOM + header + baris-baris.
String buildCsv(List<String> headers, List<List<String>> rows) {
  final sb = StringBuffer(kBom);
  sb.writeln(headers.map(csvEscape).join(','));
  for (final row in rows) {
    sb.writeln(row.map(csvEscape).join(','));
  }
  return sb.toString();
}
