// This is a basic Flutter widget test for AudioNotes.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:audio_notes/main.dart';
import 'package:audio_notes/providers/app_providers.dart';
import 'package:audio_notes/services/model_manager_service.dart';

class _TestModelManagerService extends ModelManagerService {
  @override
  Future<bool> isModelDownloaded(String modelName) async => true;
}

void main() {
  testWidgets('AudioNotes app loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelManagerServiceProvider
              .overrideWithValue(_TestModelManagerService()),
        ],
        child: const AudioNotesApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that the app title is displayed.
    expect(find.text('AudioNotes'), findsOneWidget);

    // Verify that the recording button (FAB) is present.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Recording button is visible', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modelManagerServiceProvider
              .overrideWithValue(_TestModelManagerService()),
        ],
        child: const AudioNotesApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Find the FAB with the current idle label
    final recordButton = find.widgetWithText(FloatingActionButton, '录音');
    expect(recordButton, findsOneWidget);
  });
}
