// Basic smoke test — verifies the app mounts without crashing.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cornerman/main.dart';

void main() {
  testWidgets('App mounts without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CornermanApp()));
    // HomeScreen should be present.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
