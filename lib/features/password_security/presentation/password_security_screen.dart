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

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _passwordSecurityScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _passwordSecurityScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
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
/// The cubit factory is handed to the screen's own `cubitFactory` seam, so it is
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
/// Worth looking at for what is NOT here. Nothing states the strength floor
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
/// `PasswordSecurityCubit.submit` is synchronous and emits `failed` or
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
