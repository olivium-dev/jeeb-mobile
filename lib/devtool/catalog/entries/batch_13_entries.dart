import 'package:flutter/material.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../features/chat/data/dev_chat_fixture_gateway.dart';
import '../../../features/chat/domain/delivery_chat_message.dart';
import '../../../features/chat/domain/order_chat_summary.dart';
import '../../../features/deep_link_targets/chat_detail_screen.dart';
import '../../../features/registration/data/super_login_demo_user.dart';
import '../../../features/registration/data/super_login_service.dart';
import '../../../features/registration/presentation/super_login/super_login_cubit.dart';
import '../../../features/registration/presentation/super_login/super_login_picker.dart';
import '../../../features/registration/presentation/super_login/super_login_sheet.dart';
import '../catalog_models.dart';

/// Batch 13 — remaining screens skipped in the first catalog pass:
///
///   * `deep_link_targets` / [ChatDetailScreen] — previously skipped (see
///     `batch_02_entries.dart`'s note) because it resolved its gateway off
///     global `GetIt`/`DevSeam` with no constructor seam. This batch adds a
///     MINIMAL, ADDITIVE debug seam directly on the product screen
///     (`ChatDetailScreen.debugGateway` + friends, defaulting to `null`) —
///     see `chat_detail_screen.dart` for the seam and its call-site note.
///   * `registration` / the "Super user login plus" surfaces
///     ([showSuperLoginSheet], [showSuperLoginPicker]) — modal-bottom-sheet
///     launchers whose body widgets are private to their files, so (mirroring
///     the established `_ProhibitedAcknowledgmentPreview` pattern in
///     `batch_08_entries.dart`) each state opens the REAL sheet/picker right
///     after the first frame via a thin preview host.
///
/// `request_type` has no further screens/states to add here: `RequestTypeScreen`
/// is already fully cataloged in `batch_09_entries.dart` (Loaded + Eco
/// selected). The only uncataloged lifecycle value,
/// `TierSelectionState.usingCachedFallback`, is never read by
/// `RequestTypeScreen`'s widget tree (grep confirms no reference), so it is
/// not a visually distinct DESIGNED state — nothing to skip or add.
List<CatalogEntry> get batch13Entries => <CatalogEntry>[
      const CatalogEntry(
        feature: 'deep_link_targets',
        screen: 'ChatDetailScreen',
        states: [
          CatalogState('Compose — broadcasting (client)', _chatDetailCompose),
          CatalogState(
            'Accepted — pinned summary (client)',
            _chatDetailAccepted,
          ),
        ],
      ),
      const CatalogEntry(
        feature: 'registration',
        screen: 'SuperLoginSheet',
        states: [
          CatalogState(
            'Prefilled from demo picker',
            _superLoginSheetPrefilled,
          ),
          CatalogState('Invalid credentials error', _superLoginSheetError),
        ],
      ),
      const CatalogEntry(
        feature: 'registration',
        screen: 'SuperLoginPicker',
        states: [
          CatalogState('Loaded — demo roster', _superLoginPickerLoaded),
          CatalogState('Load error', _superLoginPickerError),
        ],
      ),
    ];

// ---------------------------------------------------------------------------
// deep_link_targets — ChatDetailScreen
// ---------------------------------------------------------------------------

Widget _chatDetailCompose(BuildContext _) => ChatDetailScreen(
      chatId: 'demo-compose-001',
      debugGateway: DevChatFixtureGateway(phase: ConversationPhase.broadcasting),
      debugPhase: ConversationPhase.broadcasting,
    );

Widget _chatDetailAccepted(BuildContext _) => ChatDetailScreen(
      chatId: 'demo-accepted-001',
      debugGateway: DevChatFixtureGateway(phase: ConversationPhase.accepted),
      debugCounterpartName: 'Kamal Hajj',
      debugPhase: ConversationPhase.accepted,
      debugHasWinner: true,
      debugSummary: const OrderChatSummary(
        deliveryId: 'demo-accepted-001',
        requestId: 'demo-accepted-001',
        priceLabel: r'$20.00',
        jeeberName: 'Kamal Hajj',
        rating: 4.8,
        etaMinutes: 180,
        tierId: 'standard',
        orderRef: 'ORD-1042',
      ),
    );

// ---------------------------------------------------------------------------
// registration — Super user login plus (sheet + picker)
// ---------------------------------------------------------------------------

/// Debug-only fixed-result [SuperLoginService] — never touches the network.
class _FakeSuperLoginService implements SuperLoginService {
  const _FakeSuperLoginService(this._result);
  final SuperLoginResult _result;

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async =>
      _result;
}

/// Debug-only fixed-roster [SuperLoginDemoUserService] — never touches the
/// network.
class _FakeSuperLoginDemoUserService implements SuperLoginDemoUserService {
  const _FakeSuperLoginDemoUserService(this._users);
  final List<SuperLoginDemoUser> _users;

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async => _users;
}

/// Debug-only always-failing [SuperLoginDemoUserService], for the picker's
/// error + Retry state.
class _ThrowingSuperLoginDemoUserService implements SuperLoginDemoUserService {
  const _ThrowingSuperLoginDemoUserService();

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async =>
      throw const SuperLoginDemoUserException(SuperLoginDemoUserError.network);
}

/// Hosts the real [showSuperLoginSheet] (its form body is private to its
/// file), opening it right after the first frame — mirrors the
/// `_ProhibitedAcknowledgmentPreview` pattern in `batch_08_entries.dart`.
///
/// When [autoSubmit] is true, the built cubit's `submit` is awaited BEFORE
/// the sheet opens so it mounts already in the resulting (e.g. error) state,
/// using [service] to resolve that submit with no network.
class _SuperLoginSheetPreview extends StatefulWidget {
  const _SuperLoginSheetPreview({
    required this.service,
    this.initialUserId,
    this.initialPasscode,
    this.autoSubmit = false,
  });

  final SuperLoginService service;
  final String? initialUserId;
  final String? initialPasscode;
  final bool autoSubmit;

  @override
  State<_SuperLoginSheetPreview> createState() =>
      _SuperLoginSheetPreviewState();
}

class _SuperLoginSheetPreviewState extends State<_SuperLoginSheetPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    // AuthTokenStore is only ever touched by `submit`'s SUCCESS branch, which
    // no state here reaches (prefilled-idle never submits; the error state's
    // fake service resolves to a failure) — safe to construct without a
    // platform-channel round trip.
    final cubit = SuperLoginCubit(
      service: widget.service,
      tokenStore: AuthTokenStore(),
    );
    if (widget.autoSubmit) {
      await cubit.submit(
        userId: widget.initialUserId ?? '',
        passcode: widget.initialPasscode ?? '',
      );
      if (!mounted) return;
    }
    await showSuperLoginSheet(
      context,
      cubit: cubit,
      initialUserId: widget.initialUserId,
      initialPasscode: widget.initialPasscode,
    );
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.expand());
}

/// Hosts the real [showSuperLoginPicker] (its list body is private to its
/// file), opening it right after the first frame.
class _SuperLoginPickerPreview extends StatefulWidget {
  const _SuperLoginPickerPreview({required this.service});

  final SuperLoginDemoUserService service;

  @override
  State<_SuperLoginPickerPreview> createState() =>
      _SuperLoginPickerPreviewState();
}

class _SuperLoginPickerPreviewState extends State<_SuperLoginPickerPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSuperLoginPicker(context, service: widget.service);
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.expand());
}

const List<SuperLoginDemoUser> _demoRoster = [
  SuperLoginDemoUser(
    userId: 'a3f1e2d4-nour-demo',
    name: 'Nour Khalil',
    role: 'client',
    passcode: 'demo-nour',
  ),
  SuperLoginDemoUser(
    userId: 'b7c9a0e6-kamal-demo',
    name: 'Kamal Hajj',
    role: 'jeeber',
    passcode: 'demo-kamal',
  ),
];

Widget _superLoginSheetPrefilled(BuildContext _) => _SuperLoginSheetPreview(
      service: const _FakeSuperLoginService(
        SuperLoginFailure(SuperLoginError.unknown),
      ),
      initialUserId: _demoRoster.first.userId,
      initialPasscode: _demoRoster.first.passcode,
    );

Widget _superLoginSheetError(BuildContext _) => _SuperLoginSheetPreview(
      service: const _FakeSuperLoginService(
        SuperLoginFailure(SuperLoginError.invalidCredentials),
      ),
      initialUserId: _demoRoster.last.userId,
      initialPasscode: 'wrong-passcode',
      autoSubmit: true,
    );

Widget _superLoginPickerLoaded(BuildContext _) => const _SuperLoginPickerPreview(
      service: _FakeSuperLoginDemoUserService(_demoRoster),
    );

Widget _superLoginPickerError(BuildContext _) => const _SuperLoginPickerPreview(
      service: _ThrowingSuperLoginDemoUserService(),
    );
