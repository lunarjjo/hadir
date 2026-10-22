/// Ekspor rekap absensi ke CSV (RFC 4180 + BOM agar Excel membaca UTF-8).
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:hadir/core/attendance_rules.dart';
import 'package:hadir/core/csv.dart';
import 'package:hadir/core/datetime_format.dart';
import 'package:hadir/core/geo.dart';
import 'package:hadir/core/result.dart';
import 'package:hadir/data/dao/office_dao.dart';
import 'package:hadir/data/dao/user_dao.dart';
import 'package:hadir/data/models/attendance.dart';
import 'package:hadir/data/models/office.dart';
import 'package:hadir/data/models/user.dart';

class ExportService {
  final UserDao _users;
  final OfficeDao _offices;

  ExportService(Database db)
      : _users = UserDao(db),
        _offices = OfficeDao(db);

  static const List<String> headers = [
    'Tanggal',
    'Nama',
    'Username',
    'Peran',
    'Kantor',
    'Masuk',
    'Status Masuk',
    'Jarak Masuk',
    'Pulang',
    'Status Pulang',
    'Jarak Pulang',
    'Durasi (menit)',
    'Metode',
    'Catatan',
  ];

  String _statusIn(int index) => index == 0 ? 'Tepat' : 'Terlambat';

  String _statusOut(CheckOutStatus? s) => switch (s) {
        null => '',
        CheckOutStatus.tepat => 'Tepat',
        CheckOutStatus.pulangAwal => 'Pulang Awal',
        CheckOutStatus.lembur => 'Lembur',
      };

  String _overall(String s) => switch (s) {
        'hadir' => 'Hadir',
        'terlambat' => 'Terlambat',
        'pulang_awal' => 'Pulang Awal',
        'lembur' => 'Lembur',
        _ => s,
      };

  /// Bangun isi CSV lengkap untuk [records] (nama & kantor di-join).
  Future<String> buildCsvFor(List<Attendance> records) async {
    final users = <String, User>{};
    for (final u in await _users.listAll()) {
      users[u.id] = u;
    }
    final offices = <String, Office>{};
    for (final o in await _offices.list()) {
      offices[o.id] = o;
    }
    final rows = [
      for (final r in records)
        [
          r.day,
          users[r.userId]?.displayName ?? r.userId,
          users[r.userId]?.username ?? '',
          users[r.userId]?.isAdmin == true ? 'Admin' : 'Anggota',
          offices[r.officeId]?.name ?? r.officeId,
          formatJam(DateTime.fromMillisecondsSinceEpoch(r.checkInAtMs)),
          _statusIn(r.statusIn.index),
          formatDistance(r.checkInDistance),
          r.checkOutAtMs == null
              ? ''
              : formatJam(
                  DateTime.fromMillisecondsSinceEpoch(r.checkOutAtMs!),
                ),
          _statusOut(r.statusOut),
          r.checkOutDistance == null
              ? ''
              : formatDistance(r.checkOutDistance!),
          r.workedMinutes?.toString() ?? '',
          r.isManual ? 'Manual' : 'QR',
          r.note ?? '',
        ],
    ];
    return buildCsv(headers, rows);
  }

  /// Simpan CSV ke folder dokumen aplikasi; mengembalikan jalur lengkap.
  Future<Result<String>> saveCsv(
    List<Attendance> records,
    String fileName,
  ) async {
    try {
      final content = await buildCsvFor(records);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(content, flush: true);
      return ok(file.path);
    } catch (_) {
      return err(AppErrCode.storage);
    }
  }

  // Dipakai dashboard: label overall untuk tampilan UI (di-share ke UI).
  String overallLabel(String s) => _overall(s);
}
