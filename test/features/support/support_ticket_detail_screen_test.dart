import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/case_evidence/domain/case_evidence.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_detail_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  Future<void> pump(WidgetTester tester, SupportRepository repository) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: const Locale('en'),
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
        home: SupportTicketDetailScreen(
          ticketId: 'ticket-1',
          repository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders status, replies, attachments, and partial marker', (
    tester,
  ) async {
    await pump(
      tester,
      const _ThreadRepository(
        ticket: SupportTicket(
          id: 'ticket-1',
          ticketNumber: 'SUP-100',
          status: 'fixed',
          version: 4,
          body: 'My delivery arrived damaged.',
          isPartial: true,
          attachments: <SupportAttachment>[
            SupportAttachment(
              id: 'att-1',
              kind: 'photo',
              status: 'failed',
              fileName: 'damage.jpg',
            ),
          ],
          replies: <SupportReply>[
            SupportReply(
              id: 'reply-1',
              body: 'We corrected the issue.',
              authorRole: 'support',
              createdAt: '2026-08-05T10:00:00Z',
            ),
          ],
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('support_thread_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_thread_status'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('support_thread_partial_evidence'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('support_reply_reply-1'), findsOneWidget);
    expect(find.text('Attachment unavailable'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('support_reply_composer'),
      findsOneWidget,
    );
  });

  testWidgets(
    'empty pending thread has an accessible empty state and composer',
    (tester) async {
      await pump(
        tester,
        const _ThreadRepository(
          ticket: SupportTicket(
            id: 'ticket-1',
            status: 'pending',
            body: 'Please help.',
          ),
        ),
      );

      expect(
        find.bySemanticsIdentifier('support_thread_empty'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('support_reply_composer'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('support_reply_send'), findsOneWidget);
    },
  );

  testWidgets('closed thread is read-only and exposes no close control', (
    tester,
  ) async {
    await pump(
      tester,
      const _ThreadRepository(
        ticket: SupportTicket(
          id: 'ticket-1',
          status: 'closed',
          body: 'Original request',
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('support_thread_closed'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_reply_composer'), findsNothing);
    expect(find.bySemanticsIdentifier('support_reply_send'), findsNothing);
    expect(find.textContaining('Close ticket'), findsNothing);
  });

  testWidgets('offline load exposes an error state and retry action', (
    tester,
  ) async {
    // R6: only a real transport gap claims "offline" — the id follows the
    // classified failure, not the feature enum.
    await pump(
      tester,
      const _ThreadRepository(
        failure: SupportFailure.network,
        appFailure: NetworkFailure(offline: true),
      ),
    );

    expect(
      find.bySemanticsIdentifier('support_thread_offline'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('support_thread_retry_cta'),
      findsOneWidget,
    );
  });

  testWidgets('a not-found thread gets the way out, never an inert Retry', (
    tester,
  ) async {
    await pump(
      tester,
      const _ThreadRepository(
        failure: SupportFailure.notFound,
        appFailure: NotFoundFailure(),
      ),
    );

    expect(find.bySemanticsIdentifier('support_thread_error'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('support_thread_exit_cta'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('support_thread_retry_cta'),
      findsNothing,
    );
  });

  testWidgets('stale-version conflict visibly restores the reply draft', (
    tester,
  ) async {
    await pump(tester, _ConflictRepository());
    final fieldFinder = find.descendant(
      of: find.bySemanticsIdentifier('support_reply_composer'),
      matching: find.byType(EditableText),
    );
    await tester.enterText(fieldFinder, 'The issue is still happening.');
    await tester.pump();
    await tester.tap(find.bySemanticsIdentifier('support_reply_send'));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('support_thread_conflict'),
      findsOneWidget,
    );
    final field = tester.widget<EditableText>(fieldFinder);
    expect(field.controller.text, 'The issue is still happening.');
  });
}

class _ThreadRepository implements SupportRepository, SupportThreadRepository {
  const _ThreadRepository({this.ticket, this.failure, this.appFailure});

  final SupportTicket? ticket;
  final SupportFailure? failure;
  final AppFailure? appFailure;

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async {
    final value = failure;
    if (value != null) {
      throw SupportRepositoryException.classified(
        value,
        appFailure: appFailure ?? const UnknownFailure(),
      );
    }
    return ticket!;
  }

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    return ticket!;
  }

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    return ticket!;
  }
}

class _ConflictRepository
    implements SupportRepository, SupportThreadRepository {
  static const ticket = SupportTicket(
    id: 'ticket-1',
    status: 'pending',
    version: 1,
    body: 'Original request',
  );

  @override
  Future<SupportTicket> fetchTicket(String ticketId) async => ticket;

  @override
  Future<SupportTicket> replyToTicket(
    String ticketId,
    SupportReplyDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) {
    throw const SupportRepositoryException(
      SupportFailure.conflict,
      'stale',
      SupportTicket(
        id: 'ticket-1',
        status: 'pending',
        version: 2,
        body: 'Original request',
      ),
    );
  }

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async => ticket;
}
