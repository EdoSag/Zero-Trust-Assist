import 'dart:convert';
import 'dart:io';

import 'lab_result.dart';

/// A saved run, as the list of past runs shows it.
class SavedRun {
  const SavedRun({required this.file, required this.summary});

  final File file;

  /// The run in a few lines, as written when it was saved.
  final String summary;

  String get name => file.uri.pathSegments.last;
}

/// Keeps every finished run as one JSON file, so results survive closing the
/// app and can be shared later.
class ResultStore {
  ResultStore(this.directory);

  final Directory directory;

  Future<File> save(LabRun run) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}/${run.fileName}');
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(run.toJson()), flush: true);
    return file;
  }

  /// Saved runs, newest first. Files that cannot be read are skipped.
  Future<List<SavedRun>> list() async {
    if (!await directory.exists()) return const [];
    final files = [
      await for (final entry in directory.list())
        if (entry is File && entry.path.endsWith('.json')) entry,
    ]..sort((a, b) => b.path.compareTo(a.path));
    final runs = <SavedRun>[];
    for (final file in files) {
      try {
        final json = jsonDecode(await file.readAsString());
        final summary = json is Map ? json['summary'] : null;
        final text = summary is Map ? summary['text'] : null;
        if (text is String) runs.add(SavedRun(file: file, summary: text));
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return runs;
  }

  Future<void> delete(SavedRun run) async {
    if (await run.file.exists()) await run.file.delete();
  }
}
