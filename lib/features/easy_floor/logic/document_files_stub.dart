import 'document_storage.dart';

DocumentStorage createStorage() => _UnavailableStorage();

class _UnavailableStorage implements DocumentStorage {
  @override
  Future<Map<String, String>> readAll() async => throw UnsupportedError(
      'Document storage is unavailable on this platform.');
  @override
  Future<void> write(String id, String content) async =>
      throw UnsupportedError('Document storage is unavailable.');
  @override
  Future<void> delete(String id) async =>
      throw UnsupportedError('Document storage is unavailable.');
}
