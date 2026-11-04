import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../viewmodels/profile_view_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  /// FEATURE: UC-009 - Update Profile
  /// MODULE: Profile Management
  /// DESCRIPTION: Tạo state sở hữu form/controller chỉnh sửa profile.
  /// ROLE: Profile form lifecycle
  /// CALLED FROM: Flutter EditProfileScreen lifecycle.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod.
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _editingUid;

  /// FEATURE: UC-009 - Update Profile
  /// MODULE: Profile Management
  /// DESCRIPTION: Giải phóng name/phone controllers khi đóng màn hình.
  /// ROLE: Profile form lifecycle
  /// CALLED FROM: Flutter state lifecycle.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod.
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// FEATURE: UC-009, UC-012, UC-013
  /// MODULE: Profile Management
  /// DESCRIPTION: Chờ profile đúng UID, điền name/phone, gắn validator và chỉ pop sau action thành công.
  /// ROLE: Validated edit form
  /// CALLED FROM: appRouterProvider /profile/edit.
  /// RELATED FILES: lib/features/profile/presentation/viewmodels/profile_view_model.dart; lib/features/profile/data/profile_repository_impl.dart.
  /// TECHNOLOGY: Dart, Flutter Material, Riverpod.
  @override
  Widget build(BuildContext context) {
    final action = ref.watch(profileActionProvider);
    final profile = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: AsyncValueView(
        value: profile,
        onRetry: () => ref.invalidate(currentUserProvider),
        data: (user) {
          if (user == null) {
            return AppErrorView(
              error: const AppException('Your profile is unavailable.'),
              onRetry: () => ref.invalidate(currentUserProvider),
            );
          }
          if (_editingUid != user.uid) {
            _editingUid = user.uid;
            _name.text = user.displayName;
            _phone.text = user.phone ?? '';
          }
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      TextFormField(
                        enabled: !action.isLoading,
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Display name',
                        ),
                        validator: Validators.displayName,
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: !action.isLoading,
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
                                if (!(_form.currentState?.validate() ??
                                    false)) {
                                  return;
                                }
                                await ref
                                    .read(profileActionProvider.notifier)
                                    .updateProfile(_name.text, _phone.text);
                                if (!context.mounted) return;
                                if (ref
                                        .read(profileActionProvider)
                                        .asData
                                        ?.value !=
                                    null) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: action.isLoading
                            ? const LoadingIndicator(
                                message: 'Saving profile...',
                              )
                            : const Text('Save changes'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
