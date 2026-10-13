import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/routing/route_names.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';
import '../viewmodels/club_form_validators.dart';

class ManageClubScreen extends ConsumerStatefulWidget {
  const ManageClubScreen({super.key, this.club});

  final ClubModel? club;

  @override
  ConsumerState<ManageClubScreen> createState() => _ManageClubScreenState();
}

class _ManageClubScreenState extends ConsumerState<ManageClubScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _nameFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  XFile? _logo;
  bool _busy = false;
  bool _submitted = false;

  bool get _isEditing => widget.club != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.club?.name ?? '';
    _descriptionController.text = widget.club?.description ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  void _close() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.clubs);
    }
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null && mounted) setState(() => _logo = picked);
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _submitted = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final actor = ref.read(currentUserProvider).asData?.value;
    if (actor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your session has ended. Please sign in again.'),
        ),
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    try {
      ClubLogoSource? source;
      if (_logo != null) {
        source = ClubLogoSource(
          bytes: await _logo!.readAsBytes(),
          fileName: _logo!.name,
        );
      }
      final repository = ref.read(clubRepositoryProvider);
      final result = _isEditing
          ? await repository.updateClub(
              clubId: widget.club!.id,
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              actor: actor,
              newLogo: source,
            )
          : await repository.createClub(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              actor: actor,
              logo: source,
            );
      if (!mounted) return;
      if (_isEditing && context.canPop()) {
        context.pop();
      } else {
        context.pushReplacement(RouteNames.clubDetail(result.id));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _busy ? null : _close,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_isEditing ? 'Edit Club' : 'Create Club'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                children: [
                  Text(
                    _isEditing
                        ? 'Update club information'
                        : 'Create a new campus club',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a clear name, a useful description, and an optional logo.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            key: const Key('clubNameField'),
                            controller: _nameController,
                            focusNode: _nameFocus,
                            enabled: !_busy,
                            maxLength: 80,
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) =>
                                _descriptionFocus.requestFocus(),
                            decoration: const InputDecoration(
                              labelText: 'Club name',
                              hintText: 'Example: Campus Photography Club',
                              prefixIcon: Icon(Icons.groups_outlined),
                            ),
                            validator: ClubFormValidators.name,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const Key('clubDescriptionField'),
                            controller: _descriptionController,
                            focusNode: _descriptionFocus,
                            enabled: !_busy,
                            minLines: 5,
                            maxLines: 8,
                            maxLength: 1000,
                            textInputAction: TextInputAction.newline,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              hintText:
                                  'Describe the club activities and who should join (at least 20 characters).',
                              alignLabelWithHint: true,
                            ),
                            validator: ClubFormValidators.description,
                          ),
                          const SizedBox(height: 12),
                          _LogoPreview(
                            file: _logo,
                            existingUrl: widget.club?.logoUrl,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const Key('chooseClubLogoButton'),
                            onPressed: _busy ? null : _pickLogo,
                            icon: const Icon(
                              Icons.add_photo_alternate_outlined,
                            ),
                            label: Text(_logo?.name ?? 'Choose optional logo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('cancelClubFormButton'),
                          onPressed: _busy ? null : _close,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          key: const Key('saveClubButton'),
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _isEditing ? Icons.save_outlined : Icons.add,
                                ),
                          label: Text(
                            _isEditing ? 'Save changes' : 'Create Club',
                          ),
                        ),
                      ),
                    ],
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

class _LogoPreview extends StatelessWidget {
  const _LogoPreview({required this.file, required this.existingUrl});

  final XFile? file;
  final String? existingUrl;

  @override
  Widget build(BuildContext context) {
    final url = existingUrl?.trim();
    Widget image = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined, size: 44)),
    );
    if (file != null) {
      image = FutureBuilder<Uint8List>(
        future: file!.readAsBytes(),
        builder: (_, snapshot) => snapshot.hasData
            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
            : const Center(child: CircularProgressIndicator()),
      );
    } else if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(height: 190, child: image),
    );
  }
}
