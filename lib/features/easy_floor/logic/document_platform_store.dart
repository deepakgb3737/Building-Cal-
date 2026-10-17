import 'document_repository.dart';
import 'document_files_stub.dart'
    if (dart.library.io) 'document_files_io.dart'
    if (dart.library.js_interop) 'document_files_web.dart';

DocumentRepository createDocumentRepository() =>
    DocumentRepository(createStorage());
