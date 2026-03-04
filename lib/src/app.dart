import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'repositories/progress_repository.dart';
import 'repositories/vocab_repository.dart';

class VocabHillApp extends StatelessWidget {
  VocabHillApp({
    super.key,
    VocabRepository? repository,
    ProgressRepository? progressRepository,
  }) : repository = repository ?? const AssetVocabRepository(),
       progressRepository = progressRepository ?? SqliteProgressRepository();

  final VocabRepository repository;
  final ProgressRepository progressRepository;

  @override
  Widget build(BuildContext context) {
    const sand = Color(0xFFF5E7CC);
    const pine = Color(0xFF1F3B2C);
    const clay = Color(0xFFB86A42);

    return MaterialApp(
      title: 'Vocab Hill',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: clay,
          brightness: Brightness.light,
          surface: sand,
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF6EC),
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: pine,
            height: 1.05,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: pine,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: pine,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.45,
            color: Color(0xFF2A2C2A),
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF484A48),
          ),
        ),
        useMaterial3: true,
      ),
      home: HomePage(
        repository: repository,
        progressRepository: progressRepository,
      ),
    );
  }
}
