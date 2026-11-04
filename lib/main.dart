import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';

/// FEATURE: UC-001 - Build Shared App Navigation and Theme
/// MODULE: App Shell
/// DESCRIPTION: Khởi tạo binding, định dạng ngày vi và ProviderScope trước khi chạy CampusHubApp.
/// ROLE: App bootstrap
/// CALLED FROM: Flutter entry point.
/// RELATED FILES: lib/app.dart; lib/features/auth/presentation/viewmodels/auth_view_model.dart.
/// TECHNOLOGY: Dart, Flutter Material, Riverpod.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('vi', null);
  } catch (_) {}
  runApp(const ProviderScope(child: CampusHubApp()));
}
