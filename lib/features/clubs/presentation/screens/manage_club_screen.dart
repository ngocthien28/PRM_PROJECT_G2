import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/services/firebase_providers.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../data/club_repository.dart';
import '../../data/models/club_model.dart';

class ManageClubScreen extends ConsumerStatefulWidget {
  const ManageClubScreen({super.key, this.club});
  final ClubModel? club;
  @override
  ConsumerState<ManageClubScreen> createState() => _State();
}

class _State extends ConsumerState<ManageClubScreen> {
  final key = GlobalKey<FormState>(),
      name = TextEditingController(),
      description = TextEditingController();
  XFile? logo;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    name.text = widget.club?.name ?? '';
    description.text = widget.club?.description ?? '';
  }

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !key.currentState!.validate()) return;
    final actor = ref.read(currentUserProvider).asData?.value;
    if (actor == null) return;
    setState(() => busy = true);
    try {
      ClubLogoSource? source;
      if (logo != null) {
        source = ClubLogoSource(
          bytes: await logo!.readAsBytes(),
          fileName: logo!.name,
        );
      }
      final repo = ref.read(clubRepositoryProvider);
      final result = widget.club == null
          ? await repo.createClub(
              name: name.text,
              description: description.text,
              actor: actor,
              logo: source,
            )
          : await repo.updateClub(
              clubId: widget.club!.id,
              name: name.text,
              description: description.text,
              actor: actor,
              newLogo: source,
            );
      if (mounted) {
        context.go(RouteNames.clubDetail(result.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.club == null ? 'Create Club' : 'Edit Club'),
    ),
    body: Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Club name'),
            validator: (v) {
              final n = v?.trim() ?? '';
              return n.length < 3 || n.length > 80
                  ? 'Name must be 3-80 characters.'
                  : null;
            },
          ),
          TextFormField(
            controller: description,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description'),
            validator: (v) {
              final n = v?.trim() ?? '';
              return n.length < 20 || n.length > 1000
                  ? 'Description must be 20-1000 characters.'
                  : null;
            },
          ),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      setState(() => logo = picked);
                    }
                  },
            icon: const Icon(Icons.image),
            label: Text(logo?.name ?? 'Choose optional logo'),
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: busy
                ? const CircularProgressIndicator()
                : Text(widget.club == null ? 'Create Club' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
}
