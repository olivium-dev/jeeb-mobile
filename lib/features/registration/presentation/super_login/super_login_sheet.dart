import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/layout/bottom_inset.dart';
import '../../../../core/network/auth_token_store.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/super_login_service.dart';
import 'super_login_cubit.dart';
import 'super_login_state.dart';

/// Opens the FR-P0-4 super-login credential sheet (Rahma-shaped, OMDS-built).
///
/// Hosts a [SuperLoginCubit] scoped to the sheet. On a successful, server-
/// validated sign-in the sheet pops with `true`; the caller then navigates
/// home. Pass a custom [cubit] from tests; production builds one from DI.
///
/// [initialUserId] / [initialPasscode] pre-fill the two credential fields —
/// used by the "Super user login plus" picker, which hands a chosen demo
/// user's credentials in so the form opens submit-ready. Both default to null
/// (empty fields), so every existing `showSuperLoginSheet(context)` call site
/// is unaffected.
Future<bool?> showSuperLoginSheet(
  BuildContext context, {
  SuperLoginCubit? cubit,
  String? initialUserId,
  String? initialPasscode,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: OmdsBorderRadius.topLarge,
    ),
    builder: (sheetContext) => _SuperLoginScope(
      cubit: cubit,
      initialUserId: initialUserId,
      initialPasscode: initialPasscode,
    ),
  );
}

/// Builds (or adopts) the [SuperLoginCubit] for the sheet body.
class _SuperLoginScope extends StatelessWidget {
  const _SuperLoginScope({
    this.cubit,
    this.initialUserId,
    this.initialPasscode,
  });

  final SuperLoginCubit? cubit;
  final String? initialUserId;
  final String? initialPasscode;

  @override
  Widget build(BuildContext context) {
    final body = _SuperLoginSheetBody(
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

/// The credential form. Owns the two controllers + the submit-enabled flag,
/// and reacts to cubit success (pop) / error (snackbar).
class _SuperLoginSheetBody extends StatefulWidget {
  const _SuperLoginSheetBody({this.initialUserId, this.initialPasscode});

  /// Pre-fill values supplied by the "Super user login plus" picker. Null when
  /// the sheet is opened directly (the original empty-field behaviour).
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
    // When both fields arrive pre-filled (picker path) the "Sign in" button
    // must be enabled immediately — otherwise the user stares at a disabled
    // CTA. Set the flag DIRECTLY here (not via `_recomputeCanSubmit`, which
    // calls `setState` — illegal during initState). A no-op-to-false when both
    // are empty (the direct-open path).
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
    // DEF-2: clear any surfaced credential error the moment the user edits a
    // field, so a stale "invalid credentials" message doesn't linger while
    // they type a correction. `submit` re-evaluates from a clean slate.
    final cubit = context.read<SuperLoginCubit>();
    if (cubit.state.status == SuperLoginStatus.error) cubit.clearError();
  }

  void _onStateChange(BuildContext context, SuperLoginState state) {
    // Success is the only transition that pops the sheet. Errors are surfaced
    // INLINE under the passcode field (DEF-2) by [_SuperLoginFields] reading
    // the cubit state directly — no snackbar, which the QA run never saw.
    if (state.isSuccess) {
      Navigator.of(context).pop(true);
    }
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

/// Pure layout: keyboard-safe padding + the credential fields + submit CTA.
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
    // Keyboard inset + system nav-bar inset: keeps the submit CTA clear of both
    // the keyboard AND the soft-button nav bar under edge-to-edge. Using only
    // `viewInsets.bottom` (keyboard) left the button behind the nav bar.
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
          color: colorScheme.onSurface.withValues(alpha: UIConstants.opacityLow),
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
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.superLoginSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
        const SizedBox(height: Spacing.medium),
        // DEF-2: the passcode field renders the server-side rejection (401
        // ProblemDetails) INLINE via its OMDS `errorText` slot — below the
        // field, in `colorScheme.error`. The message comes from the cubit
        // state, so a wrong passcode is now visible to the user instead of
        // failing silently.
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
      child: OmdsTextField(
        key: const Key('superLogin.userId'),
        controller: controller,
        labelText: l10n.superLoginUserId,
        hintText: l10n.superLoginUserIdHint,
        textInputAction: TextInputAction.next,
        onChanged: (_) => onChanged(),
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

  /// Inline credential error shown below the field (DEF-2). Null when there is
  /// no error to surface.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_super_login_passcode',
      textField: true,
      label: l10n.superLoginPasscode,
      child: OMDSPasswordTextField(
        key: const Key('superLogin.passcode'),
        controller: controller,
        labelText: l10n.superLoginPasscode,
        hint: l10n.superLoginPasscodeHint,
        textInputAction: TextInputAction.done,
        errorText: errorText,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onSubmit(),
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
        return OmdsLoadingButton(
          key: const Key('superLogin.submit'),
          text: l10n.superLoginSubmit,
          isLoading: state.isSubmitting,
          isEnabled: canSubmit,
          onTap: onSubmit,
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
