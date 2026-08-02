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

enum SetPasswordMode {
  inAppSocial;

  static SetPasswordMode fromQuery(String? value) => SetPasswordMode.inAppSocial;
}

class SetPasswordScreen extends StatelessWidget {
  const SetPasswordScreen({
    super.key,
    this.mode = SetPasswordMode.inAppSocial,
    this.email = '',
    this.resetToken,
    this.cubitFactory,
  });

  final SetPasswordMode mode;
  final String email;
  final String? resetToken;
  final SetPasswordCubit Function()? cubitFactory;

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

  void _onSucceeded(BuildContext context) {
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

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _setPasswordScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _setPasswordScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
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
/// The cubit factory is handed to the screen's own `cubitFactory` seam, so it is
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
/// Worth looking at for what is NOT here. Nothing states the strength floor
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
/// The whole visual difference from `Idle` is opacity. `isEnabled: !submitting`
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
/// Matrixed because the error node is the only directional element the screen
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
