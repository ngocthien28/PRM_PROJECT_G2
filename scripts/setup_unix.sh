#!/usr/bin/env bash
set -e
flutter create --platforms=android,ios .
flutter pub add flutter_riverpod go_router firebase_core firebase_auth cloud_firestore firebase_storage firebase_messaging http sqflite path connectivity_plus image_picker qr_flutter mobile_scanner cached_network_image intl uuid flutter_local_notifications
flutter pub get
echo 'Next: flutterfire configure and implement wiring.'
