// Shared dev-only fixtures for `PasswordSecurityScreen` (JM-061).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_08_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/password_security/presentation/password_security_screen.dart`.
//
// The catalog owned two private builders — `_weakPasswordCubit` and
// `_mismatchPasswordCubit`. Copying them into the preview section would have
// given the two surfaces two different notions of "the mismatch state", free to
// drift, and the catalog is the one a designer signs off against. Both surfaces
// now import this file. The catalog's four states (`Change Form — Idle`,
// `Social-Only — Set Password Entry`, `Strength Error`, `Mismatch Error`) are
// unchanged, down to the exact strings fed to `submit`; the extra states below
// exist only because the preview canvas asks harder questions than the catalog
// does.
//
// ## Almost every state is DRIVEN, not seeded
//
// `PasswordSecurityCubit` needs no repository at all — B-33: there is no
// change-password endpoint, so `submit` is pure local validation and returns
// synchronously. That makes these fixtures unusually honest: a state reached by
// calling the cubit's real public API is a state a real user can reach, and
// nine of the ten below are built that way. Nothing here fakes a repository,
// stubs a policy, or reaches past a seam.
//
// The exception is [PasswordSecurityStatus.submitting], and the exception is
// itself the finding — see [passwordSecurityScreenSubmittingCubit].
//
// ## Why driving in the factory keeps them inert
//
// Every builder below emits its state BEFORE the cubit is handed back to
// `PasswordSecurityScreen.cubitFactory`, i.e. before `BlocProvider.create`
// returns and long before `BlocConsumer` subscribes. The screen's `listenWhen`
// is `p.status != n.status && n.status == unavailable`, so a state that was
// already in place when the first subscriber arrived is never seen as a status
// CHANGE. No fixture can fire `_onUnavailable`, which is what lets these render
// with no `ScaffoldMessenger` interaction and no pending snackbar timers — and
// what makes `passwordSecurityScreenUnavailableCubit` show what the unavailable
// state actually looks like on a REBUILD, once the transient notice is gone.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'package:jeeb_mobile/features/password_security/application/password_security_cubit.dart';
import 'package:jeeb_mobile/features/password_security/application/password_security_state.dart';
import 'package:jeeb_mobile/features/password_security/domain/change_password_policy.dart';

/// The account's existing password, as typed into `password_current_field`.
///
/// Eight characters with a letter and a digit, so it clears
/// [ChangePasswordPolicy.isStrong] and cannot be the reason any state below
/// fails.
const String passwordSecurityScreenCurrentPassword = 'OldPass1';

/// A replacement that clears the strength floor and differs from the current
/// one — the only input that reaches `valid`.
const String passwordSecurityScreenNewPassword = 'NewPass123';

/// A confirmation that does not match [passwordSecurityScreenNewPassword].
const String passwordSecurityScreenConfirmMismatch = 'Mismatch123';

/// Below the floor: four characters, no digit.
const String passwordSecurityScreenWeakPassword = 'weak';

/// A [PasswordSecurityCubit] that starts in [seed] instead of the default idle
/// state.
///
/// DEV-ONLY. It is not a production seam and it adds none: the screen still only
/// ever sees a `PasswordSecurityCubit` come back from its `cubitFactory`. It
/// exists for exactly one state — see [passwordSecurityScreenSubmittingCubit] —
/// and every other fixture in this file deliberately avoids it.
class PasswordSecurityScreenSeededCubit extends PasswordSecurityCubit {
  /// Emits [seed] immediately, before any surface has subscribed.
  PasswordSecurityScreenSeededCubit(PasswordSecurityState seed) {
    emit(seed);
  }
}

/// The state every user lands in: three blank masked fields, no error, a live
/// "Save password". Catalog: `Change Form — Idle`.
PasswordSecurityCubit passwordSecurityScreenIdleCubit() =>
    PasswordSecurityCubit();

/// `ChangePasswordValidation.weak` — the new password is below the floor
/// ([ChangePasswordPolicy]: 8 characters, a letter and a digit) while the two
/// new-password fields agree perfectly. Catalog: `Strength Error`.
PasswordSecurityCubit passwordSecurityScreenWeakCubit() =>
    PasswordSecurityCubit()
      ..submit(
        current: passwordSecurityScreenCurrentPassword,
        newPassword: passwordSecurityScreenWeakPassword,
        confirm: passwordSecurityScreenWeakPassword,
      );

/// `ChangePasswordValidation.mismatch` — new and confirm differ, and the new
/// password is otherwise fine. Catalog: `Mismatch Error`.
PasswordSecurityCubit passwordSecurityScreenMismatchCubit() =>
    PasswordSecurityCubit()
      ..submit(
        current: passwordSecurityScreenCurrentPassword,
        newPassword: passwordSecurityScreenNewPassword,
        confirm: passwordSecurityScreenConfirmMismatch,
      );

/// `ChangePasswordValidation.empty` — the CTA was tapped on an untouched form.
///
/// [ChangePasswordPolicy.validate] tests emptiness FIRST, and the CTA's only
/// gate is `!submitting`, so this is what the idle screen turns into on a stray
/// tap. It routes through `hasStrengthError`.
PasswordSecurityCubit passwordSecurityScreenEmptyFieldsCubit() =>
    PasswordSecurityCubit()
      ..submit(current: '', newPassword: '', confirm: '');

/// `ChangePasswordValidation.sameAsCurrent` — the "new" password is the one the
/// account already has, typed identically into all three boxes.
///
/// The password is strong and the two new fields match; the only thing wrong is
/// that nothing changed. It routes through `hasStrengthError` all the same.
PasswordSecurityCubit passwordSecurityScreenSameAsCurrentCubit() =>
    PasswordSecurityCubit()
      ..submit(
        current: passwordSecurityScreenCurrentPassword,
        newPassword: passwordSecurityScreenCurrentPassword,
        confirm: passwordSecurityScreenCurrentPassword,
      );

/// `PasswordSecurityStatus.unavailable` — a perfectly valid change, submitted.
///
/// B-33: there is no `POST` behind this form, so `submit` records `unavailable`
/// and the screen answers with a transient snackbar. `unavailable` also CLEARS
/// `validation`, so the state left behind is the idle form again.
PasswordSecurityCubit passwordSecurityScreenUnavailableCubit() =>
    PasswordSecurityCubit()
      ..submit(
        current: passwordSecurityScreenCurrentPassword,
        newPassword: passwordSecurityScreenNewPassword,
        confirm: passwordSecurityScreenNewPassword,
      );

/// `PasswordSecurityStatus.submitting` — the ONLY state in this file that has
/// to be seeded, because no sequence of calls on `PasswordSecurityCubit` can
/// produce it.
///
/// `submit` is synchronous end to end: it validates and emits either `failed`
/// or `unavailable` in the same turn, and never `submitting`. The guard at the
/// top of `submit` (`if (state.status == submitting) return;`) can therefore
/// never be true either. The screen nonetheless spends three `enabled:` flags
/// and an `isEnabled:` on the branch — this fixture is what makes that dead
/// wiring visible.
PasswordSecurityCubit passwordSecurityScreenSubmittingCubit() =>
    PasswordSecurityScreenSeededCubit(
      const PasswordSecurityState(status: PasswordSecurityStatus.submitting),
    );

/// All three obscure flags flipped to "shown", through the cubit's own public
/// toggles.
///
/// `toggleNewObscured` and `toggleConfirmObscured` each have a control on the
/// screen. `toggleCurrentObscured` has none — no caller anywhere under `lib/` —
/// so the unmasked current-password field this fixture produces is a state no
/// user can reach.
PasswordSecurityCubit passwordSecurityScreenRevealedCubit() =>
    PasswordSecurityCubit()
      ..toggleCurrentObscured()
      ..toggleNewObscured()
      ..toggleConfirmObscured();
