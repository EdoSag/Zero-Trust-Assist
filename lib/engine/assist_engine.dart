/// The one place the app meets a model runtime.
///
/// Screens and the phone test talk to [AssistEngine] only, so the library
/// underneath (see `llamadart_engine.dart`) can be swapped without touching
/// them, and tests can run against a fake.
library;

/// Who said a message.
enum AssistRole { system, user, assistant }

/// One message of a conversation.
class AssistMessage {
  const AssistMessage(this.role, this.text);

  const AssistMessage.system(this.text) : role = AssistRole.system;
  const AssistMessage.user(this.text) : role = AssistRole.user;
  const AssistMessage.assistant(this.text) : role = AssistRole.assistant;

  final AssistRole role;
  final String text;
}

/// Where the model should run.
enum AssistDevice {
  /// The processor. Works on every phone.
  cpu,

  /// The graphics chip. Faster where the phone and its driver allow it; a
  /// load that asks for it fails instead of quietly using the CPU, so a test
  /// knows which one it measured.
  gpu,
}

/// Token counts and timings of one answer, as the runtime measured them.
class AssistUsage {
  const AssistUsage({
    required this.promptTokens,
    required this.cachedPromptTokens,
    required this.completionTokens,
    required this.timeToFirstToken,
    required this.duration,
  });

  /// Tokens of the request (instructions and text) the model had to read.
  final int promptTokens;

  /// How many of those it already had in memory from the previous request.
  final int cachedPromptTokens;

  /// Tokens of the answer.
  final int completionTokens;

  /// From the start of the request to the first piece of the answer.
  final Duration? timeToFirstToken;

  /// From the start of the request to the end of the answer.
  final Duration? duration;
}

/// The runtime's own counters for the last answer: how many tokens it read
/// and wrote and how long each part took, measured inside the native library.
class AssistPerf {
  const AssistPerf({
    required this.promptTokens,
    required this.promptMs,
    required this.answerTokens,
    required this.answerMs,
  });

  /// Tokens of the request the model actually had to read (not ones it kept
  /// from the previous request).
  final int promptTokens;

  /// Milliseconds spent reading them.
  final double promptMs;

  /// Tokens of the answer.
  final int answerTokens;

  /// Milliseconds spent writing them.
  final double answerMs;
}

/// A piece of an answer. The last piece carries [usage] when the runtime
/// reports it.
class AssistChunk {
  const AssistChunk(this.text, {this.usage});

  final String text;
  final AssistUsage? usage;
}

/// A loaded model that answers requests, one at a time.
abstract class AssistEngine {
  /// Loads the model file at [path]. Throws when the file or the [device]
  /// cannot be used. [threads] is how many processor cores to use; 0 lets
  /// the runtime choose.
  Future<void> load(
    String path, {
    AssistDevice device = AssistDevice.cpu,
    int contextSize = 4096,
    int threads = 0,
  });

  /// What is actually running the model, in the runtime's own words (for
  /// example "CPU" or "Vulkan").
  Future<String> backendName();

  /// Answers [messages], piece by piece. [maxTokens] caps the answer's
  /// length; a [temperature] of 0 gives the same answer every time.
  Stream<AssistChunk> generate(
    List<AssistMessage> messages, {
    int maxTokens = 512,
    double temperature = 0,
  });

  /// The runtime's counters for the answer that just finished, or null when
  /// it keeps none.
  Future<AssistPerf?> lastPerformance();

  /// How many tokens [text] is for the loaded model, or null when the runtime
  /// cannot say.
  Future<int?> countTokens(String text);

  /// One search vector per text of [texts], in order, each of length 1.
  /// Texts that mean alike get vectors that point alike. Only a search
  /// model can do this; a chat model throws.
  Future<List<List<double>>> embed(List<String> texts);

  /// Stops the answer being written. The stream then ends normally.
  void cancel();

  /// Unloads the model and frees its memory.
  Future<void> dispose();
}
