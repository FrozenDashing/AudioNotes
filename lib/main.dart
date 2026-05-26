import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/home_screen.dart';
import 'data/todo_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Perform cleanup tasks in background
  _performStartupCleanup();
  
  runApp(
    const ProviderScope(
      child: AudioNotesApp(),
    ),
  );
}

/// Perform startup cleanup tasks (non-blocking)
Future<void> _performStartupCleanup() async {
  try {
    final repository = TodoRepository();
    
    // Clean up orphaned audio files (runs in background)
    await repository.cleanupOrphanedFiles();
    
    // Log storage usage
    final size = await repository.getTotalAudioStorageSize();
    print('Total audio storage used: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
  } catch (e) {
    print('Startup cleanup error: $e');
  }
}

class AudioNotesApp extends StatelessWidget {
  const AudioNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AudioNotes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          elevation: 4,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
