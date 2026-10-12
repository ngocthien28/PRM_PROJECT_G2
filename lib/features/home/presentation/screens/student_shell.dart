import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import 'home_screen.dart';

/// Minimal authenticated landing. Feature tabs/dashboards belong to later work.
class StudentShell extends ConsumerWidget {
  final String title;
  const StudentShell({super.key, this.title = 'Student'});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (title == 'Student') return const HomeScreen();
    final user = ref.watch(currentUserProvider).asData?.value;
    final action = ref.watch(authViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: Text('CampusHub · $title')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Welcome, ${user?.displayName ?? ""}'),
              if (user != null) Text(user.email),
              if (action.hasError)
                Text(action.error.toString(), key: const Key('auth-error')),
              if (action.asData?.value != null) Text(action.asData!.value!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: action.isLoading
                    ? null
                    : ref.read(authViewModelProvider.notifier).signOut,
                child: action.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
