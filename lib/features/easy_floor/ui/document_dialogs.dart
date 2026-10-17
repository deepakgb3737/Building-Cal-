import 'package:flutter/material.dart';
import '../logic/document_repository.dart';

class DocumentNameDialog extends StatefulWidget {
  const DocumentNameDialog(
      {super.key, required this.title, required this.initialName});
  final String title, initialName;
  @override
  State<DocumentNameDialog> createState() => _DocumentNameDialogState();
}

class _DocumentNameDialogState extends State<DocumentNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          scrollable: true,
          insetPadding: const EdgeInsets.all(12),
          title: Text(widget.title),
          content: Form(
              key: _form,
              child: TextFormField(
                  key: const ValueKey('documentName'),
                  controller: _name,
                  autofocus: true,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Document name'),
                  validator: (value) {
                    try {
                      DocumentRepository.validName(value ?? '');
                      return null;
                    } catch (_) {
                      return 'Enter a name of 1-80 characters';
                    }
                  })),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _name.text);
                  }
                },
                child: const Text('Confirm name')),
          ]);
}

class DocumentListDialog extends StatefulWidget {
  const DocumentListDialog(
      {super.key,
      required this.repository,
      this.currentId,
      required this.onRename,
      required this.onDelete});
  final DocumentRepository repository;
  final String? currentId;
  final ValueChanged<DocumentEntry> onRename, onDelete;
  @override
  State<DocumentListDialog> createState() => _DocumentListDialogState();
}

class _DocumentListDialogState extends State<DocumentListDialog> {
  late Future<List<DocumentEntry>> _entries = widget.repository.list();
  bool _busy = false, _writing = false;
  String? _error;
  Future<void> _manage(DocumentEntry entry, bool rename) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (rename) {
        final name = await showDialog<String>(
            context: context,
            builder: (_) => DocumentNameDialog(
                title: 'Rename document', initialName: entry.name));
        if (name == null || !mounted) return;
        setState(() => _writing = true);
        final changed = await widget.repository.rename(entry.id, name);
        widget.onRename(changed);
      } else {
        final yes = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
                    scrollable: true,
                    insetPadding: const EdgeInsets.all(12),
                    title: Text('Delete ${entry.name}?'),
                    content: Text(entry.id == widget.currentId
                        ? 'Delete the saved copy? The open drawing will remain unsaved.'
                        : 'This permanently deletes the saved document.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete document'))
                    ]));
        if (yes != true || !mounted) return;
        setState(() => _writing = true);
        await widget.repository.delete(entry.id);
        widget.onDelete(entry);
      }
      if (mounted) setState(() => _entries = widget.repository.list());
    } catch (e) {
      if (mounted) setState(() => _error = 'Document operation failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _writing = false;
        });
      }
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'Invalid or unsupported document';
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          insetPadding: const EdgeInsets.all(12),
          title: const Text('Open document',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          content: SizedBox(
              width: 480,
              height: MediaQuery.sizeOf(context).height * .4,
              child: Column(children: [
                if (_error != null)
                  ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .12),
                      child: SingleChildScrollView(child: Text(_error!))),
                if (_writing) const LinearProgressIndicator(),
                Expanded(
                    child: FutureBuilder<List<DocumentEntry>>(
                        future: _entries,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Column(children: [
                              const Text('Could not read saved documents.'),
                              TextButton(
                                  onPressed: () => setState(() =>
                                      _entries = widget.repository.list()),
                                  child: const Text('Retry'))
                            ]);
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.data!.isEmpty) {
                            return const Center(
                                child: Text('No saved documents yet.'));
                          }
                          return ListView(children: [
                            for (final entry in snapshot.data!)
                              ListTile(
                                  title: Text(entry.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                      '${_date(entry.modified)}${entry.id == widget.currentId ? ' · Current' : ''}'),
                                  enabled: !_busy,
                                  onTap: () {
                                    if (entry.invalid) {
                                      setState(() => _error =
                                          'This document is unreadable. The current drawing is unchanged.');
                                    } else {
                                      Navigator.pop(context, entry.id);
                                    }
                                  },
                                  trailing: PopupMenuButton<String>(
                                      enabled: !_busy,
                                      tooltip: 'Manage ${entry.name}',
                                      onSelected: (value) =>
                                          _manage(entry, value == 'rename'),
                                      itemBuilder: (_) => [
                                            if (!entry.invalid)
                                              const PopupMenuItem(
                                                  value: 'rename',
                                                  child:
                                                      Text('Rename document')),
                                            const PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Delete document')),
                                          ]))
                          ]);
                        }))
              ])),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Close list'))
          ]);
}
