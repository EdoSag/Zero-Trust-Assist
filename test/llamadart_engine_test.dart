import 'package:flutter_test/flutter_test.dart';
import 'package:llamadart/llamadart.dart';
// The package's own check of which load settings a runtime accepts. The
// package version is pinned, so reaching into it here is safe.
// ignore: implementation_imports
import 'package:llamadart/src/core/models/inference/model_params_runtime_support.dart';
import 'package:zerotrust_assist/engine/assist_engine.dart';
import 'package:zerotrust_assist/engine/llamadart_engine.dart';
import 'package:zerotrust_assist/lab/model_catalog.dart';

void main() {
  group('modelParamsFor', () {
    test('LiteRT-LM gets the thread count without the batch setting', () {
      final params = modelParamsFor(
        '/models/gemma.litertlm',
        device: AssistDevice.cpu,
        contextSize: 4096,
        threads: 6,
      );
      expect(params.numberOfThreads, 6);
      expect(params.numberOfThreadsBatch, 0);
      expect(params.device, ComputeDevice.cpu);
      expect(params.contextSize, 4096);
    });

    test('LiteRT-LM on the graphics chip gets no thread count', () {
      final params = modelParamsFor(
        '/models/Gemma.LITERTLM',
        device: AssistDevice.gpu,
        contextSize: 4096,
        threads: 6,
      );
      expect(params.numberOfThreads, 0);
      expect(params.numberOfThreadsBatch, 0);
      expect(params.device, ComputeDevice.gpu);
    });

    test('llama.cpp gets both thread settings', () {
      final params = modelParamsFor(
        '/models/dicta.gguf',
        device: AssistDevice.cpu,
        contextSize: 2048,
        threads: 4,
      );
      expect(params.numberOfThreads, 4);
      expect(params.numberOfThreadsBatch, 4);
      expect(params.contextSize, 2048);
    });

    test('automatic threads leave both settings to the runtime', () {
      for (final path in ['/models/a.litertlm', '/models/a.gguf']) {
        final params = modelParamsFor(
          path,
          device: AssistDevice.cpu,
          contextSize: 4096,
          threads: 0,
        );
        expect(params.numberOfThreads, 0, reason: path);
        expect(params.numberOfThreadsBatch, 0, reason: path);
      }
    });

    test('every model of the test loads with every thread choice', () {
      // Build 1003 failed here: LiteRT-LM refused the batch thread setting
      // and no run with a chosen thread count could load.
      for (final model in labModels) {
        final runtime = switch (model.runtime) {
          LabRuntime.liteRtLm => LlamaRuntime.liteRtLm,
          LabRuntime.llamaCpp => LlamaRuntime.llamaCpp,
        };
        for (final device in AssistDevice.values) {
          for (final threads in [0, 2, 4, 6, 8]) {
            final params = modelParamsFor(
              '/models/${model.fileName}',
              device: device,
              contextSize: 4096,
              threads: threads,
            );
            expect(
              modelParamsUnsupportedBy(params, runtime, web: false),
              isEmpty,
              reason: '${model.id} on ${device.name} with $threads threads',
            );
          }
        }
      }
    });
  });
}
