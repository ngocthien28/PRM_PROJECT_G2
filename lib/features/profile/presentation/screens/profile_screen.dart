import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/local_profile_cache.dart';
import '../viewmodels/profile_view_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final action = ref.watch(profileActionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: CampusColors.mint,
                  backgroundImage: user?.avatarUrl == null
                      ? null
                      : NetworkImage(user!.avatarUrl!),
                  child: user?.avatarUrl == null
                      ? const Icon(Icons.person_outline, size: 48)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: IconButton.filled(
                    tooltip: 'Change profile photo',
                    onPressed: action.isLoading
                        ? null
                        : ref.read(profileActionProvider.notifier).chooseAvatar,
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              user?.displayName ?? 'Profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              user?.email ?? '',
              style: const TextStyle(color: CampusColors.muted),
            ),
          ),
          const SizedBox(height: 24),
          if (action.isLoading) const LinearProgressIndicator(),
          if (action.hasError)
            Text(
              action.error.toString(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (action.asData?.value != null)
            Text(
              action.asData!.value!,
              style: const TextStyle(color: CampusColors.teal),
            ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Edit profile'),
                  subtitle: Text(user?.phone ?? 'Name and phone number'),
                  onTap: () => context.push(RouteNames.editProfile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Appearance'),
                  subtitle: const Text('Theme preference'),
                  trailing: FutureBuilder<Object?>(
                    future: user == null
                        ? Future.value('system')
                        : ref
                              .watch(localProfileCacheProvider)
                              .readSetting(user.uid, 'theme'),
                    builder: (context, snapshot) => DropdownButton<String>(
                      value: ['system', 'light', 'dark'].contains(snapshot.data)
                          ? snapshot.data as String
                          : 'system',
                      items: const [
                        DropdownMenuItem(
                          value: 'system',
                          child: Text('System'),
                        ),
                        DropdownMenuItem(value: 'light', child: Text('Light')),
                        DropdownMenuItem(value: 'dark', child: Text('Dark')),
                      ],
                      onChanged: user == null
                          ? null
                          : (value) {
                              if (value != null) {
                                ref
                                    .read(localProfileCacheProvider)
                                    .saveSetting(user.uid, 'theme', value);
                              }
                            },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
