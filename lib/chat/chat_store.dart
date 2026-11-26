import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'conversation.dart';

/// Conversations are items of the Assist app, sealed with its own key
/// (`app = 'assist'`, `kind` chat). They are encrypted on the phone before
/// they are stored or synced, like notes. No database change.
final conversationsCollection = ZtCollection<Conversation>(
  kind: 'chat',
  fromJson: Conversation.fromJson,
  toJson: (conversation) => conversation.toJson(),
  idOf: (conversation) => conversation.id,
);

/// Newest change first.
int compareConversations(Conversation a, Conversation b) =>
    b.updatedAt.compareTo(a.updatedAt);

/// Every conversation of the account, newest change first.
final conversationsProvider = StreamProvider<List<Conversation>>((ref) async* {
  final store = await ref.watch(ztLocalStoreProvider.future);
  if (store is ZtLocalStore) {
    yield* conversationsCollection
        .watch(store)
        .map((list) => [...list]..sort(compareConversations));
  } else {
    yield (await conversationsCollection.list(store))
      ..sort(compareConversations);
  }
});

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref),
);

/// Saves and deletes through the shared sync controller, so every change is
/// encrypted, stored locally and sent to the account's other devices.
class ChatRepository {
  ChatRepository(this._ref);
  final Ref _ref;

  static const _uuid = Uuid();
  String newId() => _uuid.v4();

  SyncController get _sync => _ref.read(ztSyncControllerProvider.notifier);
  Future<LocalItemStore> get _store => _ref.read(ztLocalStoreProvider.future);

  Future<void> save(Conversation conversation) async =>
      conversationsCollection.save(_sync, await _store, conversation);

  Future<void> delete(String id) => conversationsCollection.delete(_sync, id);
}
