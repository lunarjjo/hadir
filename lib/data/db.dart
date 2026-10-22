/// Koneksi & migrasi basis data SQLite.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:hadir/data/seed.dart';

/// Pembungkus koneksi dengan dukungan injeksi pabrik (untuk tes FFI)
/// dan jalur basis data khusus.
class AppDatabase {
  final DatabaseFactory? factoryOverride;

  /// Jalur lengkap berkas DB; null = lokasi bawaan perangkat.
  final String? dbPath;

  /// Jam yang bisa disuntik (untuk tes deterministik).
  final DateTime Function()? clock;

  /// Sandi akun admin awal saat basis data baru dibuat.
  final String? seedAdminPassword;

  static const int kVersion = 1;

  Future<Database>? _opened;

  AppDatabase({
    this.factoryOverride,
    this.dbPath,
    this.clock,
    this.seedAdminPassword,
  });

  /// Buka (sekali saja; aman dipanggil berulang).
  Future<Database> open() {
    _opened ??= _open();
    return _opened!;
  }

  Future<Database> _open() async {
    final factory = factoryOverride ?? databaseFactory;
    var path = dbPath;
    if (path == null) {
      final dir = await getDatabasesPath();
      path = p.join(dir, 'hadir.db');
    }
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> close() async {
    final opened = _opened;
    if (opened != null) {
      final db = await opened;
      await db.close();
      _opened = null;
    }
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL COLLATE NOCASE UNIQUE,
        display_name TEXT NOT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','member')),
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        iterations INTEGER NOT NULL CHECK (iterations > 0),
        active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE offices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        latitude REAL NOT NULL CHECK (latitude BETWEEN -90 AND 90),
        longitude REAL NOT NULL CHECK (longitude BETWEEN -180 AND 180),
        radius_meters INTEGER NOT NULL DEFAULT 50 CHECK (radius_meters BETWEEN 10 AND 5000),
        active INTEGER NOT NULL DEFAULT 1 CHECK (active IN (0,1)),
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE attendance (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL REFERENCES users(id),
        office_id TEXT NOT NULL REFERENCES offices(id),
        day TEXT NOT NULL,
        check_in_at INTEGER NOT NULL,
        check_in_lat REAL NOT NULL,
        check_in_lng REAL NOT NULL,
        check_in_distance REAL NOT NULL,
        check_in_geo_ok INTEGER NOT NULL,
        token_ok INTEGER NOT NULL DEFAULT 0,
        check_out_at INTEGER,
        check_out_lat REAL,
        check_out_lng REAL,
        check_out_distance REAL,
        check_out_geo_ok INTEGER,
        status_in TEXT NOT NULL CHECK (status_in IN ('tepat','terlambat')),
        status_out TEXT CHECK (status_out IN ('tepat','pulang_awal','lembur')),
        status TEXT NOT NULL CHECK (status IN ('hadir','terlambat','pulang_awal','lembur')),
        method TEXT NOT NULL CHECK (method IN ('qr','manual')),
        note TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute(
      'CREATE UNIQUE INDEX idx_att_user_day ON attendance(user_id, day)',
    );
    batch.execute('CREATE INDEX idx_att_day ON attendance(day)');
    batch.execute('CREATE INDEX idx_att_user ON attendance(user_id)');
    batch.execute('CREATE INDEX idx_att_office ON attendance(office_id)');
    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await batch.commit(noResult: true);

    await DatabaseSeeder(
      db,
      clock: clock,
      adminPassword: seedAdminPassword ?? 'admin123',
    ).seed();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrasi masa depan: tambahkan langkah per peningkatan versi.
  }
}
