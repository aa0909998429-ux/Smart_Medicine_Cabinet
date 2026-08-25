import 'package:flutter/material.dart';

import 'screens/symptom_search_screen.dart';

class SmartMedicineCabinetApp extends StatelessWidget {
  const SmartMedicineCabinetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '智慧藥櫃',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SymptomSearchScreen(),
    );
  }
}
