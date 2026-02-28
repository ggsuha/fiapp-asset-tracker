import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/dashboard/dashboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: Fiapp()));
}

class Fiapp extends StatelessWidget {
  const Fiapp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5C6B73),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F6F8),
      useMaterial3: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fiapp',
      theme: base.copyWith(
        cardTheme: const CardThemeData(
          margin: EdgeInsets.symmetric(vertical: 6),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
