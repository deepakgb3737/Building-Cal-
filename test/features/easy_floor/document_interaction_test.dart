import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_repository.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/drawing_point.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/ui/easy_floor_screen.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'document_test_support.dart';
import 'drawing_screen_test.dart' as drawing;
import 'annotation_interaction_test.dart' as text;
import 'advanced_interaction_test.dart' as editing;

Future<void> openWorkspace(WidgetTester t, DocumentRepository repo) async {
  t.view.physicalSize = const Size(320, 740);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => EasyFloorScreen(documents: repo))),
                  child: const Text('Launch EasyFloor'))))));
  await t.tap(find.text('Launch EasyFloor'));
  await t.pumpAndSettle();
}

Future<void> action(WidgetTester t, String label) async {
  await t.tap(find.byTooltip('Documents'));
  await t.pumpAndSettle();
  await t.ensureVisible(find.text(label));
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

Future<void> name(WidgetTester t, String value) async {
  await t.enterText(find.byKey(const ValueKey('documentName')), value);
  await t.tap(find.text('Confirm name'));
  await t.pumpAndSettle();
}

Future<void> save(WidgetTester t, String value) async {
  await action(t, 'Save');
  await name(t, value);
}

Future<void> choose(WidgetTester t, String label) async {
  await t.ensureVisible(find.text(label));
  await t.tap(find.text(label));
  await t.pumpAndSettle();
}

Future<void> openSaved(WidgetTester t, String label) async {
  await action(t, 'Open Document');
  await t.tap(find.widgetWithText(ListTile, label));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
      'Save named drawing, close workspace, reopen with text/units and fresh undo history',
      (t) async {
    final repo = DocumentRepository(TestDocumentStorage());
    await openWorkspace(t, repo);
    await drawing.outline(t);
    await text.add(t, 'Kitchen', const Offset(90, 130));
    await editing.menu(t, 'Measurement unit', DrawingUnit.feetInches.name);
    final geometry = editing.geometry(t);
    await save(t, 'House Plan');
    expect(find.text('House Plan'), findsOneWidget);
    expect((await repo.list()).single.name, 'House Plan');
    await action(t, 'Close Document');
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('Launch EasyFloor'), findsOneWidget);
    await t.tap(find.text('Launch EasyFloor'));
    await t.pumpAndSettle();
    await openSaved(t, 'House Plan');
    expect(editing.geometry(t), geometry);
    expect(text.textView(t).annotations.items.values.single.text, 'Kitchen');
    expect(drawing.painter(t).unit, DrawingUnit.feetInches);
    final undo = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Undo'));
    expect(undo.onSelected, isNull);
    final id = text.textView(t).annotations.items.keys.single;
    await t.tapAt(text.noteAt(t, id));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('annotationText')), 'Room A');
    await t.tap(find.text('Apply text'));
    await t.pumpAndSettle();
    await text.undo(t, 'Undo');
    expect(text.textView(t).annotations.items[id]!.text, 'Kitchen');
    expect(find.text('House Plan'), findsOneWidget);
    await text.undo(t, 'Redo');
    expect(find.text('House Plan *'), findsOneWidget);
  });
  testWidgets(
      'Save updates current document; Save As keeps original independent',
      (t) async {
    final repo = DocumentRepository(TestDocumentStorage());
    await openWorkspace(t, repo);
    await drawing.outline(t);
    await save(t, 'A');
    final first = (await repo.list()).single.id;
    await text.add(t, 'A note', const Offset(90, 130));
    await action(t, 'Save');
    expect((await repo.list()).length, 1);
    expect((await repo.open(first)).$2.annotations.items.length, 1);
    await action(t, 'Save As');
    await name(t, 'B');
    await text.add(t, 'B note', const Offset(180, 200));
    await action(t, 'Save');
    expect((await repo.list()).length, 2);
    await openSaved(t, 'A');
    expect(find.text('Unsaved changes'), findsNothing);
    expect(text.textView(t).annotations.items.length, 1);
    await openSaved(t, 'B');
    expect(text.textView(t).annotations.items.length, 2);
  });
  testWidgets(
      'New Document Cancel preserves edits; Discard resets model and history',
      (t) async {
    await openWorkspace(t, DocumentRepository(TestDocumentStorage()));
    await drawing.outline(t);
    final original = editing.geometry(t);
    await action(t, 'New Document');
    await choose(t, 'Cancel');
    expect(editing.geometry(t), original);
    await action(t, 'New Document');
    await choose(t, 'Discard Changes and Continue');
    expect(drawing.painter(t).model.walls, isEmpty);
    expect(find.text('Untitled'), findsOneWidget);
    final undo = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Undo'));
    expect(undo.onSelected, isNull);
  });
  testWidgets(
      'Save and Continue saves unsaved work before opening another document',
      (t) async {
    final repo = DocumentRepository(TestDocumentStorage());
    await repo.save(documentFixture(), 'Target');
    await openWorkspace(t, repo);
    await drawing.outline(t);
    await text.add(t, 'Keep this note', const Offset(90, 130));
    await openSaved(t, 'Target');
    expect(find.text('Unsaved changes'), findsOneWidget);
    await choose(t, 'Save and Continue');
    await name(t, 'Saved before switch');
    expect(find.text('Target'), findsOneWidget);
    final saved =
        (await repo.list()).firstWhere((e) => e.name == 'Saved before switch');
    expect((await repo.open(saved.id)).$2.annotations.items.values.single.text,
        'Keep this note');
    expect(drawing.painter(t).unit, DrawingUnit.feetInches);
  });
  testWidgets(
      'Failed Save and Continue never switches or discards the current drawing',
      (t) async {
    final storage = TestDocumentStorage();
    await openWorkspace(t, DocumentRepository(storage));
    await drawing.outline(t);
    final original = editing.geometry(t);
    storage.failWrite = true;
    await action(t, 'New Document');
    await choose(t, 'Save and Continue');
    await name(t, 'Failed save');
    expect(editing.geometry(t), original);
    expect(find.text('Untitled *'), findsOneWidget);
    expect(storage.files, isEmpty);
    expect(find.textContaining('Could not save.'), findsOneWidget);
    storage.failWrite = false;
    await action(t, 'New Document');
    await choose(t, 'Save and Continue');
    await name(t, 'Retry success');
    expect(drawing.painter(t).model.walls, isEmpty);
    expect((await DocumentRepository(storage).list()).single.name,
        'Retry success');
  });
  testWidgets(
      'View interactions do not warn; unit changes do; back navigation protects work',
      (t) async {
    final repo = DocumentRepository(TestDocumentStorage());
    await openWorkspace(t, repo);
    await drawing.outline(t);
    await save(t, 'Clean');
    await t.ensureVisible(find.byTooltip('Hide labels'));
    await t.tap(find.byTooltip('Hide labels'));
    await t.pumpAndSettle();
    expect(find.text('Clean'), findsOneWidget);
    await editing.menu(t, 'Measurement unit', DrawingUnit.mm.name);
    expect(find.text('Clean *'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await choose(t, 'Cancel');
    expect(drawing.painter(t).model.walls.length, 4);
    await t.pageBack();
    await t.pumpAndSettle();
    await choose(t, 'Discard Changes and Continue');
    expect(find.text('Launch EasyFloor'), findsOneWidget);
  });
  testWidgets(
      'Rename/delete confirmation keeps the current drawing independent of saved files',
      (t) async {
    final repo = DocumentRepository(TestDocumentStorage());
    await openWorkspace(t, repo);
    await drawing.outline(t);
    await save(t, 'Original');
    final geometry = editing.geometry(t);
    await action(t, 'Open Document');
    await t.tap(find.byTooltip('Manage Original'));
    await t.pumpAndSettle();
    await choose(t, 'Rename document');
    await name(t, 'Renamed');
    await t.tap(find.byTooltip('Manage Renamed'));
    await t.pumpAndSettle();
    await choose(t, 'Delete document');
    await choose(t, 'Cancel');
    expect((await repo.list()).length, 1);
    await t.tap(find.byTooltip('Manage Renamed'));
    await t.pumpAndSettle();
    await choose(t, 'Delete document');
    await choose(t, 'Delete document');
    await choose(t, 'Close list');
    expect((await repo.list()), isEmpty);
    expect(editing.geometry(t), geometry);
    expect(find.text('Renamed *'), findsOneWidget);
  });
  testWidgets(
      'Invalid document open and duplicate names preserve the current workspace',
      (t) async {
    final storage = TestDocumentStorage();
    final repository = DocumentRepository(storage);
    await repository.save(documentFixture(), 'Existing');
    await openWorkspace(t, repository);
    await drawing.outline(t);
    final geometry = editing.geometry(t);
    await save(t, 'Existing');
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(editing.geometry(t), geometry);
    storage.files['corrupt'] = '{';
    await action(t, 'Open Document');
    await t.tap(find.widgetWithText(ListTile, 'Unreadable document'));
    await t.pumpAndSettle();
    expect(find.textContaining('unreadable'), findsWidgets);
    await choose(t, 'Close list');
    expect(editing.geometry(t), geometry);
    expect(find.text('Untitled *'), findsOneWidget);
  });
  testWidgets('Open Cancel retains work; Open Discard restores target only',
      (t) async {
    final repo = DocumentRepository(TestDocumentStorage());
    await repo.save(documentFixture(), 'Target');
    await openWorkspace(t, repo);
    await drawing.outline(t);
    final original = editing.geometry(t);
    await openSaved(t, 'Target');
    await choose(t, 'Cancel');
    expect(editing.geometry(t), original);
    expect(find.text('Untitled *'), findsOneWidget);
    await openSaved(t, 'Target');
    await choose(t, 'Discard Changes and Continue');
    expect(find.text('Target'), findsOneWidget);
    expect(text.textView(t).annotations.items.length, 2);
    expect((await repo.list()).length, 1);
    await text.undo(t, 'Undo');
    expect(find.text('Target'), findsOneWidget);
  });
  testWidgets('Native exit request protects unsaved work', (t) async {
    await openWorkspace(t, DocumentRepository(TestDocumentStorage()));
    await drawing.outline(t);
    final original = editing.geometry(t);
    final cancel = WidgetsBinding.instance.handleRequestAppExit();
    await t.pumpAndSettle();
    await choose(t, 'Cancel');
    expect((await cancel).name, 'cancel');
    expect(editing.geometry(t), original);
    final exit = WidgetsBinding.instance.handleRequestAppExit();
    await t.pumpAndSettle();
    await choose(t, 'Discard Changes and Continue');
    expect((await exit).name, 'exit');
  });
  testWidgets('Document dialogs fit a narrow screen with enlarged text',
      (t) async {
    final repo = DocumentRepository(TestDocumentStorage());
    await openWorkspace(t, repo);
    t.view.physicalSize = const Size(240, 420);
    t.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpAndSettle();
    final longName = List.filled(80, 'A').join();
    await save(t, longName);
    await action(t, 'Open Document');
    expect(find.text(longName), findsWidgets);
    await t.ensureVisible(find.byTooltip('Manage $longName'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Manage $longName'));
    await t.pumpAndSettle();
    await choose(t, 'Delete document');
    await choose(t, 'Cancel');
    await choose(t, 'Close list');
    expect(t.takeException(), isNull);
  });
}
