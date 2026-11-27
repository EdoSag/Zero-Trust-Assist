import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';
import 'package:zerotrust_assist/models/assist_models.dart';

void main() {
  test('every model is pinned by size and SHA-256', () {
    expect(labModels.map((m) => m.id).toSet().length, labModels.length);
    for (final model in labModels) {
      expect(model.sha256, matches(r'^[0-9a-f]{64}$'), reason: model.id);
      // A chat model is gigabytes; a search model is a few hundred MB.
      expect(
        model.bytes,
        greaterThan((model.search ? 100 : 500) * 1000 * 1000),
        reason: model.id,
      );
      expect(model.repoId, matches(r'^[\w.-]+/[\w.-]+$'), reason: model.id);
    }
  });

  test('the file type matches the runtime', () {
    for (final model in labModels) {
      final extension = switch (model.runtime) {
        LabRuntime.liteRtLm => '.litertlm',
        LabRuntime.llamaCpp => '.gguf',
      };
      expect(model.fileName, endsWith(extension), reason: model.id);
    }
  });

  test('the search model is no chat model', () {
    final search = labModels.where((m) => m.search).toList();
    expect(search.map((m) => m.id), ['embeddinggemma-300m-gguf']);
    // The chat's own list must never offer it.
    expect(chatModels.any((m) => m.search), isFalse);
  });

  test('the planned default model comes first', () {
    expect(labModels.first.id, 'gemma-4-e2b-litert');
  });
}
