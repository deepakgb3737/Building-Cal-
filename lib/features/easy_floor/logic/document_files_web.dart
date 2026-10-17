import 'dart:js_interop';
import 'document_storage.dart';

@JS('localStorage.length')
external int get _length;
@JS('localStorage.key')
external JSString? _key(int index);
@JS('localStorage.getItem')
external JSString? _get(JSString key);
@JS('localStorage.setItem')
external void _set(JSString key, JSString value);
@JS('localStorage.removeItem')
external void _remove(JSString key);

DocumentStorage createStorage() => _BrowserStorage();

class _BrowserStorage implements DocumentStorage {
  static const _prefix = 'buildcalc.easyfloor.';
  @override
  Future<Map<String, String>> readAll() async {
    final result = <String, String>{};
    for (var i = 0; i < _length; i++) {
      final key = _key(i)?.toDart;
      if (key != null && key.startsWith(_prefix)) {
        result[key.substring(_prefix.length)] = _get(key.toJS)?.toDart ?? '';
      }
    }
    return result;
  }

  @override
  Future<void> write(String id, String content) async {
    validateDocumentId(id);
    _set('$_prefix$id'.toJS, content.toJS);
  }

  @override
  Future<void> delete(String id) async {
    validateDocumentId(id);
    _remove('$_prefix$id'.toJS);
  }
}
