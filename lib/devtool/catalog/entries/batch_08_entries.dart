import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/password_security/application/password_security_cubit.dart';
import '../../../features/password_security/presentation/password_security_screen.dart';
import '../../../features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import '../../../features/prohibited_acknowledgment/domain/prohibited_item.dart';
import '../../../features/prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart';
import '../../../features/prohibited_item_report/presentation/prohibited_item_report_screen.dart';
import '../../../features/rating/application/mutual_rating_cubit.dart';
import '../../../features/rating/domain/entities/rating_status.dart';
import '../../../features/rating/domain/rating_repository.dart';
import '../../../features/rating/presentation/mutual_rating_screen.dart';
import '../../../features/rating/presentation/rating_screen.dart';
import '../catalog_models.dart';

/// Batch 08 — password_security, photo_attachment, prohibited_acknowledgment,
/// prohibited_item_report, rate_app, rating.
///
/// SKIPPED (see manifest, not represented below):
///   * `photo_attachment` — no `presentation/` screen; pure domain/service
///     module (photo picker abstraction consumed by other features' screens).
///   * `rate_app` — no `presentation/` screen; a native in-app-review launcher
///     (platform channel), no Flutter UI to render.
List<CatalogEntry> get batch08Entries => <CatalogEntry>[
      const CatalogEntry(
        feature: 'password_security',
        screen: 'PasswordSecurityScreen',
        states: [
          CatalogState('Change form (has password)', _passwordChangeForm),
          CatalogState('Social-only (no password)', _passwordSocialOnly),
          CatalogState('Mismatch error', _passwordMismatchError),
          CatalogState('Strength error', _passwordStrengthError),
        ],
      ),
      CatalogEntry(
        feature: 'prohibited_acknowledgment',
        screen: 'ProhibitedAcknowledgmentDialog',
        states: [
          CatalogState(
            'Loaded (block + warn items)',
            (_) => const _ProhibitedAcknowledgmentPreview(
              repository: _LoadedProhibitedRepository(),
            ),
          ),
          CatalogState(
            'Error (fetch failed)',
            (_) => const _ProhibitedAcknowledgmentPreview(
              repository: _ErrorProhibitedRepository(),
            ),
          ),
        ],
      ),
      const CatalogEntry(
        feature: 'prohibited_item_report',
        screen: 'ProhibitedItemReportScreen',
        states: [
          CatalogState('Report form', _prohibitedItemReportForm),
        ],
      ),
      const CatalogEntry(
        feature: 'rating',
        screen: 'RatingScreen',
        states: [
          CatalogState('Client rating Jeeber', _ratingClientRatesJeeber),
          CatalogState('Jeeber rating client', _ratingJeeberRatesClient),
        ],
      ),
      const CatalogEntry(
        feature: 'rating',
        screen: 'MutualRatingScreen',
        states: [
          CatalogState('Inputting (empty)', _mutualRatingInputting),
          CatalogState(
            'Filled (stars + comment + tags)',
            _mutualRatingFilled,
          ),
          CatalogState('Error (submit failed)', _mutualRatingError),
        ],
      ),
    ];

// ---------------------------------------------------------------------------
// password_security
// ---------------------------------------------------------------------------

Widget _passwordChangeForm(BuildContext _) =>
    const PasswordSecurityScreen(hasPassword: true);

Widget _passwordSocialOnly(BuildContext _) =>
    const PasswordSecurityScreen(hasPassword: false);

Widget _passwordMismatchError(BuildContext _) => PasswordSecurityScreen(
      cubitFactory: () => PasswordSecurityCubit()
        ..submit(
          current: 'OldPass1',
          newPassword: 'NewPass12',
          confirm: 'Mismatch12',
        ),
    );

Widget _passwordStrengthError(BuildContext _) => PasswordSecurityScreen(
      cubitFactory: () => PasswordSecurityCubit()
        ..submit(current: 'OldPass1', newPassword: 'weak', confirm: 'weak'),
    );

// ---------------------------------------------------------------------------
// prohibited_acknowledgment
// ---------------------------------------------------------------------------

/// Hosts the real [showProhibitedAcknowledgmentDialog] (the dialog's own view
/// widget is private to its file), opening it right after the first frame so
/// the catalog preview shows the actual designed dialog with no network.
class _ProhibitedAcknowledgmentPreview extends StatefulWidget {
  const _ProhibitedAcknowledgmentPreview({required this.repository});

  final ProhibitedAcknowledgmentRepository repository;

  @override
  State<_ProhibitedAcknowledgmentPreview> createState() =>
      _ProhibitedAcknowledgmentPreviewState();
}

class _ProhibitedAcknowledgmentPreviewState
    extends State<_ProhibitedAcknowledgmentPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showProhibitedAcknowledgmentDialog(
        context,
        repository: widget.repository,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SizedBox.expand(),
      );
}

class _LoadedProhibitedRepository
    implements ProhibitedAcknowledgmentRepository {
  const _LoadedProhibitedRepository();

  @override
  Future<List<ProhibitedItem>> fetchItems() async => const [
        ProhibitedItem(id: 'p1', name: 'Firearms & ammunition'),
        ProhibitedItem(
          id: 'p2',
          name: 'Perishable food without cold packaging',
          severity: ProhibitedItemSeverity.warn,
        ),
        ProhibitedItem(id: 'p3', name: 'Hazardous chemicals'),
      ];

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}

class _ErrorProhibitedRepository
    implements ProhibitedAcknowledgmentRepository {
  const _ErrorProhibitedRepository();

  @override
  Future<List<ProhibitedItem>> fetchItems() async =>
      throw Exception('demo: prohibited-items fetch failed');

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}

// ---------------------------------------------------------------------------
// prohibited_item_report
// ---------------------------------------------------------------------------

Widget _prohibitedItemReportForm(BuildContext _) =>
    const ProhibitedItemReportScreen(requestId: 'demo-request-001');

// ---------------------------------------------------------------------------
// rating — RatingScreen
// ---------------------------------------------------------------------------

Widget _ratingClientRatesJeeber(BuildContext _) => const RatingScreen(
      deliveryId: 'demo-delivery-101',
      isClient: true,
      rateeName: 'Ahmed Youssef',
      repository: _FakeRatingRepository(),
    );

Widget _ratingJeeberRatesClient(BuildContext _) => const RatingScreen(
      deliveryId: 'demo-delivery-102',
      isClient: false,
      rateeName: 'Sara Ali',
      repository: _FakeRatingRepository(),
    );

class _FakeRatingRepository implements RatingRepository {
  const _FakeRatingRepository();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// rating — MutualRatingScreen
// ---------------------------------------------------------------------------

Widget _mutualRatingInputting(BuildContext _) => BlocProvider<MutualRatingCubit>(
      create: (_) => MutualRatingCubit(
        repository: const _FakeRatingRepository(),
        deliveryId: 'demo-delivery-201',
        isClient: true,
      ),
      child: const MutualRatingScreen(),
    );

Widget _mutualRatingFilled(BuildContext _) => BlocProvider<MutualRatingCubit>(
      create: (_) => MutualRatingCubit(
        repository: const _FakeRatingRepository(),
        deliveryId: 'demo-delivery-202',
        isClient: false,
      )
        ..setStars(4)
        ..setComment('Great delivery, very professional!')
        ..toggleTag('Punctual')
        ..toggleTag('Friendly'),
      child: const MutualRatingScreen(),
    );

Widget _mutualRatingError(BuildContext _) => BlocProvider<MutualRatingCubit>(
      create: (_) => MutualRatingCubit(
        repository: const _ThrowingRatingRepository(),
        deliveryId: 'demo-delivery-203',
        isClient: true,
      )
        ..setStars(5)
        ..submit(),
      child: const MutualRatingScreen(),
    );

class _ThrowingRatingRepository implements RatingRepository {
  const _ThrowingRatingRepository();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    throw const RatingRepositoryException(RatingFailure.network);
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      throw UnimplementedError();
}
