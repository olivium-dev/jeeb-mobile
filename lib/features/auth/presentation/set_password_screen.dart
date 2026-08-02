import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../l10n/app_localizations.dart';
import '../application/set_password_cubit.dart';
import '../application/set_password_state.dart';
import '../data/dio_auth_repository.dart';
import '../domain/auth_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/set_password_screen_fixtures.dart';

/// The exit of the set-password screen (JM-061 password-security, D90).
///   * [inAppSocial] — reached from password-security for a social-only account;
///                     on success → customer-profile.
///
/// The former `recovery` mode (reached from the hidden email/password recovery
/// funnel) was removed with that funnel (JEBV4-199, Q-044): the only end-user
/// auth surfaces are phone-OTP + Apple/Google social, so there is no email
/// recovery flow to land here anymore. This screen now serves ONLY the
/// authenticated password-security settings path.
enum SetPasswordMode {
  inAppSocial;

  /// Parses the `?mode=` query param. Always resolves to [inAppSocial] — the
  /// single surviving mode — regardless of the (now legacy) value (R-F).
  static SetPasswordMode fromQuery(String? value) => SetPasswordMode.inAppSocial;
}

/// `auth-set-password` (JM-022, JM-061). In-app-social set-password screen
/// (`?mode=in-app-social`, D90). New + confirm password fields with
/// strength/mismatch validation and per-field eye toggles.
///
/// Data flows through [AuthRepository.setPassword] → `POST /v1/auth/set-password`
/// (the VERIFIED W-1 FLOOR contract, 42_GUARDRAILS_MOCK). On success it lands on
/// customer-profile (`customer-profile` route, customer_profile_wallet_chip)
/// [D90, JM-035].
///
/// Reached ONLY from password-security (a social-only account adding a password
/// from settings). The former recovery entry (email/password recovery funnel)
/// was removed in JEBV4-199; `email`/`resetToken` stay as optional inputs the
/// authenticated caller may forward but are not required in-app-social.
class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({
    super.key,
    this.mode = SetPasswordMode.inAppSocial,
    this.email = '',
    this.resetToken,
    this.cubitFactory,
  });

  final SetPasswordMode mode;

  /// The account email the password is being set for. Carried from the
  /// recovery verify step (JM-021); empty for the seam capture path.
  final String email;

  /// The recovery reset token (recovery mode). Optional for in-app-social.
  final String? resetToken;

  /// Test seam: overrides the DI-backed cubit construction
  /// (40_GUARDRAILS_ARCH §5.4).
  final SetPasswordCubit Function()? cubitFactory;

  /// The production [AuthRepository] from DI. Falls back to a freshly
  /// constructed Dio-backed impl when GetIt is not configured (e.g. the
  /// integrator's `w0_routes_resolve_test.dart`, which mounts the route table
  /// without `configureDependencies()`), mirroring `login_screen.dart`'s
  /// `_resolveAuthRepository()`. The Dio + token store are cheap to construct
  /// and never touched until a submit fires.
  AuthRepository _resolveAuthRepository() {
    if (sl.isRegistered<AuthRepository>()) return sl<AuthRepository>();
    return DioAuthRepository(resolveGatewayDio(), AuthTokenStore());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SetPasswordCubit>(
      create: (_) =>
          cubitFactory?.call() ??
          SetPasswordCubit(
            repository: _resolveAuthRepository(),
            email: email,
            resetToken: resetToken,
          ),
      child: _SetPasswordView(mode: mode),
    );
  }
}

class _SetPasswordView extends StatefulWidget {
  const _SetPasswordView({required this.mode});

  final SetPasswordMode mode;

  @override
  State<_SetPasswordView> createState() => _SetPasswordViewState();
}

class _SetPasswordViewState extends State<_SetPasswordView> {
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<SetPasswordCubit>().submit(
          newPassword: _newController.text,
          confirmPassword: _confirmController.text,
        );
  }

  /// Routes off the screen on a successful set-password. Runs only in the
  /// `listener` (never the builder), gated by the succeeded edge.
  void _onSucceeded(BuildContext context) {
    // EDGE: set-password (in-app-social) → customer-profile
    // (60_W0_TEST_PLAN nav matrix, JM-022 → JM-035, D90). This is the only
    // surviving exit now that the email recovery funnel is gone (JEBV4-199).
    context.goNamed('customer-profile');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'setpw_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: l10n.setpwTitle, showBackButton: true),
        body: BlocConsumer<SetPasswordCubit, SetPasswordState>(
          listenWhen: (p, n) =>
              p.status != n.status && n.status == SetPasswordStatus.succeeded,
          listener: (context, state) => _onSucceeded(context),
          builder: (context, state) {
            final cubit = context.read<SetPasswordCubit>();
            final submitting = state.status == SetPasswordStatus.submitting;
            return SafeArea(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.medium,
                  Spacing.large,
                  Spacing.medium,
                  Spacing.xLarge,
                ),
                children: [
                  // New password field + its eye toggle.
                  Semantics(
                    identifier: 'setpw_new_field',
                    textField: true,
                    child: OmdsTextField(
                      controller: _newController,
                      labelText: l10n.setpwNewLabel,
                      hintText: l10n.setpwNewHint,
                      obscureText: state.newObscured,
                      autoValidate: false,
                      enabled: !submitting,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => cubit.acknowledgeError(),
                      suffixIcon: Semantics(
                        identifier: 'setpw_new_visibility_toggle',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            state.newObscured
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: cubit.toggleNewObscured,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.medium),
                  // Confirm password field + its eye toggle.
                  Semantics(
                    identifier: 'setpw_confirm_field',
                    textField: true,
                    child: OmdsTextField(
                      controller: _confirmController,
                      labelText: l10n.setpwConfirmLabel,
                      hintText: l10n.setpwConfirmHint,
                      obscureText: state.confirmObscured,
                      autoValidate: false,
                      enabled: !submitting,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => cubit.acknowledgeError(),
                      onSubmitted: (_) => _onSubmit(),
                      suffixIcon: Semantics(
                        identifier: 'setpw_confirm_visibility_toggle',
                        button: true,
                        child: IconButton(
                          icon: Icon(
                            state.confirmObscured
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: cubit.toggleConfirmObscured,
                        ),
                      ),
                    ),
                  ),
                  // Validation / submit error node. Mismatch or weak password
                  // (AC3) and any server failure both surface here so QA has a
                  // single assertable id (60_W0_TEST_PLAN §2.11).
                  if (state.hasError) ...[
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'setpw_validation_error',
                      liveRegion: true,
                      child: Text(
                        l10n.setpwValidationError,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Spacing.xLarge),
                  // Primary submit CTA.
                  Semantics(
                    identifier: 'setpw_submit_cta',
                    button: true,
                    child: OmdsPrimaryButton(
                      text: l10n.setpwSubmitCta,
                      isEnabled: !submitting,
                      onTap: _onSubmit,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/auth/set_password_screen_preview_test.dart
// ===========================================================================
//
// State is driven through the screen's own `cubitFactory` seam, with the seeded
// cubits shared verbatim with the Screen Catalog entry
// (`lib/devtool/catalog/fixtures/set_password_screen_fixtures.dart`). No preview
// builds a `DioAuthRepository` and nothing here resolves GetIt: `cubitFactory`
// short-circuits `_resolveAuthRepository()` entirely, so these previews are
// network-free BY CONSTRUCTION rather than by the guard in [jeebPreviewHost].
//
// Three things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + OMDSAppBar` paints inside it. Harmless, and the
//    same nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.** The `size:` on
//    [JeebPreview] boxes the canvas; [_setPasswordScreenHosted] pins the same
//    width in the widget tree, so the render tests measure the same phone
//    rather than the harness's 800 x 600 surface — otherwise `Compact 320 pt`
//    and the phone states would silently be the same widget.
//  * **Every state is pinned by a CAPTION** ([SetPasswordScreenCaptions], the
//    same device as `OtpVerificationScreenCaptions`) rather than by screen copy.
//    That is forced, not stylistic: four of these states render the SAME
//    sentence (see the first finding below), so `expectedText` on shipped copy
//    could not tell them apart. The render test asserts the real state behind
//    each caption — which fields are enabled, which eye icon is drawn, whether
//    the error node is mounted — so the caption is never the whole proof.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * **One sentence is shown for six different causes.** The error node is
//    hardcoded to `l10n.setpwValidationError` — "Passwords must match and meet
//    the strength requirements." — and `state.hasError` is the ONLY thing the
//    builder reads. So `SetPasswordValidation.mismatch`, `.weak` and `.empty`,
//    plus every `AuthFailure` the server can return (`network`, `invalidToken`,
//    `badRequest`, `unknown`), all paint the identical line. A user whose
//    request never left the phone is told their passwords do not match. The
//    discriminator EXISTS on the state — `validation` and `failure` are
//    separate fields, and `SetPasswordCubit` is careful to clear one when it
//    sets the other — and the screen throws it away. Read `Passwords differ`,
//    `Below the strength floor`, `Both fields blank` and `Never reached the
//    gateway` as a block: they are four pictures of one pixel arrangement, and
//    the ARB has no `setpwNetworkError` / `setpwWeak` / `setpwMismatch` key in
//    either locale to fix it with.
//  * **The submit in flight has no progress affordance at all.** `Submitting`
//    dims the CTA to `OmdsPrimaryButton`'s 45%-opacity disabled fill, greys the
//    two fields, and changes nothing else: the label still reads "Save
//    password", and there is no spinner anywhere on the surface
//    (`OmdsPrimaryButton` has no loading state and the screen adds none). It is
//    the same picture a disabled button would paint, so on a slow gateway the
//    screen looks broken rather than busy.
//  * **The strength floor is never stated, before OR after it is failed.**
//    `SetPasswordPolicy` wants 8 characters with at least one letter and one
//    digit; no helper text under the field says so, and the error copy only
//    says "meet the strength requirements". `Idle` is where that gap is
//    visible: two bare fields and a live CTA, with nothing to aim at.
//  * **The CTA is live on an empty form.** `isEnabled: !submitting` is the whole
//    gate, so the first thing a user can do on `Idle` is submit nothing — which
//    lands on `Both fields blank`, i.e. the mismatch/strength sentence about two
//    fields they never typed in.
//  * **`mode` is dead plumbing.** `SetPasswordMode` has one value,
//    `fromQuery` ignores its argument, and `_SetPasswordView.build` never reads
//    `widget.mode` — so the field is threaded through three layers and changes
//    no pixel. There is deliberately no per-mode preview: there is nothing to
//    see.
//  * **The typed password is not part of the state.** Both controllers live in
//    `_SetPasswordViewState` while the two `obscured` flags live in the cubit,
//    so `Both fields revealed` can only show the flipped eye icons over EMPTY
//    fields. No fixture, catalog entry or restored screen can put characters in
//    those boxes; a cubit rebuild would reset the eyes while the text stayed.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _setPasswordScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _setPasswordScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see the third bullet in the section prose. Dev chrome, never shipped
/// copy, so they are deliberately un-localized and rendered LTR at a fixed text
/// scale.
final class SetPasswordScreenCaptions {
  SetPasswordScreenCaptions._();

  /// Nothing typed, nothing submitted — the state every user lands in.
  static const String idle = 'preview · idle · nothing typed yet';

  /// `POST /v1/auth/set-password` in flight.
  static const String submitting = 'preview · set-password POST in flight';

  /// `SetPasswordValidation.mismatch`.
  static const String mismatch = 'preview · client check · passwords differ';

  /// `SetPasswordValidation.weak` — same picture as [mismatch].
  static const String weak = 'preview · client check · below strength floor';

  /// `SetPasswordValidation.empty` — same picture again.
  static const String emptyFields = 'preview · client check · both fields blank';

  /// `AuthFailure.network` — and still the same picture.
  static const String networkFailure =
      'preview · server failure · never reached gateway';

  /// Both eye toggles flipped to "shown".
  static const String revealed = 'preview · both eye toggles flipped';

  /// The 320 x 568 floor, showing the error node.
  static const String compact = 'preview · 320 pt · error at the ceiling';
}

/// Puts a seeded [SetPasswordCubit] behind [SetPasswordScreen], pins the device
/// frame in the tree, and captions the state.
///
/// The cubit factory is handed to the screen's own `cubitFactory` seam, so it is
/// built inside the screen's `BlocProvider.create`: each mount gets its own and
/// the provider closes it on dispose. Passing a pre-built cubit here would leak
/// one per canvas rebuild.
class _SetPasswordScreenPreviewFrame extends StatelessWidget {
  const _SetPasswordScreenPreviewFrame({
    required this.createCubit,
    required this.caption,
    required this.box,
  });

  final SetPasswordCubit Function() createCubit;

  /// The line painted above the device frame — see the section prose.
  final String caption;

  /// The device the state is being read on.
  final Size box;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            // one latin line and the 200% card does not spend a third of the
            // device on a label.
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: SetPasswordScreen(cubitFactory: createCubit),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _setPasswordScreenHosted(
  SetPasswordCubit Function() createCubit,
  String caption, {
  Size box = _setPasswordScreenPhoneBox,
}) =>
    _SetPasswordScreenPreviewFrame(
      createCubit: createCubit,
      caption: caption,
      box: box,
    );

/// The EMPTY state: two blank masked fields and a live "Save password".
///
/// Worth looking at for what is NOT here. Nothing states the strength floor
/// (`SetPasswordPolicy`: 8 characters, a letter and a digit), nothing marks
/// either field required, and the CTA's only gate is `!submitting` — so the
/// first action available on this screen is to submit nothing, which lands on
/// `Both fields blank` below.
@JeebPreview(
  group: 'auth',
  name: 'Idle · nothing typed',
  size: _setPasswordScreenPhoneBox,
)
Widget setPasswordScreenIdle() => _setPasswordScreenHosted(
      setPasswordScreenIdleCubit,
      SetPasswordScreenCaptions.idle,
    );

/// The LOADING state: `POST /v1/auth/set-password` in flight.
///
/// The whole visual difference from `Idle` is opacity. `isEnabled: !submitting`
/// drops the CTA to `OmdsPrimaryButton`'s 45%-alpha disabled fill and
/// `enabled: !submitting` greys the two fields; the label still says "Save
/// password" and there is no spinner on the surface, because
/// `OmdsPrimaryButton` has no loading state and nothing else was added. Held
/// next to `Idle`, this is what a user on a slow connection has to read
/// "working" out of.
@JeebPreview(
  group: 'auth',
  name: 'Submitting · POST in flight',
  size: _setPasswordScreenPhoneBox,
)
Widget setPasswordScreenSubmitting() => _setPasswordScreenHosted(
      setPasswordScreenSubmittingCubit,
      SetPasswordScreenCaptions.submitting,
    );

/// The ERROR state the catalog ships: new and confirm differ.
///
/// Matrixed because the error node is the only directional element the screen
/// grows — a `liveRegion` sentence added between the fields and the CTA — and
/// it is a full sentence in both locales. The AR column shows it mirrored under
/// RTL labels; the 200% column shows what it costs the CTA's position, since a
/// `ListView` will happily push "Save password" below the fold rather than
/// overflow.
@JeebPreview(
  group: 'auth',
  name: 'Error · passwords differ',
  size: _setPasswordScreenPhoneBox,
  matrix: true,
)
Widget setPasswordScreenMismatch() => _setPasswordScreenHosted(
      setPasswordScreenMismatchCubit,
      SetPasswordScreenCaptions.mismatch,
    );

/// A DIFFERENT cause, the same picture: the password is below the strength
/// floor while the two fields agree perfectly.
///
/// Keep this adjacent to `Error · passwords differ`. The identity is the
/// finding: the builder reads only `state.hasError` and paints
/// `l10n.setpwValidationError` for every reason, so a user who typed `abc` twice
/// is told their passwords must match — which they already do.
@JeebPreview(
  group: 'auth',
  name: 'Error · below strength floor',
  size: _setPasswordScreenPhoneBox,
)
Widget setPasswordScreenWeak() => _setPasswordScreenHosted(
      setPasswordScreenWeakCubit,
      SetPasswordScreenCaptions.weak,
    );

/// The most common failure on this screen, and the third copy of the same
/// picture: the CTA was tapped with a blank field.
///
/// `SetPasswordPolicy.validate` checks emptiness FIRST, so this is what `Idle`
/// turns into on a stray tap — and the answer is a sentence about matching and
/// strength for two fields the user never typed in.
@JeebPreview(
  group: 'auth',
  name: 'Error · both fields blank',
  size: _setPasswordScreenPhoneBox,
)
Widget setPasswordScreenEmptyFields() => _setPasswordScreenHosted(
      setPasswordScreenEmptyFieldsCubit,
      SetPasswordScreenCaptions.emptyFields,
    );

/// The SERVER failure, and the fourth copy of the same picture: the request
/// never reached the gateway.
///
/// This is the one that matters. `SetPasswordCubit.submit` catches the
/// `AuthRepositoryException`, records `AuthFailure.network` and CLEARS
/// `validation` — it is explicit that this was not a typing mistake — and the
/// screen then renders "Passwords must match and meet the strength
/// requirements." anyway. The user retypes a password that was never wrong,
/// twice, and gets the same line. `AuthFailure.invalidToken` (401 on the reset
/// token, unfixable by retyping) reaches the identical sentence; the fixture for
/// it is `setPasswordScreenInvalidTokenCubit`, deliberately not given a card
/// here because it would be a fifth identical picture.
@JeebPreview(
  group: 'auth',
  name: 'Error · never reached the gateway',
  size: _setPasswordScreenPhoneBox,
)
Widget setPasswordScreenNetworkFailure() => _setPasswordScreenHosted(
      setPasswordScreenNetworkFailureCubit,
      SetPasswordScreenCaptions.networkFailure,
    );

/// Both eye toggles flipped to "shown" — the only other cubit-driven visual on
/// the screen.
///
/// The fields are still EMPTY, and cannot be otherwise: the typed characters
/// live in `_SetPasswordViewState`'s two `TextEditingController`s, which no
/// fixture can reach. So what this card actually proves is that the toggles are
/// independent state and that the icon flips (`visibility` → `visibility_off`),
/// not what an unmasked password looks like.
@JeebPreview(
  group: 'auth',
  name: 'Both fields revealed',
  size: _setPasswordScreenPhoneBox,
)
Widget setPasswordScreenRevealed() => _setPasswordScreenHosted(
      setPasswordScreenRevealedCubit,
      SetPasswordScreenCaptions.revealed,
    );

/// The layout ceiling: the longest content this screen can hold — two labelled
/// fields, two hints and the full-sentence error — on the 320 x 568 floor.
///
/// Matrixed because that is where the sentence is really tested: at 200% text
/// the error copy alone runs to five lines in EN and the AR label
/// "تأكيد كلمة المرور" sits above a mirrored field, on a device 70 pt narrower
/// than the one every other card uses. The body is a `ListView`, so nothing
/// overflows — it scrolls, and the CTA leaves the screen instead. That is the
/// thing to look at: on this device, at this scale, the button the whole screen
/// exists for is below the fold the moment an error appears.
@JeebPreview(
  group: 'auth',
  name: 'Compact 320 pt · error at the ceiling',
  size: _setPasswordScreenCompactBox,
  matrix: true,
)
Widget setPasswordScreenCompact() => _setPasswordScreenHosted(
      setPasswordScreenMismatchCubit,
      SetPasswordScreenCaptions.compact,
      box: _setPasswordScreenCompactBox,
    );
