import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';

void main() {
  test('every model is pinned by size and SHA-256', () {
    expect(labModels.map((m) => m.id).toSet().length, labModels.length);
    for (final model in labModels) {
      expect(model.sha256, matches(r'^[0-9a-f]{64}$'), reason: model.id);
      expect(model.bytes, greaterThan(500 * 1000 * 1000), reason: model.id);
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

  test('the planned default model comes first', () {
    expect(labModels.first.id, 'gemma-4-e2b-litert');
  });
}
