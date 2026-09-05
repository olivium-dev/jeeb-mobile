import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/dio_chat_conversations_repository.dart';
import 'data/shared_prefs_chat_outbox.dart';
import 'domain/chat_conversation_summary.dart';
import 'domain/chat_outbox.dart';

/// Chat's own registrations. Called from the composition root in Stage 2; the
/// screens keep an `isRegistered`-guarded seam until then.
void registerChatDependencies(GetIt getIt) {
  if (!getIt.isRegistered<ChatConversationsRepository>()) {
    getIt.registerLazySingleton<ChatConversationsRepository>(
      () => DioChatConversationsRepository(getIt<Dio>()),
    );
  }
  if (!getIt.isRegistered<ChatOutbox>()) {
    getIt.registerLazySingleton<ChatOutbox>(
      () => SharedPrefsChatOutbox(prefs: getIt<SharedPreferences>()),
    );
  }
}
