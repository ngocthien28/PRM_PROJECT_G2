import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/core/theme/app_theme.dart';
import 'package:campushub/features/admin/data/admin_repository.dart';
import 'package:campushub/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:campushub/features/admin/presentation/viewmodels/admin_dashboard_view_model.dart';
import 'package:campushub/features/auth/presentation/screens/login_screen.dart';
import 'package:campushub/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:campushub/features/clubs/data/models/club_model.dart';
import 'package:campushub/features/clubs/presentation/screens/club_list_screen.dart';
import 'package:campushub/features/clubs/presentation/screens/club_detail_screen.dart';
import 'package:campushub/features/clubs/presentation/screens/manage_club_screen.dart';
import 'package:campushub/features/clubs/presentation/viewmodels/club_view_model.dart';
import 'package:campushub/features/events/presentation/viewmodels/event_list_view_model.dart';
import 'package:campushub/features/home/presentation/screens/home_screen.dart';
import 'package:campushub/features/notifications/data/models/app_notification.dart';
import 'package:campushub/features/notifications/presentation/screens/notification_screen.dart';
import 'package:campushub/features/notifications/presentation/viewmodels/notification_view_model.dart';
import 'package:campushub/shared/enums/club_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

// Preview data is confined to tests; production screens always use repositories.
final _clubs =
    [
          (
            'c1',
            'Creative Collective',
            'A home for curious minds and creative souls. Share ideas, try new things, and make something that matters together.',
          ),
          (
            'c2',
            'Code & Coffee',
            'Build cool things with people who love technology. Friendly workshops, project nights and plenty of good conversation.',
          ),
          (
            'c3',
            'Outdoor Society',
            'Step outside the ordinary. Meet fellow explorers for campus walks, weekend adventures and a breath of fresh air.',
          ),
        ].indexed
        .map(
          (entry) => ClubModel(
            id: entry.$2.$1,
            ownerId: 'uid',
            name: entry.$2.$2,
            description: entry.$2.$3,
            memberCount: [24, 38, 16][entry.$1],
            status: ClubStatus.active,
            createdAt: DateTime(2026, 9, 14),
            updatedAt: DateTime(2026, 10, 20),
          ),
        )
        .toList();
final _notices = [
  for (var i = 0; i < 3; i++)
    AppNotification(
      id: 'n$i',
      userId: 'uid',
      title: [
        'You found your people!',
        'A new chapter begins',
        'Your membership update',
      ][i],
      body: [
        'You joined Creative Collective. Welcome to the community!',
        'Your Code & Coffee membership is active. Great conversations start here.',
        'You left Outdoor Society. You can always join again.',
      ][i],
      type: 'club_membership',
      isRead: i > 0,
      createdAt: DateTime(2026, 10, 20 - i, 9, 30),
    ),
];

void main() {
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      final fonts = '$root/bin/cache/artifacts/material_fonts';
      final roboto = FontLoader('Roboto');
      for (final file in [
        'roboto-regular.ttf',
        'roboto-medium.ttf',
        'roboto-bold.ttf',
        'roboto-black.ttf',
      ]) {
        roboto.addFont(
          File(
            '$fonts/$file',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await roboto.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            '$fonts/materialicons-regular.otf',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await icons.load();
    }
  });
  final screens = <String, (Widget, UserRole)>{
    'clubs': (const ClubListScreen(), UserRole.organizer),
    'detail': (const ClubDetailScreen(clubId: 'c1'), UserRole.student),
    'form': (ManageClubScreen(club: _clubs.first), UserRole.organizer),
    'inbox': (const NotificationScreen(), UserRole.student),
    'admin': (const AdminDashboardScreen(), UserRole.admin),
    'home': (const HomeScreen(), UserRole.student),
    'login': (const LoginScreen(), UserRole.student),
  };
  for (final screen in screens.entries) {
    for (final device in ['desktop', 'phone', 'large-phone']) {
      testWidgets(
        '${screen.key} fits $device and renders a reviewable preview',
        (tester) async {
          final size = device == 'desktop'
              ? const Size(1440, 1000)
              : const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.platformDispatcher.textScaleFactorTestValue =
              device == 'large-phone' ? 1.6 : 1;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.binding.setSurfaceSize(size);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                currentUserProvider.overrideWith(
                  (ref) => Stream.value(testUser(role: screen.value.$2)),
                ),
                notificationInboxProvider.overrideWith(
                  (ref) => Stream.value(_notices),
                ),
                clubsProvider.overrideWith((ref) => Stream.value(_clubs)),
                clubProvider(
                  'c1',
                ).overrideWith((ref) => Stream.value(_clubs.first)),
                clubMembershipProvider((
                  clubId: 'c1',
                  userId: 'uid',
                )).overrideWith((ref) => Stream.value(null)),
                homeEventsProvider.overrideWith(
                  (ref) async => [
                    testEvent(title: 'An evening of ideas & possibilities'),
                    testEvent(
                      id: 'e2',
                      title: 'Campus Acoustic Sessions',
                      category: 'music',
                    ),
                  ],
                ),
                adminStatsProvider.overrideWith(
                  (ref) async => const AdminStats(
                    userCount: 128,
                    clubCount: 12,
                    eventCount: 8,
                    activeMembershipCount: 76,
                  ),
                ),
              ],
              child: RepaintBoundary(
                key: const Key('preview'),
                child: MaterialApp(
                  theme: AppTheme.light,
                  debugShowCheckedModeBanner: false,
                  home: screen.value.$1,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (device == 'large-phone') return;
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('preview')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/ui-previews').create(recursive: true);
            await File(
              'build/ui-previews/${screen.key}-$device.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        },
      );
    }
  }

  testWidgets('club search narrows results and editing updates live preview', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Widget app(Widget screen) => ProviderScope(
      overrides: [
        currentUserProvider.overrideWith(
          (ref) => Stream.value(testUser(role: UserRole.organizer)),
        ),
        notificationInboxProvider.overrideWith((ref) => Stream.value([])),
        clubsProvider.overrideWith((ref) => Stream.value(_clubs)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: screen),
    );
    await tester.pumpWidget(app(const ClubListScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('club-search')), 'coffee');
    await tester.pumpAndSettle();
    expect(find.text('Code & Coffee'), findsOneWidget);
    expect(find.text('Creative Collective'), findsNothing);
    await tester.pumpWidget(app(const ManageClubScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('clubNameField')),
      'A new community',
    );
    await tester.pumpAndSettle();
    expect(find.text('A new community'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('saveClubButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('Description must be 20-1000 characters.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('clubDescriptionField')),
      'A welcoming place for students to learn and create together.',
    );
    await tester.pumpAndSettle();
    expect(find.text('Description must be 20-1000 characters.'), findsNothing);
    await tester.tap(find.byKey(const Key('clubNameField')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('clubDescriptionField')));
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('clubDescriptionField')),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('saveClubButton')))
          .onPressed,
      isNotNull,
    );
  });
}
