import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../local/app_database.dart';
import '../../auth/data/models/app_user.dart';

/// FEATURE: UC-011 - Implement Local Profile and Settings Cache
/// MODULE: Profile Management
/// DESCRIPTION: Cung cấp LocalProfileCache cho profile stream và màn hình settings.
/// ROLE: Local cache injection
/// CALLED FROM: currentUserProvider và ProfileScreen.
/// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
/// TECHNOLOGY: Dart, Riverpod, Cloud Firestore SDK, sqflite, dart:convert.
final localProfileCacheProvider = Provider<LocalProfileCache>(
  (ref) => LocalProfileCache(),
);

class LocalProfileCache {
  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Lưu profile theo UID với thời gian milliseconds để JSON encode được.
  /// ROLE: SQLite profile/settings cache
  /// CALLED FROM: currentUserProvider.watchProfile.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, Cloud Firestore SDK, sqflite, dart:convert.
  Future<void> saveProfile(AppUser user) => _save(user.uid, 'profile', {
    ...user.toMap(),
    'createdAt': user.createdAt.millisecondsSinceEpoch,
    'updatedAt': user.updatedAt.millisecondsSinceEpoch,
  });
  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Đọc profile cache và khôi phục Timestamp; không dùng cache để cấp quyền route.
  /// ROLE: SQLite profile/settings cache
  /// CALLED FROM: Cache API / test fakes; chưa có production caller.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, Cloud Firestore SDK, sqflite, dart:convert.
  Future<AppUser?> readProfile(String uid) async {
    final data = await _read(uid, 'profile');
    if (data == null) return null;
    data['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(
      data['createdAt'] as int,
    );
    data['updatedAt'] = Timestamp.fromMillisecondsSinceEpoch(
      data['updatedAt'] as int,
    );
    return AppUser.fromMap(data);
  }

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Lưu setting vào namespace setting:key thuộc UID hiện tại.
  /// ROLE: SQLite profile/settings cache
  /// CALLED FROM: ProfileScreen dropdown.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, Cloud Firestore SDK, sqflite, dart:convert.
  Future<void> saveSetting(String uid, String key, Object value) =>
      _save(uid, 'setting:$key', {'value': value});
  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Đọc setting theo UID/key; trả null khi chưa có.
  /// ROLE: SQLite profile/settings cache
  /// CALLED FROM: ProfileScreen FutureBuilder.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, Cloud Firestore SDK, sqflite, dart:convert.
  Future<Object?> readSetting(String uid, String key) async =>
      (await _read(uid, 'setting:$key'))?['value'];

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Ghi JSON vào local_profile_cache bằng insert replace; bỏ qua nếu database không khả dụng.
  /// ROLE: SQLite profile/settings cache
  /// CALLED FROM: saveProfile và saveSetting.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, Cloud Firestore SDK, sqflite, dart:convert.
  Future<void> _save(String uid, String key, Map<String, dynamic> data) async {
    final db = await AppDatabase.instance.database;
    if (db == null) return;
    await db.insert('local_profile_cache', {
      'user_id': uid,
      'cache_key': key,
      'payload': jsonEncode(data),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// FEATURE: UC-011 - Implement Local Profile and Settings Cache
  /// MODULE: Profile Management
  /// DESCRIPTION: Query bằng user_id/cache_key rồi JSON decode; trả null khi thiếu database hoặc dữ liệu.
  /// ROLE: SQLite profile/settings cache
  /// CALLED FROM: readProfile và readSetting.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Riverpod, Cloud Firestore SDK, sqflite, dart:convert.
  Future<Map<String, dynamic>?> _read(String uid, String key) async {
    final db = await AppDatabase.instance.database;
    if (db == null) return null;
    final rows = await db.query(
      'local_profile_cache',
      columns: ['payload'],
      where: 'user_id = ? AND cache_key = ?',
      whereArgs: [uid, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload']! as String) as Map<String, dynamic>;
  }
}
