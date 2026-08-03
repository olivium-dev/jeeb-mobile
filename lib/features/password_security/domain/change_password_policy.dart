// (not a first-set) implies: a current-password field must be present, and the

enum ChangePasswordValidation {
  valid,

  empty,

  weak,

  mismatch,

  sameAsCurrent,
}

class ChangePasswordPolicy {
  const ChangePasswordPolicy();

  static const int minLength = 8;

  bool isStrong(String password) {
    if (password.length < minLength) return false;
    final hasLetter = password.contains(RegExp('[A-Za-z]'));
    final hasDigit = password.contains(RegExp('[0-9]'));
    return hasLetter && hasDigit;
  }

  ChangePasswordValidation validate({
    required String current,
    required String newPassword,
    required String confirm,
  }) {
    if (current.isEmpty || newPassword.isEmpty || confirm.isEmpty) {
      return ChangePasswordValidation.empty;
    }
    if (!isStrong(newPassword)) {
      return ChangePasswordValidation.weak;
    }
    if (newPassword == current) {
      return ChangePasswordValidation.sameAsCurrent;
    }
    if (newPassword != confirm) {
      return ChangePasswordValidation.mismatch;
    }
    return ChangePasswordValidation.valid;
  }
}
