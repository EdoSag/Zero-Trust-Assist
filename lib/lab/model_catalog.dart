/// The models the phone test can download and measure.
library;

/// Which runtime runs a model file.
enum LabRuntime {
  /// Google's LiteRT-LM, for `.litertlm` files.
  liteRtLm('LiteRT-LM'),

  /// llama.cpp, for `.gguf` files.
  llamaCpp('llama.cpp');

  const LabRuntime(this.label);

  final String label;
}

/// One downloadable model file, pinned by its exact size and SHA-256 so the
/// app refuses anything else.
class LabModel {
  const LabModel({
    required this.id,
    required this.title,
    required this.note,
    required this.runtime,
    required this.repoId,
    required this.fileName,
    required this.bytes,
    required this.sha256,
    required this.license,
  });

  /// Short stable name, used in result files.
  final String id;
  final String title;

  /// One line on why this model is in the test.
  final String note;
  final LabRuntime runtime;

  /// The Hugging Face repository the file is downloaded from.
  final String repoId;
  final String fileName;
  final int bytes;
  final String sha256;
  final String license;

  double get gigabytes => bytes / (1000 * 1000 * 1000);
}

/// Sizes and hashes read from the Hugging Face file listings on 2026-11-24.
const List<LabModel> labModels = [
  LabModel(
    id: 'gemma-4-e2b-litert',
    title: 'Gemma 4 E2B (small)',
    note: 'The planned default model.',
    runtime: LabRuntime.liteRtLm,
    repoId: 'litert-community/gemma-4-E2B-it-litert-lm',
    fileName: 'gemma-4-E2B-it.litertlm',
    bytes: 2588147712,
    sha256: '181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c',
    license: 'Apache 2.0',
  ),
  LabModel(
    id: 'gemma-4-e4b-litert',
    title: 'Gemma 4 E4B (large)',
    note: 'The larger option for better answers. Slower and needs more memory.',
    runtime: LabRuntime.liteRtLm,
    repoId: 'litert-community/gemma-4-E4B-it-litert-lm',
    fileName: 'gemma-4-E4B-it.litertlm',
    bytes: 3659530240,
    sha256: '0b2a8980ce155fd97673d8e820b4d29d9c7d99b8fa6806f425d969b145bd52e0',
    license: 'Apache 2.0',
  ),
  LabModel(
    id: 'dictalm-3-1.7b-gguf',
    title: 'DictaLM 3.0 1.7B (Hebrew)',
    note: 'The Hebrew-tuned backup, in a community 4-bit conversion.',
    runtime: LabRuntime.llamaCpp,
    repoId: 'Ibrerhim/DictaLM-3.0-1.7B-Instruct-GGUF',
    fileName: 'DictaLM-3.0-1.7B-Instruct-Q4_K_M.gguf',
    bytes: 1107408064,
    sha256: '1de7fd63c65045cb4da68717bb123b046606d603e23a9ed9336e7abde8a70d9c',
    license: 'Apache 2.0 (base model)',
  ),
  LabModel(
    id: 'gemma-4-e2b-gguf',
    title: 'Gemma 4 E2B (small), llama.cpp',
    note: 'The same model on the other engine, to compare the two engines.',
    runtime: LabRuntime.llamaCpp,
    repoId: 'unsloth/gemma-4-E2B-it-GGUF',
    fileName: 'gemma-4-E2B-it-Q4_K_M.gguf',
    bytes: 3106738272,
    sha256: '80d155f647d3a896669b1d1605b494b97ee9dbd1dcafd27957394134c280d270',
    license: 'Apache 2.0',
  ),
];
