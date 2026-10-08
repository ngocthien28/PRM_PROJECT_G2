import 'package:flutter/material.dart';

/// Bootstrap-only screen. Replace with Riverpod + go_router when configured.
class CampusHubApp extends StatelessWidget {
  const CampusHubApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CampusHub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
    home: const Scaffold(
      body: Center(child: Text('CampusHub • Project Skeleton')),
    ),
  );
}
