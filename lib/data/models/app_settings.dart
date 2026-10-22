/// Pengaturan aplikasi yang tersimpan di tabel settings.
library;

import 'package:hadir/core/attendance_rules.dart';

class AppSettings {
  final String qrSecretHex;
  final int workStartMinutes;
  final int workEndMinutes;
  final int lateGraceMinutes;
  final int earlyLeaveGraceMinutes;
  final int overtimeExtraMinutes;
  final bool requireQr;
  final int qrWindowSeconds;
  final bool verifyCheckOutGeo;

  const AppSettings({
    required this.qrSecretHex,
    this.workStartMinutes = 480,
    this.workEndMinutes = 1020,
    this.lateGraceMinutes = 15,
    this.earlyLeaveGraceMinutes = 15,
    this.overtimeExtraMinutes = 30,
    this.requireQr = true,
    this.qrWindowSeconds = 300,
    this.verifyCheckOutGeo = true,
  });

  WorkPolicy get policy => WorkPolicy(
        workStartMinutes: workStartMinutes,
        workEndMinutes: workEndMinutes,
        lateGraceMinutes: lateGraceMinutes,
        earlyLeaveGraceMinutes: earlyLeaveGraceMinutes,
        overtimeExtraMinutes: overtimeExtraMinutes,
      );

  AppSettings copyWith({
    String? qrSecretHex,
    int? workStartMinutes,
    int? workEndMinutes,
    int? lateGraceMinutes,
    int? earlyLeaveGraceMinutes,
    int? overtimeExtraMinutes,
    bool? requireQr,
    int? qrWindowSeconds,
    bool? verifyCheckOutGeo,
  }) {
    return AppSettings(
      qrSecretHex: qrSecretHex ?? this.qrSecretHex,
      workStartMinutes: workStartMinutes ?? this.workStartMinutes,
      workEndMinutes: workEndMinutes ?? this.workEndMinutes,
      lateGraceMinutes: lateGraceMinutes ?? this.lateGraceMinutes,
      earlyLeaveGraceMinutes: earlyLeaveGraceMinutes ?? this.earlyLeaveGraceMinutes,
      overtimeExtraMinutes: overtimeExtraMinutes ?? this.overtimeExtraMinutes,
      requireQr: requireQr ?? this.requireQr,
      qrWindowSeconds: qrWindowSeconds ?? this.qrWindowSeconds,
      verifyCheckOutGeo: verifyCheckOutGeo ?? this.verifyCheckOutGeo,
    );
  }
}
