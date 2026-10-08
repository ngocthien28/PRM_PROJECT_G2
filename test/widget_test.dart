import 'package:flutter_test/flutter_test.dart';
import 'package:campushub/app.dart';

void main() {
  testWidgets('Bootstrap shows CampusHub', (tester) async {
    await tester.pumpWidget(const CampusHubApp());
    expect(find.text('CampusHub • Project Skeleton'), findsOneWidget);
  });
}
