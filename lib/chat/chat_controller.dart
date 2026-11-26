import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../app/assist_settings.dart';
import '../lab/model_store.dart';
import '../models/assist_models.dart';
import 'assistant.dart';
import 'chat_store.dart';
import 'conversation.dart';
import 'prompt.dart';

/// What the assistant is doing for the open conversation.
enum ChatPhase {
  /// Waiting for the user.
  idle,

  /// Bringing the model into memory, before the first answer.
  loadingModel,

  /// Writing an answer.
  answering,
}

/// What went wrong with the last message.
enum ChatProblem {
  /// The chosen model is not on the phone (deleted, or never downloaded).
  modelMissing,

  /// The model did not load.
  loadFailed,

  /// The model stopped in the middle of an answer.
  answerFailed,

  /// The conversation could not be saved.
  saveFailed,
}

class ChatState {
  const ChatState({
    this.conversation,
    this.phase = ChatPhase.idle,
    this.partial = '',
    this.problem,
    this.problemDetail,
  });

  /// The open conversation, or null for a new one nothing was written in.
  final Conversation? conversation;
  final ChatPhase phase;

  /// The answer being written, so far.
  final String partial;
  final ChatProblem? problem;

  /// The engine's own words for [problem], for the phone test's owner.
  final String? problemDetail;

  bool get busy => phase != ChatPhase.idle;

  List<ChatMessage> get messages => conversation?.messages ?? const [];
}

/// Runs the open conversation: sends a message, shows the answer as it is
/// written and saves both.
class ChatController extends Notifier<ChatState> {
  /// Rises whenever the conversation on screen is replaced, so an answer
  /// still arriving for the old one is dropped.
  int _generation = 0;
  bool _stopRequested = false;
  bool _sending = false;

  @override
  ChatState build() {
    // A locked app shows nothing, and the model's memory is given back.
    ref.listen(vaultControllerProvider, (_, VaultState next) {
      if (next is VaultLocked) {
        _replace(const ChatState());
        unawaited(ref.read(assistantProvider).unload());
      }
    });
    return const ChatState();
  }

  void _replace(ChatState next) {
    if (state.busy) ref.read(assistantProvider).cancel();
    _generation++;
    state = next;
  }

  /// Shows [conversation].
  void open(Conversation conversation) =>
      _replace(ChatState(conversation: conversation));

  /// Shows an empty conversation.
  void newChat() => _replace(const ChatState());

  /// Stops the answer being written and keeps what there is of it.
  void stop() {
    if (!state.busy) return;
    _stopRequested = true;
    ref.read(assistantProvider).cancel();
  }

  void clearProblem() {
    if (state.problem == null) return;
    state = ChatState(conversation: state.conversation);
  }

  /// The file of the model to chat with, or null when it is not on the phone.
  Future<String?> _modelPath() async {
    final chosen = chatModelById(await ref.read(chosenModelProvider.future));
    if (chosen == null) return null;
    final store = ref.read(modelStoreProvider);
    var model = store.stateOf(chosen);
    if (model.stage == ModelStage.missing) {
      await store.refresh();
      model = store.stateOf(chosen);
    }
    return model.stage == ModelStage.ready ? model.path : null;
  }

  Future<bool> _save(Conversation conversation) async {
    try {
      await ref.read(chatRepositoryProvider).save(conversation);
      return true;
    } on Object {
      return false;
    }
  }

  /// Adds [text] to the conversation and writes the model's answer.
  Future<void> send(String text) async {
    final message = text.trim();
    // One message at a time: a second one sent before the first is on
    // screen (a double tap) is dropped, not answered out of order.
    if (message.isEmpty || state.busy || _sending) return;
    _sending = true;
    try {
      await _send(message);
    } finally {
      _sending = false;
    }
  }

  Future<void> _send(String message) async {
    final path = await _modelPath();
    if (path == null) {
      state = ChatState(
        conversation: state.conversation,
        problem: ChatProblem.modelMissing,
      );
      return;
    }

    final repository = ref.read(chatRepositoryProvider);
    var conversation =
        (state.conversation ??
                Conversation.start(repository.newId(), DateTime.now()))
            .withMessage(
              ChatMessage(
                role: ChatRole.user,
                text: message,
                at: DateTime.now(),
              ),
            );
    final generation = ++_generation;
    _stopRequested = false;
    state = ChatState(
      conversation: conversation,
      phase: ChatPhase.loadingModel,
    );
    // Saved before the answer, so the question survives whatever happens.
    var saved = await _save(conversation);
    if (generation != _generation) return;

    final assistant = ref.read(assistantProvider);
    final device = ref.read(deviceInfoProvider);
    // An answer can take a minute; the screen must not switch off and lock
    // the app in the middle of it.
    unawaited(device.keepAwake(true));
    final answer = StringBuffer();
    ChatProblem? problem;
    String? detail;
    try {
      try {
        await assistant.ensureLoaded(path, contextSize: contextTokens);
      } on Object catch (error) {
        problem = ChatProblem.loadFailed;
        detail = error.toString();
      }
      if (problem == null && generation == _generation) {
        state = ChatState(
          conversation: conversation,
          phase: ChatPhase.answering,
        );
        try {
          final pieces = assistant.answer(
            buildPrompt(conversation, DateTime.now()),
            maxTokens: answerTokens,
          );
          var touched = DateTime.now();
          await for (final piece in pieces) {
            if (generation != _generation) break;
            // Reading an answer as it is written is use of the app: a long
            // answer must not end with the app locking itself.
            final now = DateTime.now();
            if (now.difference(touched) >= const Duration(seconds: 5)) {
              touched = now;
              ref.read(vaultControllerProvider.notifier).touch();
            }
            if (piece.text.isEmpty) continue;
            answer.write(piece.text);
            state = ChatState(
              conversation: conversation,
              phase: ChatPhase.answering,
              partial: answer.toString(),
            );
          }
        } on Object catch (error) {
          problem = ChatProblem.answerFailed;
          detail = error.toString();
        }
      }
    } finally {
      unawaited(device.keepAwake(false));
    }
    // Another conversation is on screen by now: this answer has no place.
    if (generation != _generation) return;

    final written = answer.toString().trim();
    if (written.isNotEmpty) {
      conversation = conversation.withMessage(
        ChatMessage(
          role: ChatRole.assistant,
          text: written,
          at: DateTime.now(),
          stopped: _stopRequested || problem != null,
        ),
      );
      saved = await _save(conversation) && saved;
      if (generation != _generation) return;
    }
    if (problem == null && !saved) problem = ChatProblem.saveFailed;
    state = ChatState(
      conversation: conversation,
      problem: problem,
      problemDetail: detail,
    );
  }

  /// Gives the open conversation the name [title].
  Future<void> rename(Conversation conversation, String title) async {
    final renamed = conversation.renamed(title);
    if (renamed.title.isEmpty) return;
    await ref.read(chatRepositoryProvider).save(renamed);
    if (state.conversation?.id == renamed.id && !state.busy) {
      state = ChatState(conversation: renamed);
    }
  }

  /// Deletes [conversation] on every device.
  Future<void> delete(Conversation conversation) async {
    if (state.conversation?.id == conversation.id) newChat();
    await ref.read(chatRepositoryProvider).delete(conversation.id);
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(
  ChatController.new,
);
