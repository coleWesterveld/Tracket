// Regression tests for the exercise search.
//
// The bug these pin down: picking an exercise mid-workout sometimes did
// nothing. The search closed (which is also what success looks like) and no
// exercise appeared. Two causes, both here:
//
//  1. The page's visibility was driven by the search field's focus, so
//     anything that took focus away tore the results list down. A tap fires on
//     pointer UP, so a teardown between down and up dropped the selection on
//     the floor.
//  2. Nothing awaited the caller's write, so the search could close (and the
//     rows it was holding could go) before the append had finished.

import 'dart:async';

import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/widgets/exercise_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _host({
  Future<void> Function(Map<String, dynamic>)? onSelected,
  VoidCallback? onDismiss,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ExerciseSearchWidget(
        theme: ThemeData.light(),
        onExerciseSelected: onSelected,
        onDismiss: onDismiss,
      ),
    ),
  );
}

/// Pumps the search and lets its exercise list actually load.
///
/// The list comes from sqflite, which is real I/O: it never resolves inside
/// testWidgets' fake-async zone, so the load has to happen under runAsync.
Future<void> _pumpSearch(WidgetTester tester, Widget host) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(host);
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Touch the database once so the schema and the seeded exercise list exist
    // before the first pump.
    await DatabaseHelper.instance.database;
  });

  testWidgets('losing focus does not close the search', (tester) async {
    int dismissals = 0;
    await _pumpSearch(tester, _host(onDismiss: () => dismissals++));

    // Exactly what the keyboard's return key, a tap elsewhere, or a field on
    // another screen taking focus all end up doing.
    final FocusNode node = tester.widget<TextField>(find.byType(TextField)).focusNode!;
    expect(node.hasFocus, isTrue, reason: 'search field should open focused');

    node.unfocus();
    await tester.pumpAndSettle();

    expect(dismissals, 0, reason: 'focus loss must not dismiss the search');
    expect(find.byType(ListTile), findsWidgets, reason: 'results must stay put');
  });

  testWidgets('the back arrow is what closes the search', (tester) async {
    int dismissals = 0;
    await _pumpSearch(tester, _host(onDismiss: () => dismissals++));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(dismissals, 1);
  });

  testWidgets('a selection is fully handled before the search closes',
      (tester) async {
    final order = <String>[];
    final completer = Completer<void>();

    await _pumpSearch(tester, _host(
      onSelected: (exercise) async {
        order.add('write-start');
        await completer.future;
        order.add('write-done');
      },
      onDismiss: () => order.add('dismiss'),
    ));

    await tester.tap(find.byType(ListTile).first);
    await tester.pump();

    // The write is still in flight, so the search is still the screen on top.
    expect(order, ['write-start']);

    completer.complete();
    await tester.pumpAndSettle();

    expect(order, ['write-start', 'write-done', 'dismiss'],
        reason: 'dismissal must come after the caller has finished');
  });

  testWidgets('a second tap while the first is still writing is ignored',
      (tester) async {
    int selections = 0;
    final completer = Completer<void>();

    await _pumpSearch(tester, _host(
      onSelected: (exercise) async {
        selections++;
        await completer.future;
      },
    ));

    await tester.tap(find.byType(ListTile).first);
    await tester.pump();
    await tester.tap(find.byType(ListTile).first, warnIfMissed: false);
    await tester.pump();

    expect(selections, 1, reason: 'one tap, one exercise');

    completer.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('the picked exercise arrives keyed exercise_id', (tester) async {
    Map<String, dynamic>? picked;

    await _pumpSearch(tester, _host(
      onSelected: (exercise) async => picked = exercise,
    ));

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!['exercise_id'], isA<int>(),
        reason: 'the workout page passes this straight to exerciseAppend');
    expect(picked!.containsKey('id'), isFalse);
  });
}
