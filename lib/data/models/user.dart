/// Model pengguna (tanpa rahasia sandi — hash tidak pernah keluar lapisan data).
library;

class _UnsetSentinel {
  const _UnsetSentinel();
}

class User {
  final String id;
  final String username;
  final String displayName;
  final String role; // 'admin' | 'member'
  final bool active;
  final int failedAttempts;
  final int? lockedUntilMs;
  final int createdAtMs;
  final int updatedAtMs;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
    required this.active,
    required this.failedAttempts,
    required this.lockedUntilMs,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  bool get isAdmin => role == 'admin';

  bool get isLockedNow =>
      lockedUntilMs != null &&
      DateTime.now().millisecondsSinceEpoch < lockedUntilMs!;

  User copyWith({
    String? displayName,
    String? role,
    bool? active,
    int? failedAttempts,
    Object? lockedUntilMs = _unset,
    int? updatedAtMs,
  }) {
    return User(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      active: active ?? this.active,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntilMs:
          identical(lockedUntilMs, _unset)
              ? this.lockedUntilMs
              : lockedUntilMs as int?,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  factory User.fromMap(Map<String, Object?> m) => User(
        id: m['id'] as String,
        username: m['username'] as String,
        displayName: m['display_name'] as String,
        role: m['role'] as String,
        active: (m['active'] as int) == 1,
        failedAttempts: m['failed_attempts'] as int,
        lockedUntilMs: m['locked_until'] as int?,
        createdAtMs: m['created_at'] as int,
        updatedAtMs: m['updated_at'] as int,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'role': role,
        'active': active ? 1 : 0,
        'failed_attempts': failedAttempts,
        'locked_until': lockedUntilMs,
        'created_at': createdAtMs,
        'updated_at': updatedAtMs,
      };

  static const Object _unset = _UnsetSentinel();
}

/// Baris rahasia sandi (hanya dipakai lapisan data/auth).
class UserSecret {
  final String userId;

  /// String hash lengkap `pbkdf2-sha256$iter$salt$hash`.
  final String encoded;

  const UserSecret({required this.userId, required this.encoded});
}
