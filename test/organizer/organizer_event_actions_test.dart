import 'package:campushub/features/organizer_events/data/models/event_form_input.dart';
import 'package:campushub/features/organizer_events/presentation/viewmodels/organizer_events_view_model.dart';
import 'package:campushub/shared/enums/event_status.dart';
import 'package:campushub/shared/enums/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/event_fakes.dart';

void main() {
  final input = EventFormInput(
    title: 'Organizer Flutter Workshop',
    description: 'A practical hands-on Flutter workshop for CampusHub students.',
    category: 'technology',
    locationName: 'Hall A',
    startAt: DateTime.utc(2030, 6, 1, 9),
    endAt: DateTime.utc(2030, 6, 1, 11),
    capacity: 100,
  );

  test('actions create, update and cancel through the shared repository', () async {
    final repository = FakeEvents([]);
    final organizer = testUser(
      uid: 'organizer-1',
      role: UserRole.organizer,
    );
    var refreshes = 0;
    final actions = OrganizerEventActions(
      repository: repository,
      currentActor: () => organizer,
      refresh: () => refreshes++,
    );

    await actions.createEvent(input);
    final created = repository.events.single;
    expect(created.organizerId, organizer.uid);

    await actions.updateEvent(
      created.id,
      EventFormInput(
        title: 'Updated Flutter Workshop',
        description:
            'A practical hands-on Flutter workshop for CampusHub students.',
        category: 'technology',
        locationName: 'Hall A',
        startAt: DateTime.utc(2030, 6, 1, 9),
        endAt: DateTime.utc(2030, 6, 1, 11),
        capacity: 100,
      ),
    );
    await actions.cancelEvent(created.id);

    expect(repository.events.single.title, 'Updated Flutter Workshop');
    expect(repository.events.single.status, EventStatus.cancelled);
    expect(refreshes, 3);
  });
}
