void validateDocumentId(String id) {
  if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id)) {
    throw const FormatException('Invalid document identifier.');
  }
}

abstract class DocumentStorage {
  Future<Map<String, String>> readAll();
  Future<void> write(String id, String content);
  Future<void> delete(String id);
}
