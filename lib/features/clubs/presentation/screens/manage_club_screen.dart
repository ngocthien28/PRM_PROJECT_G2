import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/routing/route_names.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/campus_scaffold.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../notifications/presentation/viewmodels/notification_view_model.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';
import '../../domain/usecases/create_club.dart';
import '../../domain/usecases/update_club.dart';
import '../viewmodels/club_form_validators.dart';
import 'club_list_screen.dart';

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
  Uint8List? _logoBytes;
  bool _busy = false;
  bool _submitted = false;

  bool get _isEditing => widget.club != null;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.club?.name ?? '';
    _descriptionController.text = widget.club?.description ?? '';
    _nameController.addListener(_refreshPreview);
    _descriptionController.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _nameController.text != (widget.club?.name ?? '') ||
      _descriptionController.text != (widget.club?.description ?? '') ||
      _logo != null;

  Future<bool> _confirmDiscard() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_busy) return false;
    if (!_hasUnsavedChanges) return true;
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text(
              'Your club changes have not been saved. You can keep editing or discard them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Discard changes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _close() async {
    if (!await _confirmDiscard() || !mounted) return;
    _leaveWithoutPrompt();
  }

  void _leaveWithoutPrompt() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.clubs);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() {
          _logo = picked;
          _logoBytes = bytes;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open this image. Please try another file.',
            ),
          ),
        );
      }
    }
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
          bytes: _logoBytes ?? await _logo!.readAsBytes(),
          fileName: _logo!.name,
        );
      }
      final result = _isEditing
          ? await UpdateClub(
              ref.read(firestoreProvider),
              ref.read(clubLogoServiceProvider),
            )(
              clubId: widget.club!.id,
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              actor: actor,
              newLogo: source,
            )
          : await CreateClub(
              ref.read(firestoreProvider),
              ref.read(clubLogoServiceProvider),
            )(
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
    final user = ref.watch(currentUserProvider).asData?.value;
    final theme = Theme.of(context);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final page = CampusScaffold(
      title: _isEditing ? 'Edit Club' : 'Create Club',
      section: CampusSection.clubs,
      role: user?.role.name ?? 'organizer',
      userName: user?.displayName ?? 'Organizer',
      unreadCount: ref.watch(unreadNotificationCountProvider),
      onBack: _busy ? null : _close,
      onBeforeNavigate: _confirmDiscard,
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: CampusPage(
                children: [
                  const Text(
                    'CLUB WORKSPACE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                      color: CampusColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isEditing
                        ? 'Keep your community growing.'
                        : 'Start something worth joining.',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'A great club starts with a clear idea and an open invitation.',
                    style: TextStyle(color: CampusColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 26),
                  LayoutBuilder(
                    builder: (context, box) {
                      final form = Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: CampusColors.mint,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.edit_note_rounded,
                                      color: CampusColors.teal,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'The essentials',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
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
                                  hintText: 'e.g. Campus Photography Club',
                                ),
                                validator: ClubFormValidators.name,
                              ),
                              const SizedBox(height: 16),
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
                                  alignLabelWithHint: true,
                                  hintText:
                                      'Tell people what your club is about, what you do together, and who can join. Minimum 20 characters.',
                                ),
                                validator: ClubFormValidators.description,
                              ),
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 22),
                              Text(
                                'Give your club a face',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'A memorable logo makes your community easier to find.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CampusColors.muted,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: CampusColors.canvas,
                                  border: Border.all(color: CampusColors.line),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 32,
                                      color: CampusColors.teal,
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      key: const Key('chooseClubLogoButton'),
                                      onPressed: _busy ? null : _pickLogo,
                                      icon: const Icon(
                                        Icons.upload_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _logo?.name ?? 'Choose optional logo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    const Text(
                                      'JPG, PNG or WebP · up to 5 MB',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: CampusColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      final preview = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'LIVE PREVIEW',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2,
                                color: CampusColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Card(
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 175,
                                  child: _logoBytes != null
                                      ? Image.memory(
                                          _logoBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : ClubCover(
                                          name: name.isEmpty ? 'C' : name,
                                          url: widget.club?.logoUrl,
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name.isEmpty ? 'Your club name' : name,
                                        style: theme.textTheme.titleLarge,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        description.isEmpty
                                            ? 'Your community story will appear here as you write.'
                                            : description,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.7,
                                          color: CampusColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      const Divider(),
                                      const SizedBox(height: 15),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.people_outline_rounded,
                                            size: 17,
                                            color: CampusColors.teal,
                                          ),
                                          const SizedBox(width: 7),
                                          Text(
                                            '${widget.club?.memberCount ?? 0} members',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF0D9),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  color: Color(0xFFA47A2A),
                                  size: 23,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  'Make a good first impression',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Be specific about your activities. A warm, clear introduction helps new members feel welcome.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.7,
                                    color: Color(0xFF88754F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                      if (box.maxWidth < 780) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [form, const SizedBox(height: 24), preview],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: form),
                          const SizedBox(width: 24),
                          SizedBox(width: 310, child: preview),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: CampusColors.line)),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                final cancel = OutlinedButton(
                  key: const Key('cancelClubFormButton'),
                  onPressed: _busy ? null : _close,
                  child: const Text('Cancel'),
                );
                final save = FilledButton.icon(
                  key: const Key('saveClubButton'),
                  onPressed: _busy ? null : _submit,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isEditing ? Icons.save_outlined : Icons.add,
                          size: 18,
                        ),
                  label: Text(_isEditing ? 'Save changes' : 'Create Club'),
                );
                if (box.maxWidth < 560) {
                  return OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 12,
                    overflowSpacing: 10,
                    children: [cancel, save],
                  );
                }
                return Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: CampusColors.muted,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'Your changes are saved when you submit.',
                        style: TextStyle(
                          color: CampusColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    cancel,
                    const SizedBox(width: 12),
                    save,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
    return PopScope(
      canPop: !_hasUnsavedChanges && !_busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !await _confirmDiscard() || !mounted) return;
        _leaveWithoutPrompt();
      },
      child: page,
    );
  }
}
