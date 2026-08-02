enum SetPasswordValidation {
  valid,

  mismatch,

  weak,

  empty,
}

class SetPasswordPolicy {
  const SetPasswordPolicy();

  static const int minLength = 8;

  bool isStrong(String password) {
    if (password.length < minLength) return false;
    final hasLetter = password.contains(RegExp('[A-Za-z]'));
    final hasDigit = password.contains(RegExp('[0-9]'));
    return hasLetter && hasDigit;
  }

  SetPasswordValidation validate({
    required String newPassword,
    required String confirmPassword,
  }) {
    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      return SetPasswordValidation.empty;
    }
    if (!isStrong(newPassword)) {
      return SetPasswordValidation.weak;
    }
    if (newPassword != confirmPassword) {
      return SetPasswordValidation.mismatch;
    }
    return SetPasswordValidation.valid;
  }
}
