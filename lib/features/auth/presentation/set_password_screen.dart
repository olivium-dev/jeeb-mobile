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
