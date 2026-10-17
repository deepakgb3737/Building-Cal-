import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_repository.dart';
import 'document_interaction_test.dart' as documents;
import 'document_test_support.dart';
import 'drawing_screen_test.dart' as drawing;
import 'natural_drawing_test.dart' as natural;
import 'sketch_refinement_interaction_test.dart' as sketch;

void main() {
  testWidgets(
      'Save/reopen keeps only refined geometry; draft undo stays unsaved',
      (t) async {
    final repository = DocumentRepository(TestDocumentStorage());
    await documents.openWorkspace(t, repository);
    await natural.stroke(t, sketch.roughSquare, finish: false);
    await sketch.choose(t, 'Yes, Straighten');
    await sketch.choose(t, 'Accept refinement');
    final clean = drawing.painter(t).model.toJson();
    await documents.save(t, 'Refined plan');
    final entry = (await repository.list()).single;
    await t.ensureVisible(find.byTooltip('Undo'));
    await t.tap(find.byTooltip('Undo'));
    await t.pumpAndSettle();
    expect(find.text('Refined plan *'), findsOneWidget);
    await documents.action(t, 'Save');
    expect(find.textContaining('Finish or cancel'), findsOneWidget);
    expect((await repository.open(entry.id)).$2.walls.toJson(), clean);
    await t.ensureVisible(find.byTooltip('Redo'));
    await t.tap(find.byTooltip('Redo'));
    await t.pumpAndSettle();
    expect(find.text('Refined plan'), findsOneWidget);
    await documents.action(t, 'Close Document');
    await t.tap(find.text('Launch EasyFloor'));
    await t.pumpAndSettle();
    await documents.openSaved(t, 'Refined plan');
    expect(drawing.painter(t).model.toJson(), clean);
    expect(drawing.painter(t).rawStroke, isEmpty);
    expect(find.text('Straighten and refine this sketch?'), findsNothing);
    final undo = t.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Undo'));
    expect(undo.onSelected, isNull);
  });
}
