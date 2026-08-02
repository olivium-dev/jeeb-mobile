import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/password_security_cubit.dart';
import '../application/password_security_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/password_security_screen_fixtures.dart';

/// Password-security screen (JM-061): change password (current / new / confirm fields with validation)
/// for password accounts, or "Set a password" entry for social-only (D90).
/// Current password verify + change endpoint not in mock (42_GUARDRAILS_MOCK);
/// only set-password via /v1/auth/set-password. Reaches from customer_profile_password_row (JM-035).
/// GATING: [hasPassword] gates change form. JM-061 AC4 / 67_W34_TEST_PLAN drive social-only variant via
/// `jeeb.seam.account_type=social_only` (not yet landed; defaults to password account).
class PasswordSecurityScreen extends StatelessWidget {
  const PasswordSecurityScreen({
    super.key,
    this.hasPassword = true,
    this.cubitFactory,
  });

  /// Whether account has password set. true → render change-password form; false (social-only, D90) → form suppressed.
  /// When true, both change form and social-only entry render (re-link affordance for password users who also want social).
  final bool hasPassword;

  /// Test seam: overrides cubit construction (40_GUARDRAILS_ARCH §5.4).
  final PasswordSecurityCubit Function()? cubitFactory;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PasswordSecurityCubit>(
      create: (_) => cubitFactory?.call() ?? PasswordSecurityCubit(),
      child: _PasswordSecurityView(hasPassword: hasPassword),
    );
  }
}

class _PasswordSecurityView extends StatefulWidget {
  const _PasswordSecurityView({required this.hasPassword});

  final bool hasPassword;

  @override
  State<_PasswordSecurityView> createState() => _PasswordSecurityViewState();
}

class _PasswordSecurityViewState extends State<_PasswordSecurityView> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    context.read<PasswordSecurityCubit>().submit(
          current: _currentController.text,
          newPassword: _newController.text,
          confirm: _confirmController.text,
        );
  }

  /// B-33: no change-password endpoint yet; surface "not available yet" and STAY on screen.
  void _onUnavailable(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: l10n.passwordChangeUnavailable);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'password_security_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.passwordSecurityTitle,
          showBackButton: true,
          leading: Semantics(
            identifier: 'password_back',
            button: true,
            container: true,
            child: BackButton(
              // EDGE: password_back → customer-profile (JM-061 AC).
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.goNamed('customer-profile'),
            ),
          ),
        ),
        body: BlocConsumer<PasswordSecurityCubit, PasswordSecurityState>(
          listenWhen: (p, n) =>
              p.status != n.status &&
              n.status == PasswordSecurityStatus.unavailable,
          listener: (context, state) => _onUnavailable(context),
          builder: (context, state) {
            final cubit = context.read<PasswordSecurityCubit>();
            final submitting =
                state.status == PasswordSecurityStatus.submitting;
            return SafeArea(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.medium,
                  Spacing.large,
                  Spacing.medium,
                  Spacing.xLarge,
                ),
                children: [
                  Text(
                    l10n.passwordSecurityBody,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.large),

                  if (widget.hasPassword) ...[
                    Semantics(
                      identifier: 'password_current_field',
                      textField: true,
                      child: OmdsTextField(
                        controller: _currentController,
                        labelText: l10n.loginPasswordLabel,
                        hintText: l10n.loginPasswordHint,
                        obscureText: state.currentObscured,
                        autoValidate: false,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => cubit.acknowledgeError(),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'password_new_field',
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
                          identifier: 'password_new_visibility_toggle',
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
                    Semantics(
                      identifier: 'password_confirm_field',
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
                          identifier: 'password_confirm_visibility_toggle',
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
                    if (state.hasStrengthError) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'password_strength_error',
                        liveRegion: true,
                        child: Text(
                          l10n.setpwValidationError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    if (state.hasMismatchError) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'password_mismatch_error',
                        liveRegion: true,
                        child: Text(
                          l10n.setpwValidationError,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.xLarge),
                    Semantics(
                      identifier: 'password_submit_cta',
                      button: true,
                      child: OmdsPrimaryButton(
                        text: l10n.setpwSubmitCta,
                        isEnabled: !submitting,
                        onTap: _onSubmit,
                      ),
                    ),
                    const SizedBox(height: Spacing.large),
                  ],

                  // Always reachable: social user without password sees only this; password user sees as re-link.
                  Semantics(
                    identifier: 'password_set_entry',
                    button: true,
                    container: true,
                    child: OmdsPrimaryButton(
                      text: l10n.passwordSetEntryCta,
                      variant: widget.hasPassword
                          ? OmdsButtonVariant.outlined
                          : OmdsButtonVariant.primary,
                      // EDGE: password_set_entry → set-password (?mode=in-app-social, D90).
                      // Pushed (keeps back stack to here); JM-022 screen owns POST + D90 exit.
                      onTap: () =>
                          context.pushNamed('set-password', queryParameters: {
                        'mode': 'in-app-social',
                      }),
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
// Render tests: test/previews/password_security/password_security_screen_preview_test.dart
// ===========================================================================
//
// State is driven through the screen's own `cubitFactory` seam, with the cubits
// shared verbatim with the Screen Catalog entry
// (`lib/devtool/catalog/fixtures/password_security_screen_fixtures.dart`).
//
// These previews are unusually literal. `PasswordSecurityCubit` has NO
// repository — B-33: there is no change-password endpoint, so `submit` is pure
// local validation and returns in the same turn — so nine of the ten states
// below are produced by CALLING the cubit's real public API, not by seeding a
// state object. Nothing here fakes a repository or stubs a policy, which means
// every card except `Submitting` is a state a real user can genuinely arrive
// at. `jeebPreviewHost`'s network guard has nothing to guard.
//
// Three things about this harness before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + OMDSAppBar` paints inside it. Harmless, and the
//    same nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.** `size:` boxes
//    the canvas; [_passwordSecurityScreenHosted] pins the same width in the
//    widget tree, so the render tests measure the same phone rather than the
//    harness's 800 x 600 surface — otherwise `Compact 320 pt` and the phone
//    states would silently be the same widget.
//  * **Every state is pinned by a CAPTION** ([PasswordSecurityScreenCaptions])
//    rather than by screen copy. Forced, not stylistic: five of these states
//    render the SAME sentence and two more render no distinguishing text at
//    all (see the findings below), so `expectedText` on shipped copy could not
//    tell them apart. The render test asserts the real state behind each
//    caption — which fields are enabled, which are masked, which error node is
//    mounted — so the caption is never the whole proof.
//
// What these previews surfaced in the screen itself:
//
//  * **Four causes, one sentence — and for two of them the sentence is
//    factually wrong.** Both error nodes are hardcoded to
//    `l10n.setpwValidationError`: "Passwords must match and meet the strength
//    requirements." `ChangePasswordValidation` distinguishes `empty`, `weak`,
//    `sameAsCurrent` and `mismatch`, and `PasswordSecurityState` carries the
//    value — but `hasStrengthError` folds `empty` + `weak` + `sameAsCurrent`
//    into one node and `hasMismatchError` takes `mismatch`, and both nodes
//    paint the identical string. So a user who typed their CURRENT password
//    into every box (`New equals current`) is told it fails the strength
//    requirements, when it is strong and matching; a user who typed nothing
//    (`Blank form`) is told the same. Read `Below the strength floor`,
//    `New and confirm differ`, `Blank form` and `New equals current` as one
//    block — they are four pictures of one pixel arrangement. The ARB has no
//    `passwordSameAsCurrent` / `passwordTooShort` / `passwordMismatch` key in
//    either locale to fix it with.
//  * **`PasswordSecurityStatus.submitting` cannot be reached.** `submit` is
//    synchronous: it validates and emits `failed` or `unavailable` in the same
//    turn, never `submitting`. Nothing else emits it. So the three
//    `enabled: !submitting` flags, the `isEnabled: !submitting` on the CTA and
//    the `if (state.status == submitting) return;` re-entrancy guard in the
//    cubit are all dead — no user has ever seen the picture `Submitting`
//    draws, and it took a seeded cubit to draw it here at all.
//  * **The CTA is therefore ALWAYS live, including on an empty form.**
//    `isEnabled: !submitting` is the whole gate and `submitting` is
//    unreachable, so the first thing a user can do on `Idle` is submit
//    nothing — which lands on `Blank form`, i.e. the match/strength sentence
//    about three fields they never typed in.
//  * **The B-33 notice leaves no trace.** `passwordChangeUnavailable`
//    ("Changing your password isn't available yet. Nothing was saved.") is
//    fired from `listenWhen` as a transient snackbar, and `unavailable` also
//    CLEARS `validation` — so the state a valid submit leaves behind is a
//    pristine idle form. `Valid submit · nothing saved` is that state, and it
//    is pixel-identical to `Idle`. Rotate the device, or come back to the
//    screen, and there is nothing on the surface saying the change did not
//    happen.
//  * **The current-password field can never be unmasked.**
//    `PasswordSecurityCubit.toggleCurrentObscured` exists and the screen reads
//    `state.currentObscured` — but nothing under `lib/` ever calls the toggle,
//    and `password_current_field` is the one field with no `suffixIcon`. The
//    other two get an eye. `All three unmasked` renders the state the cubit
//    supports and the UI has no control for.
//  * **A user WITH a password is offered "Set a password".** `hasPassword:
//    true` renders the change form AND `password_set_entry` — the source calls
//    it a "re-link affordance", but the copy (`passwordSetEntryCta`) says "Set
//    a password" and it sits directly under a form for changing the one they
//    already have. Hold `Change form · idle` next to `Social-only` and it is
//    the same button, differing only in `OmdsButtonVariant`.
//  * **The strength floor is never stated, before OR after it is failed.**
//    `ChangePasswordPolicy` wants 8 characters with at least one letter and one
//    digit; no helper text says so and the error copy only says "meet the
//    strength requirements".
//  * **The current-password field is labelled "Password".** It borrows
//    `loginPasswordLabel` / `loginPasswordHint` ("Password" / "Your password")
//    from the login screen, directly above "New password" — so the field
//    asking for the OLD one is the least specific of the three.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _passwordSecurityScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _passwordSecurityScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see the third bullet in the section prose. Dev chrome, never shipped
/// copy, so they are deliberately un-localized and rendered LTR at a fixed text
/// scale.
final class PasswordSecurityScreenCaptions {
  PasswordSecurityScreenCaptions._();

  /// Nothing typed, nothing submitted — the state every user lands in.
  static const String idle = 'preview · idle · nothing typed yet';

  /// `hasPassword: false` — the change form is suppressed entirely (D90).
  static const String socialOnly = 'preview · social-only · no change form';

  /// `PasswordSecurityStatus.submitting` — seeded, because nothing emits it.
  static const String submitting =
      'preview · submitting · unreachable in production';

  /// `ChangePasswordValidation.weak`.
  static const String weak = 'preview · client check · below strength floor';

  /// `ChangePasswordValidation.mismatch` — same sentence as [weak].
  static const String mismatch =
      'preview · client check · new and confirm differ';

  /// `ChangePasswordValidation.empty` — same sentence again.
  static const String emptyFields =
      'preview · client check · submitted a blank form';

  /// `ChangePasswordValidation.sameAsCurrent` — and still the same sentence.
  static const String sameAsCurrent =
      'preview · client check · new equals current';

  /// `PasswordSecurityStatus.unavailable` — B-33, after the snackbar is gone.
  static const String unavailable = 'preview · valid submit · nothing saved';

  /// All three obscure flags flipped, including the one with no control.
  static const String revealed = 'preview · all three fields unmasked';

  /// The 320 x 568 floor, showing the error node.
  static const String compact = 'preview · 320 pt · error at the ceiling';
}

/// Puts a seeded [PasswordSecurityCubit] behind [PasswordSecurityScreen], pins
/// the device frame in the tree, and captions the state.
///
/// The cubit factory is handed to the screen's own `cubitFactory` seam, so it is
/// built inside the screen's `BlocProvider.create`: each mount gets its own and
/// the provider closes it on dispose. Passing a pre-built cubit here would leak
/// one per canvas rebuild — and would also let a second mount observe the first
/// mount's state as a CHANGE, which is the one way a fixture could fire the
/// `unavailable` snackbar.
class _PasswordSecurityScreenPreviewFrame extends StatelessWidget {
  const _PasswordSecurityScreenPreviewFrame({
    required this.createCubit,
    required this.caption,
    required this.box,
    required this.hasPassword,
  });

  final PasswordSecurityCubit Function() createCubit;

  /// The line painted above the device frame — see the section prose.
  final String caption;

  /// The device the state is being read on.
  final Size box;

  /// The screen's own gate: `true` renders the change form (plus the set-entry
  /// button), `false` renders the set-entry button alone.
  final bool hasPassword;

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
              child: PasswordSecurityScreen(
                hasPassword: hasPassword,
                cubitFactory: createCubit,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Widget _passwordSecurityScreenHosted(
  PasswordSecurityCubit Function() createCubit,
  String caption, {
  Size box = _passwordSecurityScreenPhoneBox,
  bool hasPassword = true,
}) =>
    _PasswordSecurityScreenPreviewFrame(
      createCubit: createCubit,
      caption: caption,
      box: box,
      hasPassword: hasPassword,
    );

/// The EMPTY state: three blank masked fields and a live "Save password".
///
/// Worth looking at for what is NOT here. Nothing states the strength floor
/// (`ChangePasswordPolicy`: 8 characters, a letter and a digit), nothing marks
/// any field required, the current-password field is labelled just "Password",
/// and the CTA's only gate is `!submitting` — a status nothing can emit — so
/// the first action available on this screen is to submit nothing, which lands
/// on `Blank form` below.
@JeebPreview(
  group: 'password_security',
  name: 'Change form · idle',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenIdle() => _passwordSecurityScreenHosted(
      passwordSecurityScreenIdleCubit,
      PasswordSecurityScreenCaptions.idle,
    );

/// The social-only account (D90): `hasPassword: false` suppresses the whole
/// change form and leaves the intro paragraph plus one button.
///
/// This is the screen's real EMPTY state — there is no data to be missing, so
/// "empty" here means "the feature this screen is named after is not offered".
/// Held next to `Change form · idle`, the finding is that the SAME button is on
/// both: a user who already has a password is also invited to "Set a password",
/// differing only in `OmdsButtonVariant.outlined` vs `.primary`.
@JeebPreview(
  group: 'password_security',
  name: 'Social-only · no change form',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenSocialOnly() => _passwordSecurityScreenHosted(
      passwordSecurityScreenIdleCubit,
      PasswordSecurityScreenCaptions.socialOnly,
      hasPassword: false,
    );

/// The LOADING state — which no user has ever seen.
///
/// `PasswordSecurityCubit.submit` is synchronous and emits `failed` or
/// `unavailable` in the same turn; nothing anywhere emits `submitting`. This
/// card exists only because a dev-only seeded cubit
/// (`PasswordSecurityScreenSeededCubit`) can force it, and what it shows is
/// what the screen would draw if the endpoint were ever wired: three greyed
/// fields and a 45%-alpha CTA whose label still reads "Save password", with no
/// spinner anywhere — `OmdsPrimaryButton` has no loading state and the screen
/// adds none. Identical to "disabled".
@JeebPreview(
  group: 'password_security',
  name: 'Submitting · unreachable state',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenSubmitting() => _passwordSecurityScreenHosted(
      passwordSecurityScreenSubmittingCubit,
      PasswordSecurityScreenCaptions.submitting,
    );

/// The ERROR state the catalog ships as `Strength Error`: the new password is
/// below the floor while the two new fields agree perfectly.
///
/// Matrixed because the error node is the only directional element this screen
/// grows — a `liveRegion` sentence inserted between the fields and the CTA —
/// and it is a full sentence in both locales. The AR column shows it mirrored
/// under RTL labels; the 200% column shows what it costs the CTA's position,
/// since a `ListView` will happily push "Save password" below the fold rather
/// than overflow.
@JeebPreview(
  group: 'password_security',
  name: 'Error · below strength floor',
  size: _passwordSecurityScreenPhoneBox,
  matrix: true,
)
Widget passwordSecurityScreenWeak() => _passwordSecurityScreenHosted(
      passwordSecurityScreenWeakCubit,
      PasswordSecurityScreenCaptions.weak,
    );

/// A DIFFERENT cause, the same picture: new and confirm differ while the new
/// password is strong. The catalog's `Mismatch Error`.
///
/// Keep this adjacent to `Error · below strength floor`. The two states mount
/// different `Semantics` nodes — `password_mismatch_error` vs
/// `password_strength_error` — and paint the identical sentence, because both
/// branches hardcode `l10n.setpwValidationError`.
@JeebPreview(
  group: 'password_security',
  name: 'Error · new and confirm differ',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenMismatch() => _passwordSecurityScreenHosted(
      passwordSecurityScreenMismatchCubit,
      PasswordSecurityScreenCaptions.mismatch,
    );

/// The most common failure on this screen, and the third copy of the same
/// picture: the CTA was tapped on an untouched form.
///
/// `ChangePasswordPolicy.validate` checks emptiness FIRST, so this is what
/// `Change form · idle` turns into on a stray tap — and the answer is a
/// sentence about matching and strength for three fields the user never typed
/// in. It routes through `hasStrengthError`, so the node is
/// `password_strength_error`.
@JeebPreview(
  group: 'password_security',
  name: 'Error · blank form submitted',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenEmptyFields() => _passwordSecurityScreenHosted(
      passwordSecurityScreenEmptyFieldsCubit,
      PasswordSecurityScreenCaptions.emptyFields,
    );

/// The state where the shared sentence becomes actively WRONG: the user typed
/// their current password into all three boxes.
///
/// `ChangePasswordValidation.sameAsCurrent` — the password is strong (it passes
/// `isStrong` before this branch is reached) and new and confirm match exactly.
/// The only thing wrong is that nothing changed. The screen answers "Passwords
/// must match and meet the strength requirements.", which is false on both
/// counts, and nothing on the surface says "pick a different one".
@JeebPreview(
  group: 'password_security',
  name: 'Error · new equals current',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenSameAsCurrent() => _passwordSecurityScreenHosted(
      passwordSecurityScreenSameAsCurrentCubit,
      PasswordSecurityScreenCaptions.sameAsCurrent,
    );

/// B-33 after the snackbar: a perfectly valid change was submitted, no endpoint
/// exists, and this is what is left on screen.
///
/// Compare it to `Change form · idle` — they are the same picture.
/// `PasswordSecurityStatus.unavailable` renders nothing, and `submit` CLEARS
/// `validation` on that path, so the only feedback the user ever gets is the
/// transient `passwordChangeUnavailable` snackbar fired from `listenWhen`. Come
/// back to the screen, rotate the device, or let the snackbar time out and
/// there is no trace that the save did not happen.
@JeebPreview(
  group: 'password_security',
  name: 'Valid submit · nothing saved',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenUnavailable() => _passwordSecurityScreenHosted(
      passwordSecurityScreenUnavailableCubit,
      PasswordSecurityScreenCaptions.unavailable,
    );

/// All three obscure flags flipped to "shown" — the only other cubit-driven
/// visual on the screen.
///
/// The fields are still EMPTY, and cannot be otherwise: the typed characters
/// live in `_PasswordSecurityViewState`'s three `TextEditingController`s, which
/// no fixture can reach. What this card proves is that the current-password
/// field CAN be unmasked and that the screen offers no way to do it: two eye
/// buttons are drawn (`password_new_visibility_toggle`,
/// `password_confirm_visibility_toggle`) for three maskable fields, and
/// `toggleCurrentObscured` has no caller anywhere under `lib/`.
@JeebPreview(
  group: 'password_security',
  name: 'All three fields unmasked',
  size: _passwordSecurityScreenPhoneBox,
)
Widget passwordSecurityScreenRevealed() => _passwordSecurityScreenHosted(
      passwordSecurityScreenRevealedCubit,
      PasswordSecurityScreenCaptions.revealed,
    );

/// The layout ceiling: the longest content this screen can hold — three
/// labelled fields, three hints, the intro paragraph, the full-sentence error
/// and two buttons — on the 320 x 568 floor.
///
/// Matrixed because that is where the sentence is really tested: at 200% text
/// the error copy alone runs to several lines in EN, and the AR label
/// "تأكيد كلمة المرور" sits above a mirrored field, on a device 70 pt narrower
/// than every other card. The body is a `ListView`, so nothing overflows — it
/// scrolls, and the CTA leaves the viewport instead. That is the thing to look
/// at: on this device, at this scale, the button the whole screen exists for is
/// below the fold the moment an error appears.
@JeebPreview(
  group: 'password_security',
  name: 'Compact 320 pt · error at the ceiling',
  size: _passwordSecurityScreenCompactBox,
  matrix: true,
)
Widget passwordSecurityScreenCompact() => _passwordSecurityScreenHosted(
      passwordSecurityScreenMismatchCubit,
      PasswordSecurityScreenCaptions.compact,
      box: _passwordSecurityScreenCompactBox,
    );
