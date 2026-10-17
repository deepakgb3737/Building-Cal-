@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:grid_ceiling_calculator/features/easy_floor/logic/document_platform_store.dart';
import 'document_test_support.dart';

void main() {
  test('Browser documents persist across repository recreation', () async {
    final repo = createDocumentRepository();
    final entry = await repo.save(documentFixture(),
        'Browser test ${DateTime.now().microsecondsSinceEpoch}');
    addTearDown(() => repo.delete(entry.id));
    final reopened = await createDocumentRepository().open(entry.id);
    expect(reopened.$2.toJson(), documentFixture().toJson());
    await repo.rename(entry.id, '${entry.name} renamed');
    expect((await createDocumentRepository().open(entry.id)).$1.name,
        '${entry.name} renamed');
    await repo.delete(entry.id);
    await expectLater(
        createDocumentRepository().open(entry.id), throwsFormatException);
  });
}
