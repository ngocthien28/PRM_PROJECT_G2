import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';
import '../../features/notifications/data/notification_repository_impl.dart';
import '../../features/notifications/domain/usecases/receive_push_notification.dart';
import 'desktop_notification_listener.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> campusHubBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // notification+data messages are displayed by Android while in background.
  // The membership transaction already persisted the inbox entry.
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final _local = LocalNotificationService();
  late final DesktopNotificationListener _desktop = DesktopNotificationListener(
    FirebaseFirestore.instance,
    _local,
  );
  final _seen = <String>{};
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _messages;
  StreamSubscription<RemoteMessage>? _opened;
  Future<void> _queue = Future.value();
  String? _uid;
  String? _token;
  bool _started = false;
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  bool get supported => _isAndroid || _isWindows;
  NotificationRepositoryImpl get _repository =>
      NotificationRepositoryImpl(FirebaseFirestore.instance);

  Future<void> start(void Function() openInbox) async {
    if (!supported || _started || Firebase.apps.isEmpty) return;
    _started = true;
    try {
      await _local.initialize((_) => openInbox());
      if (_isAndroid) {
        FirebaseMessaging.onBackgroundMessage(campusHubBackgroundMessage);
        final receivePush = ReceivePushNotification(_local.show);
        _messages = FirebaseMessaging.onMessage.listen((message) async {
          try {
            await receivePush(
              message: message,
              signedInUserId: _uid,
              seenNotificationIds: _seen,
            );
          } catch (error) {
            debugPrint('Local notification failed: $error');
          }
        });
        _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
          if (receivePush.shouldOpenInbox(
            message,
            FirebaseAuth.instance.currentUser?.uid,
          )) {
            openInbox();
          }
        });
      }
      _auth = FirebaseAuth.instance.authStateChanges().listen((user) {
        unawaited(_watchProfile(user));
      });
      if (_isAndroid) {
        final initial = await FirebaseMessaging.instance.getInitialMessage();
        if (initial != null &&
            initial.data['userId'] == FirebaseAuth.instance.currentUser?.uid) {
          openInbox();
        }
      }
    } catch (_) {
      await dispose();
      rethrow;
    }
  }

  Future<void> _watchProfile(User? user) async {
    await _profile?.cancel();
    if (user == null) {
      _queue = _queue.then((_) => _bind(null));
      return;
    }
    _profile = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          (profile) {
            if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
            final uid = profile.data()?['status'] == 'active' ? user.uid : null;
            _queue = _queue.then((_) => _bind(uid)).catchError((Object error) {
              _uid = null;
              debugPrint('Push registration failed: $error');
            });
          },
          onError: (Object error) {
            debugPrint('Push profile unavailable: $error');
          },
        );
  }

  Future<void> _bind(String? uid) async {
    if (uid != null && FirebaseAuth.instance.currentUser?.uid != uid) return;
    if (_uid == uid) return;
    await _refresh?.cancel();
    await _desktop.stop();
    _refresh = null;
    _uid = uid;
    _token = null;
    _seen.clear();
    if (uid == null) return;
    if (_isWindows) {
      await _desktop.start(uid);
      return;
    }
    final permission = await FirebaseMessaging.instance.requestPermission();
    if (permission.authorizationStatus == AuthorizationStatus.denied) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;
    if (token != null) {
      await _repository.saveDeviceToken(uid, token);
      _token = token;
    }
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      if (_uid != uid) return;
      try {
        if (_token != null && _token != token) {
          await _repository.removeDeviceToken(uid, _token!);
        }
        await _repository.saveDeviceToken(uid, token);
        _token = token;
      } catch (error) {
        debugPrint('Push token refresh failed: $error');
      }
    });
  }

  /// FEATURE: UC-007 - Log Out
  /// MODULE: Authentication & Authorization
  /// DESCRIPTION: Dừng listener thông báo, bỏ device token và xóa thông báo local trước logout Auth.
  /// ROLE: Logout cleanup integration
  /// CALLED FROM: AuthViewModel.signOut.
  /// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
  /// TECHNOLOGY: Dart, Firebase Auth SDK, Firebase Core, Cloud Firestore SDK.
  Future<void> unregister() async {
    if (!supported || !_started) return;
    await _queue;
    await _refresh?.cancel();
    await _desktop.stop();
    if (_uid != null && _token != null) {
      await _repository.removeDeviceToken(_uid!, _token!);
    }
    if (_isAndroid) await FirebaseMessaging.instance.deleteToken();
    await _local.cancelAll();
    _uid = null;
    _token = null;
    _seen.clear();
  }

  Future<void> dispose() async {
    await _auth?.cancel();
    await _profile?.cancel();
    await _refresh?.cancel();
    await _messages?.cancel();
    await _opened?.cancel();
    await _desktop.stop();
    _started = false;
  }
}
