import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../local/app_database.dart';
import '../../auth/data/models/app_user.dart';

final localProfileCacheProvider = Provider<LocalProfileCache>(
  (ref) => LocalProfileCache(),
);

class LocalProfileCache {
  Future<void> saveProfile(AppUser user) => _save(user.uid, 'profile', {
    ...user.toMap(),
    'createdAt': user.createdAt.millisecondsSinceEpoch,
    'updatedAt': user.updatedAt.millisecondsSinceEpoch,
  });
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

  Future<void> saveSetting(String uid, String key, Object value) =>
      _save(uid, 'setting:$key', {'value': value});
  Future<Object?> readSetting(String uid, String key) async =>
      (await _read(uid, 'setting:$key'))?['value'];

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
