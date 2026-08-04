import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../core/session/session_cubit.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/super_login_service.dart';
import 'super_login_cubit.dart';
import 'super_login_state.dart';

Future<bool?> showSuperLoginSheet(
  BuildContext context, {
  SuperLoginCubit? cubit,
  SessionCubit? session,
  String? initialUserId,
  String? initialPasscode,
}) {
  // No backgroundColor/shape override: `bottomSheetTheme` already carries the
  // navy surface and the ratified sheet rung (26), which `topLarge` (20) is not.
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _SuperLoginScope(
      cubit: cubit,
      session: session,
      initialUserId: initialUserId,
      initialPasscode: initialPasscode,
    ),
  );
}

class _SuperLoginScope extends StatelessWidget {
  const _SuperLoginScope({
    this.cubit,
    this.session,
    this.initialUserId,
    this.initialPasscode,
  });

  final SuperLoginCubit? cubit;
  final SessionCubit? session;
  final String? initialUserId;
  final String? initialPasscode;

  @override
  Widget build(BuildContext context) {
    final body = _SuperLoginSheetBody(
      session: session,
      initialUserId: initialUserId,
      initialPasscode: initialPasscode,
    );
    final injected = cubit;
    if (injected != null) {
      return BlocProvider<SuperLoginCubit>.value(
        value: injected,
        child: body,
      );
    }
    return BlocProvider<SuperLoginCubit>(
      create: (_) => SuperLoginCubit(
        service: sl<SuperLoginService>(),
        tokenStore: sl<AuthTokenStore>(),
      ),
      child: body,
    );
  }
}

class _SuperLoginSheetBody extends StatefulWidget {
  const _SuperLoginSheetBody({
    this.session,
    this.initialUserId,
    this.initialPasscode,
  });

  final SessionCubit? session;

  final String? initialUserId;
  final String? initialPasscode;

  @override
  State<_SuperLoginSheetBody> createState() => _SuperLoginSheetBodyState();
}

class _SuperLoginSheetBodyState extends State<_SuperLoginSheetBody> {
  late final TextEditingController _userIdController;
  late final TextEditingController _passcodeController;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _userIdController =
        TextEditingController(text: widget.initialUserId ?? '');
    _passcodeController =
        TextEditingController(text: widget.initialPasscode ?? '');
    _canSubmit = _computeCanSubmit();
  }

  bool _computeCanSubmit() =>
      _userIdController.text.trim().isNotEmpty &&
      _passcodeController.text.isNotEmpty;

  @override
  void dispose() {
    _userIdController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  void _recomputeCanSubmit() {
    final next = _computeCanSubmit();
    if (next != _canSubmit) setState(() => _canSubmit = next);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<SuperLoginCubit>().submit(
          userId: _userIdController.text,
          passcode: _passcodeController.text,
        );
  }

  void _onFieldChanged() {
    _recomputeCanSubmit();
    final cubit = context.read<SuperLoginCubit>();
    if (cubit.state.status == SuperLoginStatus.error) cubit.clearError();
  }

  Future<void> _onStateChange(
    BuildContext context,
    SuperLoginState state,
  ) async {
    if (!state.isSuccess) return;
    await widget.session?.refresh();
    if (!context.mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SuperLoginCubit, SuperLoginState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: _onStateChange,
      child: _SuperLoginForm(
        userIdController: _userIdController,
        passcodeController: _passcodeController,
        canSubmit: _canSubmit,
        onChanged: _onFieldChanged,
        onSubmit: _submit,
      ),
    );
  }
}

class _SuperLoginForm extends StatelessWidget {
  const _SuperLoginForm({
    required this.userIdController,
    required this.passcodeController,
    required this.canSubmit,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController userIdController;
  final TextEditingController passcodeController;
  final bool canSubmit;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = context.sheetBottomInset;
    return Semantics(
      identifier: '_super_login_sheet',
      container: true,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Spacing.large,
          Spacing.medium,
          Spacing.large,
          Spacing.large + bottomInset,
        ),
        child: _SuperLoginFormColumn(
          userIdController: userIdController,
          passcodeController: passcodeController,
          canSubmit: canSubmit,
          onChanged: onChanged,
          onSubmit: onSubmit,
        ),
      ),
    );
  }
}

class _SuperLoginFormColumn extends StatelessWidget {
  const _SuperLoginFormColumn({
    required this.userIdController,
    required this.passcodeController,
    required this.canSubmit,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController userIdController;
  final TextEditingController passcodeController;
  final bool canSubmit;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetDragHandle(),
        const SizedBox(height: Spacing.large),
        const _SuperLoginHeader(),
        const SizedBox(height: Spacing.large),
        _SuperLoginFields(
          userIdController: userIdController,
          passcodeController: passcodeController,
          onChanged: onChanged,
          onSubmit: onSubmit,
        ),
        const SizedBox(height: Spacing.large),
        _SuperLoginSubmitButton(canSubmit: canSubmit, onSubmit: onSubmit),
      ],
    );
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Sizes.fourXLarge,
        height: Spacing.xSmall,
        decoration: BoxDecoration(
          color: colorScheme.onSurfaceVariant,
          borderRadius: OmdsBorderRadius.small,
        ),
      ),
    );
  }
}

class _SuperLoginHeader extends StatelessWidget {
  const _SuperLoginHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.superLoginTitle,
          key: const Key('superLogin.title'),
          style: context.jeebText.h2.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.superLoginSubtitle,
          style: context.jeebText.body.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SuperLoginFields extends StatelessWidget {
  const _SuperLoginFields({
    required this.userIdController,
    required this.passcodeController,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController userIdController;
  final TextEditingController passcodeController;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UserIdField(controller: userIdController, onChanged: onChanged),
        const SizedBox(height: Spacing.large),
        BlocBuilder<SuperLoginCubit, SuperLoginState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status || prev.error != curr.error,
          builder: (context, state) {
            final error = state.status == SuperLoginStatus.error
                ? state.error
                : null;
            return _PasscodeField(
              controller: passcodeController,
              onChanged: onChanged,
              onSubmit: onSubmit,
              errorText: error == null ? null : _errorCopy(context, error),
            );
          },
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.xSmall),
      child: Text(
        text,
        style: context.jeebText.bodySmall.copyWith(
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _UserIdField extends StatelessWidget {
  const _UserIdField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_super_login_user_id',
      textField: true,
      label: l10n.superLoginUserId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(l10n.superLoginUserId),
          OmdsTextField(
            key: const Key('superLogin.userId'),
            controller: controller,
            hintText: l10n.superLoginUserIdHint,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _PasscodeField extends StatelessWidget {
  const _PasscodeField({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_super_login_passcode',
      textField: true,
      label: l10n.superLoginPasscode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FieldLabel(l10n.superLoginPasscode),
          OMDSPasswordTextField(
            key: const Key('superLogin.passcode'),
            controller: controller,
            hint: l10n.superLoginPasscodeHint,
            textInputAction: TextInputAction.done,
            errorText: errorText,
            onChanged: (_) => onChanged(),
            onSubmitted: (_) => onSubmit(),
          ),
        ],
      ),
    );
  }
}

class _SuperLoginSubmitButton extends StatelessWidget {
  const _SuperLoginSubmitButton({required this.canSubmit, required this.onSubmit});

  final bool canSubmit;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<SuperLoginCubit, SuperLoginState>(
      buildWhen: (prev, curr) => prev.isSubmitting != curr.isSubmitting,
      builder: (context, state) {
        return Semantics(
          identifier: '_super_login_submit_cta',
          button: true,
          container: true,
          child: OmdsLoadingButton(
          key: const Key('superLogin.submit'),
          text: l10n.superLoginSubmit,
          isLoading: state.isSubmitting,
          isEnabled: canSubmit,
          onTap: onSubmit,
        ),
        );
      },
    );
  }
}

String _errorCopy(BuildContext context, SuperLoginError error) {
  final l10n = AppLocalizations.of(context);
  return switch (error) {
    SuperLoginError.network => l10n.superLoginNetworkError,
    SuperLoginError.invalidCredentials => l10n.superLoginError,
    SuperLoginError.unknown => l10n.superLoginError,
  };
}
