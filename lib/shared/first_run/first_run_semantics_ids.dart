/// Stable Semantics identifiers exported by the first-run flow.
///
/// Maestro resolves Flutter [Semantics.identifier] values as accessibility
/// resource IDs. Keep these values stable once a flow targets them.
class FirstRunSemanticsIds {
  const FirstRunSemanticsIds._();

  static const String onboardingScreen = 'onboarding_screen';
  static const String onboardingPager = 'onboarding_pager';
  static const String onboardingDots = 'onboarding_dots';
  static const String onboardingNextButton = 'onboarding_next_button';
  static const String onboardingGetStartedButton =
      'onboarding_get_started_button';
  static const String onboardingSkipButton = 'onboarding_skip_button';
  static const String onboardingLanguageToggle = 'onboarding_language_toggle';

  static const String registrationScreen = 'registration_screen';
  static const String registrationHero = 'registration_hero';
  static const String registrationHeroLogo = 'registration_hero_logo';
  static const String registrationSocialSection = 'registration_social_section';
  static const String registrationPhoneField = 'registration_phone_field';
  static const String registrationSendCodeButton =
      'registration_send_code_button';
  static const String superLoginButton = 'super_login_button';
  static const String superLoginPlusButton = 'super_login_plus_button';

  static const String otpScreen = 'registration_otp_screen';
  static const String otpBackButton = 'registration_otp_back_button';
  static const String otpField = 'registration_otp_field';
  static const String otpVerifyButton = 'registration_verify_button';
  static const String otpError = 'registration_otp_error';
  static const String otpAttemptsLeft = 'registration_otp_attempts_left';
  static const String otpResendButton = 'registration_otp_resend_button';
  static const String otpResendCountdown = 'registration_otp_resend_countdown';
  static const String otpChangePhoneButton =
      'registration_otp_change_phone_button';
  static const String otpLockoutBanner = 'registration_otp_lockout_banner';

  static const String superLoginSheet = 'super_login_sheet';
  static const String superLoginUserIdField = 'super_login_user_id_field';
  static const String superLoginPasscodeField = 'super_login_passcode_field';
  static const String superLoginSubmitButton = 'super_login_submit_button';

  static const String superLoginPlusPicker = 'super_login_plus_picker';
  static const String superLoginPlusPickerLoading =
      'super_login_plus_picker_loading';
  static const String superLoginPlusPickerError =
      'super_login_plus_picker_error';
  static const String superLoginPlusPickerList = 'super_login_plus_picker_list';

  static const String homeShell = 'home_shell';

  static String superLoginPlusUser(String userId) =>
      'super_login_plus_user_$userId';

  static String onboardingIllustrationSlide(int zeroBasedIndex) =>
      'onboarding_illustration_${zeroBasedIndex + 1}';
}
