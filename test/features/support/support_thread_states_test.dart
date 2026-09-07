// WP7-N5 / EP-14 / TEST-15: the thread's four rungs, a refresh that keeps the
// messages, and a pagination failure that offers a real retry.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const SupportTicket _ticket = SupportTicket(
  id: 'ticket-1',
  status: 'pending',
  version: 1,
  body: 'My delivery never arrived.',
);

/// First read lands, every read after it fails — the warm-failure lane.
class _RefreshFailingRepo
    implements SupportRepository, SupportThreadRepository {
  int fetches = 0;

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async {
    fetches += 1;
    if (fetches == 1) return _ticket;
    throw const SupportRepositoryException.classified(
      SupportFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async => _ticket;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async => _ticket;
}

/// Paginated thread whose second page always fails.
class _PaginationFailingRepo
    implements
        SupportRepository,
        SupportThreadRepository,
        PaginatedSupportThreadRepository {
  int loadMoreCalls = 0;

  @override
  Future<SupportThreadPage> fetchInitialThread(
    String ticketId, {
    int limit = 20,
  }) async => const SupportThreadPage(ticket: _ticket, nextCursor: 'page-2');

  @override
  Future<SupportThreadPage> fetchMessages(
    String ticketId, {
    String? cursor,
    int limit = 20,
    String? initialRequestBody,
  }) async {
    loadMoreCalls += 1;
    throw const SupportRepositoryException.classified(
      SupportFailure.unknown,
      appFailure: ServerFailure(status: 500),
    );
  }

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async => _ticket;

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async => _ticket;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async => _ticket;
}

void main() {
  Widget harness(
    SupportRepository repo, {
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: SupportTicketDetailScreen(ticketId: 'ticket-1', repository: repo),
  );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a failed refresh keeps the thread mounted (WP7-N5)', (
      tester,
    ) async {
      useReduceMotion(tester);
      final repo = _RefreshFailingRepo();
      await tester.pumpWidget(harness(repo, locale: locale));
      await tester.pumpAndSettle();

      expect(byId('support_thread_request'), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
      await tester.pumpAndSettle();

      expect(repo.fetches, greaterThan(1));
      // The phase never returns to loading, so the messages stay.
      expect(byId('support_thread_request'), findsOneWidget);
      expect(byId('support_thread_loading'), findsNothing);
      expect(byId('support_thread_error'), findsNothing);
      expect(byId('support_thread_refresh_error'), findsOneWidget);
    });
  }

  testWidgets('the refresh strip dismisses', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(harness(_RefreshFailingRepo()));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
    await tester.pumpAndSettle();

    await tester.tap(byId('support_thread_refresh_error_dismiss_cta'));
    await tester.pumpAndSettle();
    expect(byId('support_thread_refresh_error'), findsNothing);
  });

  testWidgets('an empty thread draws the empty rung and the load-more id', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(harness(_PaginationFailingRepo()));
    await tester.pumpAndSettle();

    expect(byId('support_thread_empty'), findsOneWidget);
    expect(byId('support_thread_load_more'), findsOneWidget);
  });

  testWidgets('a pagination failure offers a retry that re-invokes loadMore', (
    tester,
  ) async {
    useReduceMotion(tester);
    final repo = _PaginationFailingRepo();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await tester.tap(byId('support_thread_load_more'));
    await tester.pumpAndSettle();

    expect(repo.loadMoreCalls, 1);
    expect(byId('support_thread_pagination_error'), findsOneWidget);
    // EP-14: the note used to be a dead end.
    expect(byId('support_thread_pagination_retry'), findsOneWidget);

    await tester.tap(byId('support_thread_pagination_retry'));
    await tester.pumpAndSettle();
    expect(repo.loadMoreCalls, 2);
  });
}
