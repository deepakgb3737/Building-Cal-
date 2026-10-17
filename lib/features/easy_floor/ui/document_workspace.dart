import 'package:flutter/material.dart';
import '../logic/document_repository.dart';
import '../logic/drawing_annotations.dart';
import '../logic/floor_document.dart';
import '../logic/wall_network.dart';
import 'document_dialogs.dart';

/// Coordinates dialogs/persistence, never mutates the live drawing during I/O.
class DocumentWorkspace extends ChangeNotifier {
  DocumentWorkspace(
      {required this.repository,
      required this.context,
      required this.capture,
      required this.apply,
      required this.revision,
      required this.settingsSignature,
      required this.pending}) {
    _savedRevision = revision();
    _savedSettings = settingsSignature();
  }
  final DocumentRepository repository;
  final BuildContext Function() context;
  final FloorDocument Function() capture;
  final ValueChanged<FloorDocument> apply;
  final int Function() revision;
  final String Function() settingsSignature;
  final bool Function() pending;
  String? id;
  String name = 'Untitled';
  late int _savedRevision;
  late String _savedSettings;
  bool busy = false, writing = false, _checking = false, _disposed = false;
  bool get dirty =>
      pending() ||
      revision() != _savedRevision ||
      settingsSignature() != _savedSettings;
  bool get _alive => !_disposed && context().mounted;
  void _message(String text) {
    if (_alive) {
      final messenger = ScaffoldMessenger.of(context());
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(text)));
    }
  }

  void _saved(DocumentEntry? entry) {
    id = entry?.id;
    name = entry?.name ?? 'Untitled';
    _savedRevision = revision();
    _savedSettings = settingsSignature();
    notifyListeners();
  }

  Future<bool> save({bool asCopy = false}) async {
    if (busy || !_alive) return false;
    if (pending()) {
      _message('Finish or cancel the current drawing before saving.');
      return false;
    }
    busy = true;
    notifyListeners();
    try {
      String? chosen = name;
      if (id == null || asCopy) {
        chosen = await showDialog<String>(
            context: context(),
            builder: (_) => DocumentNameDialog(
                title: asCopy ? 'Save document as' : 'Save document',
                initialName: asCopy ? '$name copy' : name));
        if (!_alive || chosen == null) return false;
      }
      final snapshot = capture(),
          savedRevision = revision(),
          savedSettings = settingsSignature();
      writing = true;
      notifyListeners();
      final entry =
          await repository.save(snapshot, chosen, id: asCopy ? null : id);
      if (!_alive) return false;
      id = entry.id;
      name = entry.name;
      _savedRevision = savedRevision;
      _savedSettings = savedSettings;
      _message('Document saved.');
      return true;
    } catch (e) {
      _message('Could not save. Your drawing is still open: $e');
      return false;
    } finally {
      busy = false;
      writing = false;
      if (_alive) notifyListeners();
    }
  }

  Future<bool> confirmLeave() async {
    if (busy || _checking || !_alive) return false;
    if (!dirty) return true;
    _checking = true;
    try {
      final decision = await showDialog<String>(
          context: context(),
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('Unsaved changes'),
                  content: Text(
                      'Save changes to $name? Discarding will lose unsaved edits.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, 'cancel'),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, 'discard'),
                        child: const Text('Discard Changes and Continue')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, 'save'),
                        child: const Text('Save and Continue')),
                  ]));
      if (!_alive) return false;
      if (decision == 'discard') return true;
      return decision == 'save' && await save();
    } finally {
      _checking = false;
    }
  }

  Future<void> action(String value) async {
    if (busy || !_alive) return;
    if (value == 'save' || value == 'saveAs') {
      await save(asCopy: value == 'saveAs');
      return;
    }
    if (value == 'new') {
      if (await confirmLeave() && _alive) {
        apply(FloorDocument(
            WallNetwork(), DrawingAnnotations(), const DocumentSettings()));
        _saved(null);
      }
      return;
    }
    if (value == 'open') {
      final target = await showDialog<String>(
          context: context(),
          barrierDismissible: false,
          builder: (_) => DocumentListDialog(
              repository: repository,
              currentId: id,
              onRename: (entry) {
                if (entry.id == id) {
                  name = entry.name;
                  notifyListeners();
                }
              },
              onDelete: (entry) {
                if (entry.id == id) {
                  id = null;
                  _savedRevision = -1;
                  notifyListeners();
                }
              }));
      if (!_alive || target == null || target == id) return;
      try {
        final loaded = await repository.open(target);
        if (await confirmLeave() && _alive) {
          apply(loaded.$2);
          _saved(loaded.$1);
        }
      } catch (e) {
        _message(
            'Could not open document. The current drawing is unchanged: $e');
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
