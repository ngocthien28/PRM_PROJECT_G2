import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../features/notifications/data/models/app_notification.dart';

abstract interface class DesktopNotificationPresenter {
  Future<void> show(String id, String title, String body);
}

class DesktopNotificationListener {
  DesktopNotificationListener(this._firestore, this._presenter);

  final FirebaseFirestore _firestore;
  final DesktopNotificationPresenter _presenter;
  final Set<String> _seen = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Future<void> start(String userId) async {
    await stop();
    var primed = false;
    _subscription = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snapshot) async {
            if (!primed) {
              _seen.addAll(snapshot.docs.map((doc) => doc.id));
              primed = true;
              return;
            }
            for (final change in snapshot.docChanges) {
              if (change.type != DocumentChangeType.added ||
                  !_seen.add(change.doc.id)) {
                continue;
              }
              try {
                final item = AppNotification.fromMap(
                  change.doc.id,
                  change.doc.data() ?? const <String, dynamic>{},
                );
                if (item.userId != userId) continue;
                await _presenter.show(item.id, item.title, item.body);
              } catch (error) {
                debugPrint('Windows notification failed: $error');
              }
            }
          },
          onError: (Object error) {
            debugPrint('Windows notification inbox unavailable: $error');
          },
        );
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _seen.clear();
  }
}
