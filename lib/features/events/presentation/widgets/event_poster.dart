import 'package:flutter/material.dart';

class EventPoster extends StatelessWidget {
  const EventPoster({
    super.key,
    required this.url,
    required this.category,
    this.height = 180,
  });
  final String? url;
  final String category;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        switch (category) {
          'technology' => Icons.code_rounded,
          'sport' => Icons.sports_basketball_outlined,
          'music' => Icons.music_note_outlined,
          _ => Icons.groups_outlined,
        },
        size: 64,
        color: colors.onPrimaryContainer,
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return fallback;
    }
    return Image.network(
      url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}
