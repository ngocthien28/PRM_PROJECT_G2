import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/validators.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/profile_view_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: ref.read(currentUserProvider).asData?.value?.displayName ?? '',
  );
  late final _phone = TextEditingController(
    text: ref.read(currentUserProvider).asData?.value?.phone ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(profileActionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                    ),
                    validator: Validators.displayName,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number (optional)',
                    ),
                    validator: Validators.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 20),
                  if (action.hasError)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        action.error.toString(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (action.asData?.value != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(action.asData!.value!),
                    ),
                  FilledButton(
                    onPressed: action.isLoading
                        ? null
                        : () async {
                            if (!(_form.currentState?.validate() ?? false)) {
                              return;
                            }
                            await ref
                                .read(profileActionProvider.notifier)
                                .updateProfile(_name.text, _phone.text);
                            if (!context.mounted) return;
                            if (!ref.read(profileActionProvider).hasError) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: action.isLoading
                        ? const CircularProgressIndicator()
                        : const Text('Save changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
