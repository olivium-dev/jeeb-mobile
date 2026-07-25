import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Hand-authored localizations layer for Jeeb. ARB files at
/// `lib/l10n/app_{en,ar}.arb` are the source of truth and are bundled as
/// assets; this class parses them at load time and exposes typed getters.
///
/// When the team adopts `flutter gen-l10n`, this file can be deleted and the
/// generated class swapped in without changing call sites — every getter name
/// matches the ARB key.
class AppLocalizations {
  AppLocalizations(this.locale, this._strings);

  final Locale locale;
  final Map<String, String> _strings;

  static const supportedLocales = <Locale>[Locale('en'), Locale('ar')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(
      localizations != null,
      'AppLocalizations not found in context — did you forget to add '
      'AppLocalizations.delegate to MaterialApp.localizationsDelegates?',
    );
    return localizations!;
  }

  String _get(String key) {
    final value = _strings[key];
    assert(
      value != null,
      'Missing ARB key: $key for ${locale.toLanguageTag()}',
    );
    assert(
      value != key,
      'ARB value equals key for "$key" in ${locale.toLanguageTag()} — '
      'this is a sentinel stub that was never translated.',
    );
    return value ?? key;
  }

  /// Test-only accessor over the loaded ARB map. Used by
  /// `test/l10n/runtime_parity_test.dart` (JEB-2 LEAD §3) to assert that no
  /// rendered value equals its key. Returns `null` for unknown keys.
  @visibleForTesting
  String? byKey(String key) => _strings[key];

  /// Test-only snapshot of the loaded ARB map.
  @visibleForTesting
  Map<String, String> get allStrings => Map.unmodifiable(_strings);

  String get appTitle => _get('appTitle');

  String get navHome => _get('navHome');
  String get navOrders => _get('navOrders');
  String get navChat => _get('navChat');
  String get navProfile => _get('navProfile');
  String get navDashboard => _get('navDashboard');
  String get navEarnings => _get('navEarnings');
  String get navRequests => _get('navRequests');
  String get navDelivery => _get('navDelivery');

  String get homeTitle => _get('homeTitle');
  String get homeEmptyTitle => _get('homeEmptyTitle');
  String get homeEmptyCta => _get('homeEmptyCta');
  String get homeActiveSectionTitle => _get('homeActiveSectionTitle');
  String get homeRecentSectionTitle => _get('homeRecentSectionTitle');
  String get homeTabInProgress => _get('homeTabInProgress');
  String get homeTabPendingRequests => _get('homeTabPendingRequests');
  String get homeTabReplies => _get('homeTabReplies');
  String get homeInProgressEmpty => _get('homeInProgressEmpty');
  String get homePendingEmpty => _get('homePendingEmpty');
  String get homeRepliesEmpty => _get('homeRepliesEmpty');
  String get homeRepliesCheckOffersCta => _get('homeRepliesCheckOffersCta');
  String get homeTrackOrderCta => _get('homeTrackOrderCta');
  String get homeOpenChatCta => _get('homeOpenChatCta');
  String get homeStageOrdered => _get('homeStageOrdered');
  String get homeStagePicked => _get('homeStagePicked');
  String get homeStageInTransit => _get('homeStageInTransit');
  String get chatOfferAccept => _get('chatOfferAccept');
  String get chatOfferAccepting => _get('chatOfferAccepting');
  String get chatOfferDecline => _get('chatOfferDecline');
  String get chatOfferDeclineConfirm => _get('chatOfferDeclineConfirm');
  String get chatOfferAcceptedBannerTitle =>
      _get('chatOfferAcceptedBannerTitle');
  String get chatOfferAcceptedBannerBody => _get('chatOfferAcceptedBannerBody');
  String get chatStartActiveDeliveryButton =>
      _get('chatStartActiveDeliveryButton');
  String get chatJeeberRemovedMessage => _get('chatJeeberRemovedMessage');
  String chatBroadcastTtlLabel(int seconds) =>
      _get('chatBroadcastTtlLabel').replaceFirst('{seconds}', '$seconds');
  String chatVoiceNoteA11y(String author, int duration) => _get(
    'chatVoiceNoteA11y',
  ).replaceFirst('{author}', author).replaceFirst('{duration}', '$duration');
  String chatVoiceNoteTranscription(String text) =>
      _get('chatVoiceNoteTranscription').replaceFirst('{text}', text);
  String get chatVoiceNoteTranscriptionUnavailable =>
      _get('chatVoiceNoteTranscriptionUnavailable');
  String get chatVoiceNoteRecordingA11y => _get('chatVoiceNoteRecordingA11y');
  String get chatVoiceUploadFailed => _get('chatVoiceUploadFailed');
  String chatOfferEtaMinutes(int minutes) =>
      _get('chatOfferEtaMinutes').replaceFirst('{minutes}', '$minutes');
  String chatOfferRatingA11y(String rating) =>
      _get('chatOfferRatingA11y').replaceFirst('{rating}', rating);
  String get chatSystemOfferAcceptedGeneric =>
      _get('chatSystemOfferAcceptedGeneric');
  String chatSystemOfferAcceptedNamed(String name) =>
      _get('chatSystemOfferAcceptedNamed').replaceFirst('{name}', name);
  String get chatSystemOfferRejectedGeneric =>
      _get('chatSystemOfferRejectedGeneric');
  String chatSystemOfferRejectedNamed(String name) =>
      _get('chatSystemOfferRejectedNamed').replaceFirst('{name}', name);
  String get chatBroadcastingTitle => _get('chatBroadcastingTitle');
  String get chatBroadcastingSubtitle => _get('chatBroadcastingSubtitle');
  String get chatBroadcastingEmpty => _get('chatBroadcastingEmpty');
  String get chatDateChipToday => _get('chatDateChipToday');
  String get chatDateChipYesterday => _get('chatDateChipYesterday');
  String get chatOfferAcceptOnlyOne => _get('chatOfferAcceptOnlyOne');
  String get chatBackA11y => _get('chatBackA11y');
  String get chatAvatarA11y => _get('chatAvatarA11y');
  String get chatAttachA11y => _get('chatAttachA11y');
  String get chatVoiceA11y => _get('chatVoiceA11y');
  String get chatSendA11y => _get('chatSendA11y');
  String get chatMessageReadA11y => _get('chatMessageReadA11y');
  String get chatMessageSendingA11y => _get('chatMessageSendingA11y');
  String get chatMessageSentA11y => _get('chatMessageSentA11y');
  String get chatMessageDeliveredA11y => _get('chatMessageDeliveredA11y');
  String get chatMessageFailedA11y => _get('chatMessageFailedA11y');
  String chatPhotoA11y(String author) =>
      _get('chatPhotoA11y').replaceFirst('{author}', author);
  String chatImageA11y(String author) =>
      _get('chatImageA11y').replaceFirst('{author}', author);
  String get homeMicLabel => _get('homeMicLabel');
  String get homeRefreshHint => _get('homeRefreshHint');
  String get homeReorderAction => _get('homeReorderAction');
  String homeRequestEtaMinutes(int minutes) =>
      _get('homeRequestEtaMinutes').replaceFirst('{minutes}', '$minutes');

  String get requestStatusSearching => _get('requestStatusSearching');
  String get requestStatusOffers => _get('requestStatusOffers');
  String get requestStatusAccepted => _get('requestStatusAccepted');
  String get requestStatusPickup => _get('requestStatusPickup');
  String get requestStatusEnRoute => _get('requestStatusEnRoute');

  String get ordersTitle => _get('ordersTitle');
  String get ordersEmpty => _get('ordersEmpty');
  String get chatTitle => _get('chatTitle');
  String get chatEmpty => _get('chatEmpty');
  String get profileTitle => _get('profileTitle');
  String get dashboardTitle => _get('dashboardTitle');
  String get earningsTitle => _get('earningsTitle');
  String get earningsEmpty => _get('earningsEmpty');

  String get earningsPeriodToday => _get('earningsPeriodToday');
  String get earningsPeriodWeek => _get('earningsPeriodWeek');
  String get earningsPeriodMonth => _get('earningsPeriodMonth');
  String get earningsSummaryHeaderToday => _get('earningsSummaryHeaderToday');
  String get earningsSummaryHeaderWeek => _get('earningsSummaryHeaderWeek');
  String get earningsSummaryHeaderMonth => _get('earningsSummaryHeaderMonth');
  String get earningsSummaryEmpty => _get('earningsSummaryEmpty');
  String earningsSummaryCompleted(int count) {
    if (count == 0) return _get('earningsSummaryCompletedZero');
    if (count == 1) return _get('earningsSummaryCompletedOne');
    if (count == 2) return _get('earningsSummaryCompletedTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'earningsSummaryCompletedFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'earningsSummaryCompletedMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'earningsSummaryCompletedOther',
    ).replaceFirst('{count}', '$count');
  }

  String earningsSummaryTips(String amount) =>
      _get('earningsSummaryTips').replaceFirst('{amount}', amount);
  String earningsSummaryAverage(String amount) =>
      _get('earningsSummaryAverage').replaceFirst('{amount}', amount);
  String get earningsBreakdownTitle => _get('earningsBreakdownTitle');
  String get earningsBreakdownEmpty => _get('earningsBreakdownEmpty');
  String earningsBreakdownTipSuffix(String amount) =>
      _get('earningsBreakdownTipSuffix').replaceFirst('{amount}', amount);
  String get earningsLoadFailed => _get('earningsLoadFailed');
  String get earningsLoadRetry => _get('earningsLoadRetry');

  String get availabilityCardTitle => _get('availabilityCardTitle');
  String get availabilityToggleOnline => _get('availabilityToggleOnline');
  String get availabilityToggleOffline => _get('availabilityToggleOffline');
  String get availabilityStatusOnline => _get('availabilityStatusOnline');
  String get availabilityStatusOffline => _get('availabilityStatusOffline');
  String get availabilityStatusAutoOffline =>
      _get('availabilityStatusAutoOffline');
  String get availabilityAutoOfflineHint => _get('availabilityAutoOfflineHint');
  String get availabilityTransitioning => _get('availabilityTransitioning');
  String get availabilityIndicatorSemanticOnline =>
      _get('availabilityIndicatorSemanticOnline');
  String get availabilityIndicatorSemanticOffline =>
      _get('availabilityIndicatorSemanticOffline');
  String get availabilityIndicatorSemanticAutoOffline =>
      _get('availabilityIndicatorSemanticAutoOffline');
  String get availabilityAutoOfflineBannerTitle =>
      _get('availabilityAutoOfflineBannerTitle');
  String get availabilityAutoOfflineReasonPermission =>
      _get('availabilityAutoOfflineReasonPermission');
  String get availabilityAutoOfflineReasonNetwork =>
      _get('availabilityAutoOfflineReasonNetwork');
  String get availabilityAutoOfflineReasonBattery =>
      _get('availabilityAutoOfflineReasonBattery');
  String get availabilityAutoOfflineReasonIdle =>
      _get('availabilityAutoOfflineReasonIdle');
  String get availabilityAutoOfflineReasonServer =>
      _get('availabilityAutoOfflineReasonServer');
  String get availabilityAutoOfflineDismiss =>
      _get('availabilityAutoOfflineDismiss');
  String get availabilityAutoOfflineGoOnline =>
      _get('availabilityAutoOfflineGoOnline');
  String get availabilityPermissionDeniedHint =>
      _get('availabilityPermissionDeniedHint');

  String get settingsLanguage => _get('settingsLanguage');
  String get settingsRole => _get('settingsRole');
  String get settingsLanguageEnglish => _get('settingsLanguageEnglish');
  String get settingsLanguageArabic => _get('settingsLanguageArabic');
  String get settingsRoleClient => _get('settingsRoleClient');
  String get settingsRoleJeeber => _get('settingsRoleJeeber');

  String get roleToggleSemanticLabel => _get('roleToggleSemanticLabel');
  String get roleToggleKycLockedTitle => _get('roleToggleKycLockedTitle');
  String get roleToggleKycLockedBody => _get('roleToggleKycLockedBody');
  String get roleToggleKycLockedCta => _get('roleToggleKycLockedCta');
  String get roleToggleKycLockedDismiss => _get('roleToggleKycLockedDismiss');
  String get roleToggleActiveDeliveryBlocked =>
      _get('roleToggleActiveDeliveryBlocked');

  String get settingsTheme => _get('settingsTheme');
  String get settingsThemeSystem => _get('settingsThemeSystem');
  String get settingsThemeLight => _get('settingsThemeLight');
  String get settingsThemeDark => _get('settingsThemeDark');

  String get settingsTitle => _get('settingsTitle');
  String get settingsOpenSubtitle => _get('settingsOpenSubtitle');
  String get settingsProfileSection => _get('settingsProfileSection');
  String get settingsNotificationsSection =>
      _get('settingsNotificationsSection');
  String get settingsAddressesSection => _get('settingsAddressesSection');
  String get settingsSecuritySection => _get('settingsSecuritySection');
  String get settingsAccountSection => _get('settingsAccountSection');
  String get settingsAboutSection => _get('settingsAboutSection');
  String get settingsAppVersion => _get('settingsAppVersion');

  String get profileNamePlaceholder => _get('profileNamePlaceholder');
  String get profileEditTitle => _get('profileEditTitle');
  String get profileEditSubtitle => _get('profileEditSubtitle');
  String get profileNameLabel => _get('profileNameLabel');
  String get profileNameHint => _get('profileNameHint');
  String get profileNameRequired => _get('profileNameRequired');
  String get profileAvatarChange => _get('profileAvatarChange');
  String get profileAvatarRemove => _get('profileAvatarRemove');
  String get profileSave => _get('profileSave');
  String get profileSaving => _get('profileSaving');
  String get profileSaved => _get('profileSaved');

  // Post-OTP display-name onboarding step (profile-name lane).
  String get profileNameStepTitle => _get('profileNameStepTitle');
  String get profileNameStepSubtitle => _get('profileNameStepSubtitle');
  String get profileNameStepCta => _get('profileNameStepCta');
  String get profileNameStepSkip => _get('profileNameStepSkip');
  String get profileNameStepError => _get('profileNameStepError');

  String get notificationPreferencesTitle =>
      _get('notificationPreferencesTitle');
  String get notificationPreferencesRowSubtitle =>
      _get('notificationPreferencesRowSubtitle');
  String get notificationPreferencesCategoriesSection =>
      _get('notificationPreferencesCategoriesSection');
  String get notificationPreferencesSecuritySection =>
      _get('notificationPreferencesSecuritySection');
  String get notificationPreferencesDisableOffersTitle =>
      _get('notificationPreferencesDisableOffersTitle');
  String get notificationPreferencesDisableOffersBody =>
      _get('notificationPreferencesDisableOffersBody');
  String get notificationPreferencesDisableOffersConfirm =>
      _get('notificationPreferencesDisableOffersConfirm');

  // T-MOB-026: server-wired notification prefs (GET/PATCH /users/me/notification-preferences).
  String get notificationPrefsSaveError => _get('notificationPrefsSaveError');
  String get notificationPrefsLoadError => _get('notificationPrefsLoadError');
  String get notificationPrefsRetry => _get('notificationPrefsRetry');
  String get notificationTopicOffersSemanticLabel =>
      _get('notificationTopicOffersSemanticLabel');
  String get notificationTopicChatSemanticLabel =>
      _get('notificationTopicChatSemanticLabel');
  String get notificationTopicStatusChangesSemanticLabel =>
      _get('notificationTopicStatusChangesSemanticLabel');
  String get notificationTopicRatingRemindersSemanticLabel =>
      _get('notificationTopicRatingRemindersSemanticLabel');

  String get notificationCategoryOffers => _get('notificationCategoryOffers');
  String get notificationCategoryOffersSubtitle =>
      _get('notificationCategoryOffersSubtitle');
  String get notificationCategoryChat => _get('notificationCategoryChat');
  String get notificationCategoryChatSubtitle =>
      _get('notificationCategoryChatSubtitle');
  String get notificationCategoryStatus => _get('notificationCategoryStatus');
  String get notificationCategoryStatusSubtitle =>
      _get('notificationCategoryStatusSubtitle');
  String get notificationCategoryWallet => _get('notificationCategoryWallet');
  String get notificationCategoryWalletSubtitle =>
      _get('notificationCategoryWalletSubtitle');
  String get notificationCategoryRatingReminders =>
      _get('notificationCategoryRatingReminders');
  String get notificationCategoryRatingRemindersSubtitle =>
      _get('notificationCategoryRatingRemindersSubtitle');
  String get notificationCategoryOtp => _get('notificationCategoryOtp');
  String get notificationCategoryOtpAlwaysOn =>
      _get('notificationCategoryOtpAlwaysOn');

  String get savedAddressesTitle => _get('savedAddressesTitle');
  String get savedAddressesSubtitle => _get('savedAddressesSubtitle');
  String get savedAddressesEmptyTitle => _get('savedAddressesEmptyTitle');
  String get savedAddressesEmptyBody => _get('savedAddressesEmptyBody');
  String get savedAddressAdd => _get('savedAddressAdd');
  String get savedAddressEdit => _get('savedAddressEdit');
  String get savedAddressDelete => _get('savedAddressDelete');
  String get savedAddressLabelLabel => _get('savedAddressLabelLabel');
  String get savedAddressLabelHint => _get('savedAddressLabelHint');
  String get savedAddressLabelRequired => _get('savedAddressLabelRequired');
  String get savedAddressLineLabel => _get('savedAddressLineLabel');
  String get savedAddressDeleteConfirmTitle =>
      _get('savedAddressDeleteConfirmTitle');
  String savedAddressDeleteConfirmBody(String label) =>
      _get('savedAddressDeleteConfirmBody').replaceFirst('{label}', label);

  String get useBiometrics => _get('useBiometrics');
  String get biometricNotAvailable => _get('biometricNotAvailable');
  String get biometricRowTitle => _get('biometricRowTitle');
  String get biometricRowSubtitle => _get('biometricRowSubtitle');
  String get biometricLockTitle => _get('biometricLockTitle');
  String get biometricLockBody => _get('biometricLockBody');
  String get biometricLockRetry => _get('biometricLockRetry');
  String get biometricLockPrompting => _get('biometricLockPrompting');
  String get biometricLockFailure => _get('biometricLockFailure');
  String get biometricLockUsePin => _get('biometricLockUsePin');
  String get biometricPromptReason => _get('biometricPromptReason');
  String get biometricPromptSemanticLabel =>
      _get('biometricPromptSemanticLabel');
  String get biometricPinTitle => _get('biometricPinTitle');
  String get biometricPinSubtitle => _get('biometricPinSubtitle');
  String get biometricPinIncorrect => _get('biometricPinIncorrect');

  String get accountDeleteRow => _get('accountDeleteRow');
  String get accountDeleteSubtitle => _get('accountDeleteSubtitle');
  String get accountDeletePending => _get('accountDeletePending');
  String get accountDeleteDialogTitle => _get('accountDeleteDialogTitle');
  String accountDeleteDialogBody(int days) =>
      _get('accountDeleteDialogBody').replaceFirst('{days}', '$days');
  String get accountDeleteConfirm => _get('accountDeleteConfirm');
  String accountDeleteSubmitted(int days) =>
      _get('accountDeleteSubmitted').replaceFirst('{days}', '$days');

  String get actionSave => _get('actionSave');
  String get actionDelete => _get('actionDelete');

  String get actionContinue => _get('actionContinue');
  String get actionCancel => _get('actionCancel');
  String get actionNext => _get('actionNext');
  String get actionGetStarted => _get('actionGetStarted');
  String get actionSkip => _get('actionSkip');
  String get actionSignUp => _get('actionSignUp');

  String get onboardingChooseLanguage => _get('onboardingChooseLanguage');
  String get onboardingSlide1Title => _get('onboardingSlide1Title');
  String get onboardingSlide1Body => _get('onboardingSlide1Body');
  String get onboardingSlide2Title => _get('onboardingSlide2Title');
  String get onboardingSlide2Body => _get('onboardingSlide2Body');
  String get onboardingSlide3Title => _get('onboardingSlide3Title');
  String get onboardingSlide3Body => _get('onboardingSlide3Body');
  String get onboardingNext => _get('onboardingNext');
  String get onboardingGetStarted => _get('onboardingGetStarted');
  String get onboardingSkip => _get('onboardingSkip');
  String get onboardingLanguageEnglish => _get('onboardingLanguageEnglish');
  String get onboardingLanguageArabic => _get('onboardingLanguageArabic');
  String get onboardingSlide1Semantics => _get('onboardingSlide1Semantics');
  String get onboardingSlide2Semantics => _get('onboardingSlide2Semantics');
  String get onboardingSlide3Semantics => _get('onboardingSlide3Semantics');

  String deliveryDetailTitle(String id) =>
      _get('deliveryDetailTitle').replaceFirst('{id}', id);
  String get deliveryDetailPlaceholder => _get('deliveryDetailPlaceholder');
  String chatDetailTitle(String id) =>
      _get('chatDetailTitle').replaceFirst('{id}', id);
  String get chatDetailPlaceholder => _get('chatDetailPlaceholder');
  String get kycStatusTitle => _get('kycStatusTitle');
  String get kycStatusPlaceholder => _get('kycStatusPlaceholder');
  String get ratingPromptTitle => _get('ratingPromptTitle');
  String ratingPromptPlaceholder(String id) =>
      _get('ratingPromptPlaceholder').replaceFirst('{id}', id);

  String get ratingPromptHeadlineJeeber => _get('ratingPromptHeadlineJeeber');
  String get ratingPromptHeadlineClient => _get('ratingPromptHeadlineClient');
  String get ratingCaptionNone => _get('ratingCaptionNone');
  String get ratingCaption1 => _get('ratingCaption1');
  String get ratingCaption2 => _get('ratingCaption2');
  String get ratingCaption3 => _get('ratingCaption3');
  String get ratingCaption4 => _get('ratingCaption4');
  String get ratingCaption5 => _get('ratingCaption5');
  String get ratingCommentLabel => _get('ratingCommentLabel');
  String get ratingCommentHint => _get('ratingCommentHint');
  String get ratingSubmit => _get('ratingSubmit');
  String get ratingSubmitDone => _get('ratingSubmitDone');
  String get ratingLoadFailedTitle => _get('ratingLoadFailedTitle');
  String get ratingLoadFailedBody => _get('ratingLoadFailedBody');
  String get ratingLoadRetry => _get('ratingLoadRetry');
  String get ratingSubmitFailedBody => _get('ratingSubmitFailedBody');
  String ratingRevealBlindTitle(String name) =>
      _get('ratingRevealBlindTitle').replaceFirst('{name}', name);
  String get ratingRevealBlindBody => _get('ratingRevealBlindBody');
  String ratingRevealPendingTitle(String name) =>
      _get('ratingRevealPendingTitle').replaceFirst('{name}', name);
  String ratingRevealPendingBody(String name) =>
      _get('ratingRevealPendingBody').replaceAll('{name}', name);
  String ratingRevealRevealedTitle(String name) =>
      _get('ratingRevealRevealedTitle').replaceFirst('{name}', name);

  String get feedbackScreenTitle => _get('feedbackScreenTitle');
  String get feedbackScreenSubtitleJeeber =>
      _get('feedbackScreenSubtitleJeeber');
  String get feedbackScreenSubtitleClient =>
      _get('feedbackScreenSubtitleClient');
  String get feedbackCommentHint => _get('feedbackCommentHint');
  String feedbackRateName(String name) =>
      _get('feedbackRateName').replaceFirst('{name}', name);
  String get feedbackSubmit => _get('feedbackSubmit');
  String get feedbackCloseLabel => _get('feedbackCloseLabel');

  String get pushBannerDeliveryCategory => _get('pushBannerDeliveryCategory');
  String get pushBannerChatCategory => _get('pushBannerChatCategory');
  String get pushBannerKycCategory => _get('pushBannerKycCategory');
  String get pushBannerRatingCategory => _get('pushBannerRatingCategory');
  String get pushBannerJeeberMatchCategory =>
      _get('pushBannerJeeberMatchCategory');

  String get locationPickerTitle => _get('locationPickerTitle');
  String get locationModeGps => _get('locationModeGps');
  String get locationModeSearch => _get('locationModeSearch');
  String get locationModeMapPin => _get('locationModeMapPin');
  String get locationUseGpsCta => _get('locationUseGpsCta');
  String get locationSearchHint => _get('locationSearchHint');
  String get locationMapDragHint => _get('locationMapDragHint');
  String get locationSavedAddresses => _get('locationSavedAddresses');
  String get locationSave => _get('locationSave');
  String get locationSaved => _get('locationSaved');
  String get locationConfirm => _get('locationConfirm');
  String get locationPermissionDenied => _get('locationPermissionDenied');
  String get locationPermissionPermanentlyDenied =>
      _get('locationPermissionPermanentlyDenied');
  String get locationServiceDisabled => _get('locationServiceDisabled');
  String get locationUnknownError => _get('locationUnknownError');
  String get locationFallbackHint => _get('locationFallbackHint');
  String get locationMapPinSemanticLabel => _get('locationMapPinSemanticLabel');
  String locationRemoveSavedAddress(String label) =>
      _get('locationRemoveSavedAddress').replaceAll('{label}', label);

  String get voiceRequestTitle => _get('voiceRequestTitle');
  String get voiceRequestHoldToSpeak => _get('voiceRequestHoldToSpeak');
  String get voiceRequestReleaseToStop => _get('voiceRequestReleaseToStop');
  String get voiceRequestTapToRecord => _get('voiceRequestTapToRecord');
  String get voiceRequestRecording => _get('voiceRequestRecording');
  String get voiceRequestRecorded => _get('voiceRequestRecorded');
  String get voiceRequestSubmit => _get('voiceRequestSubmit');
  String get voiceRequestPlay => _get('voiceRequestPlay');
  String get voiceRequestPause => _get('voiceRequestPause');
  String get voiceRequestDiscard => _get('voiceRequestDiscard');
  String get voiceRequestMaxDurationToast =>
      _get('voiceRequestMaxDurationToast');
  String get voiceRequestMicButtonLabel => _get('voiceRequestMicButtonLabel');
  String get voiceRequestProcessing => _get('voiceRequestProcessing');
  String get voiceRequestMicProcessingSemanticLabel =>
      _get('voiceRequestMicProcessingSemanticLabel');

  String get transcriptionTitle => _get('transcriptionTitle');
  String get transcriptionHeader => _get('transcriptionHeader');
  String get transcriptionSubtitle => _get('transcriptionSubtitle');
  String get transcriptionFieldLabel => _get('transcriptionFieldLabel');
  String get transcriptionFieldHint => _get('transcriptionFieldHint');
  String get transcriptionPlayAudio => _get('transcriptionPlayAudio');
  String get transcriptionPauseAudio => _get('transcriptionPauseAudio');
  String get transcriptionSubmit => _get('transcriptionSubmit');
  String get transcriptionRetry => _get('transcriptionRetry');
  String get transcriptionQueuedTitle => _get('transcriptionQueuedTitle');
  String get transcriptionQueuedBody => _get('transcriptionQueuedBody');
  String get transcriptionFailedTitle => _get('transcriptionFailedTitle');
  String get transcriptionFailedNetwork => _get('transcriptionFailedNetwork');
  String get transcriptionFailedPayloadTooLarge =>
      _get('transcriptionFailedPayloadTooLarge');
  String get transcriptionFailedGeneric => _get('transcriptionFailedGeneric');
  String get transcriptionEdit => _get('transcriptionEdit');
  String get transcriptionSaveEdit => _get('transcriptionSaveEdit');
  String get transcriptionReRecord => _get('transcriptionReRecord');

  String photoAttachmentTitle(int count, int max) => _get(
    'photoAttachmentTitle',
  ).replaceFirst('{count}', '$count').replaceFirst('{max}', '$max');
  String get photoAttachmentAddLabel => _get('photoAttachmentAddLabel');
  String photoAttachmentRemoveLabel(int position) => _get(
    'photoAttachmentRemoveLabel',
  ).replaceFirst('{position}', '$position');
  String photoAttachmentMaxReached(int max) =>
      _get('photoAttachmentMaxReached').replaceFirst('{max}', '$max');
  String get photoAttachmentPermissionDenied =>
      _get('photoAttachmentPermissionDenied');
  String get photoAttachmentUnavailable => _get('photoAttachmentUnavailable');
  String get photoAttachmentCompressionFailed =>
      _get('photoAttachmentCompressionFailed');
  String get photoAttachmentSourceTitle => _get('photoAttachmentSourceTitle');
  String get photoAttachmentSourceCamera => _get('photoAttachmentSourceCamera');
  String get photoAttachmentSourceGallery =>
      _get('photoAttachmentSourceGallery');

  String get registrationContinueWithApple =>
      _get('registrationContinueWithApple');
  String get registrationContinueWithGoogle =>
      _get('registrationContinueWithGoogle');
  String get registrationSocialDivider => _get('registrationSocialDivider');
  String get registrationLinkPhoneTitle => _get('registrationLinkPhoneTitle');
  String get registrationLinkPhoneSubtitle =>
      _get('registrationLinkPhoneSubtitle');

  String get registrationPhoneTitle => _get('registrationPhoneTitle');
  String get registrationPhoneSubtitle => _get('registrationPhoneSubtitle');
  String get registrationPhoneHint => _get('registrationPhoneHint');
  String get registrationPhoneInvalid => _get('registrationPhoneInvalid');
  String get registrationSendCode => _get('registrationSendCode');
  String get registrationSending => _get('registrationSending');

  String get registrationOtpTitle => _get('registrationOtpTitle');
  String registrationOtpSubtitle(String phone) =>
      _get('registrationOtpSubtitle').replaceFirst('{phone}', phone);
  String get registrationOtpVerify => _get('registrationOtpVerify');
  String get registrationOtpVerifying => _get('registrationOtpVerifying');
  String get registrationOtpExpired => _get('registrationOtpExpired');
  String get registrationOtpInvalid => _get('registrationOtpInvalid');
  String get registrationOtpResend => _get('registrationOtpResend');
  String registrationOtpResendIn(int seconds) =>
      _get('registrationOtpResendIn').replaceFirst('{seconds}', '$seconds');
  String registrationOtpAttemptsRemaining(int remaining) => _get(
    'registrationOtpAttemptsRemaining',
  ).replaceFirst('{remaining}', '$remaining');
  String get registrationLockoutTitle => _get('registrationLockoutTitle');
  String registrationLockoutBody(String minutes, String seconds) => _get(
    'registrationLockoutBody',
  ).replaceFirst('{minutes}', minutes).replaceFirst('{seconds}', seconds);
  String get registrationChangePhone => _get('registrationChangePhone');

  // FR-LOGIN: branded register hero + welcome heading.
  String get registrationWelcome => _get('registrationWelcome');

  // FR-P0-4: super-login credential bottom sheet.
  String get superLoginTitle => _get('superLoginTitle');
  String get superLoginSubtitle => _get('superLoginSubtitle');
  String get superLoginUserId => _get('superLoginUserId');
  String get superLoginUserIdHint => _get('superLoginUserIdHint');
  String get superLoginPasscode => _get('superLoginPasscode');
  String get superLoginPasscodeHint => _get('superLoginPasscodeHint');
  String get superLoginSubmit => _get('superLoginSubmit');
  String get superLoginError => _get('superLoginError');
  String get superLoginNetworkError => _get('superLoginNetworkError');

  // "Super user login plus": demo-user picker that pre-fills the sheet.
  String get superLoginPlusTitle => _get('superLoginPlusTitle');
  String get superLoginPickerTitle => _get('superLoginPickerTitle');
  String get superLoginPickerSubtitle => _get('superLoginPickerSubtitle');
  String get superLoginPickerLoadingError =>
      _get('superLoginPickerLoadingError');
  String get superLoginPickerRetry => _get('superLoginPickerRetry');
  String get superLoginPickerRoleClient => _get('superLoginPickerRoleClient');
  String get superLoginPickerRoleJeeber => _get('superLoginPickerRoleJeeber');
  String get superLoginPickerSearchHint => _get('superLoginPickerSearchHint');
  String get superLoginPickerNoMatches => _get('superLoginPickerNoMatches');

  String get tierSelectionTitle => _get('tierSelectionTitle');
  String get tierSelectionSubtitle => _get('tierSelectionSubtitle');
  String get tierSelectionConfirm => _get('tierSelectionConfirm');
  String get tierSelectionWhatDifference => _get('tierSelectionWhatDifference');
  String get tierSelectionRecommendedBadge =>
      _get('tierSelectionRecommendedBadge');
  String get tierSelectionLocked => _get('tierSelectionLocked');
  String get tierSelectionCachedBanner => _get('tierSelectionCachedBanner');
  String get tierSelectionPriceLabel => _get('tierSelectionPriceLabel');
  String tierSelectionPriceRange(String low, String high) => _get(
    'tierSelectionPriceRange',
  ).replaceFirst('{low}', low).replaceFirst('{high}', high);
  String tierSelectionSlaMinutes(int minutes) =>
      _get('tierSelectionSlaMinutes').replaceFirst('{minutes}', '$minutes');
  String tierSelectionSlaHours(int hours) =>
      _get('tierSelectionSlaHours').replaceFirst('{hours}', '$hours');
  String get tierSelectionSlaNone => _get('tierSelectionSlaNone');
  String tierSelectionRadiusKm(int km) =>
      _get('tierSelectionRadiusKm').replaceFirst('{km}', '$km');
  String get tierSelectionTierFlash => _get('tierSelectionTierFlash');
  String get tierSelectionTierExpress => _get('tierSelectionTierExpress');
  String get tierSelectionTierStandard => _get('tierSelectionTierStandard');
  String get tierSelectionTierOnTheWay => _get('tierSelectionTierOnTheWay');
  String get tierSelectionTierEco => _get('tierSelectionTierEco');
  String get tierSelectionVehicleBikeScooter =>
      _get('tierSelectionVehicleBikeScooter');
  String get tierSelectionVehicleScooterCar =>
      _get('tierSelectionVehicleScooterCar');
  String get tierSelectionVehicleCarVan => _get('tierSelectionVehicleCarVan');
  String get tierSelectionVehicleAnyOpportunistic =>
      _get('tierSelectionVehicleAnyOpportunistic');
  String get tierSelectionVehicleAny => _get('tierSelectionVehicleAny');
  String get tierSelectionFooterFlash => _get('tierSelectionFooterFlash');
  String get tierSelectionFooterExpress => _get('tierSelectionFooterExpress');
  String get tierSelectionFooterStandard => _get('tierSelectionFooterStandard');
  String get tierSelectionFooterOnTheWay => _get('tierSelectionFooterOnTheWay');
  String get tierSelectionFooterEco => _get('tierSelectionFooterEco');
  String tierSelectionCardSemanticLabel({
    required String name,
    required String sla,
    required String radius,
    required String price,
  }) => _get('tierSelectionCardSemanticLabel')
      .replaceFirst('{name}', name)
      .replaceFirst('{sla}', sla)
      .replaceFirst('{radius}', radius)
      .replaceFirst('{price}', price);
  String get tierSelectionCardSelectedHint =>
      _get('tierSelectionCardSelectedHint');
  String get tierSelectionOnTheWayMvpNote =>
      _get('tierSelectionOnTheWayMvpNote');

  // Request type screen (Figma 56535:2392)
  String get requestTypeTitle => _get('requestTypeTitle');
  String get requestTypeChooseHeading => _get('requestTypeChooseHeading');
  String get requestTypeLocationHeading => _get('requestTypeLocationHeading');
  String get requestTypeCurrentLocation => _get('requestTypeCurrentLocation');
  String get requestTypeChangeLocation => _get('requestTypeChangeLocation');
  String get requestTypeContinue => _get('requestTypeContinue');
  String get tierFlashTitle => _get('tierFlashTitle');
  String get tierFlashSpeed => _get('tierFlashSpeed');
  String get tierFlashValue => _get('tierFlashValue');
  String get tierExpressTitle => _get('tierExpressTitle');
  String get tierExpressSpeed => _get('tierExpressSpeed');
  String get tierExpressValue => _get('tierExpressValue');
  String get tierStandardTitle => _get('tierStandardTitle');
  String get tierStandardSpeed => _get('tierStandardSpeed');
  String get tierStandardValue => _get('tierStandardValue');
  String get tierOnTheWayTitle => _get('tierOnTheWayTitle');
  String get tierOnTheWaySpeed => _get('tierOnTheWaySpeed');
  String get tierOnTheWayValue => _get('tierOnTheWayValue');
  String get tierEcoTitle => _get('tierEcoTitle');
  String get tierEcoSpeed => _get('tierEcoSpeed');
  String get tierEcoValue => _get('tierEcoValue');
  String requestTypeTierSemanticLabel({
    required String title,
    required String speed,
    required String value,
  }) => _get('requestTypeTierSemanticLabel')
      .replaceFirst('{title}', title)
      .replaceFirst('{speed}', speed)
      .replaceFirst('{value}', value);
  String get requestTypeTierSelectedHint => _get('requestTypeTierSelectedHint');

  // Client Location screen (Figma 56539:1444)
  String get clientLocationTitle => _get('clientLocationTitle');
  String get clientLocationHeading => _get('clientLocationHeading');
  String get clientLocationCurrentOption => _get('clientLocationCurrentOption');
  String get clientLocationNewOption => _get('clientLocationNewOption');
  String get clientLocationAddSemantic => _get('clientLocationAddSemantic');

  // JEBV4-176 (Q-060) — honest GPS-acquisition + recovery on the Current
  // Location option (no silent Beirut fallback).
  String get clientLocationGpsResolving => _get('clientLocationGpsResolving');
  String get clientLocationGpsResolved => _get('clientLocationGpsResolved');
  String get clientLocationGpsPermissionDeniedTitle =>
      _get('clientLocationGpsPermissionDeniedTitle');
  String get clientLocationGpsPermissionDeniedMessage =>
      _get('clientLocationGpsPermissionDeniedMessage');
  String get clientLocationGpsServiceDisabledTitle =>
      _get('clientLocationGpsServiceDisabledTitle');
  String get clientLocationGpsServiceDisabledMessage =>
      _get('clientLocationGpsServiceDisabledMessage');
  String get clientLocationGpsFailedTitle =>
      _get('clientLocationGpsFailedTitle');
  String get clientLocationGpsFailedMessage =>
      _get('clientLocationGpsFailedMessage');
  String get clientLocationGpsRetry => _get('clientLocationGpsRetry');
  String get clientLocationGpsOpenAppSettings =>
      _get('clientLocationGpsOpenAppSettings');
  String get clientLocationGpsOpenLocationSettings =>
      _get('clientLocationGpsOpenLocationSettings');

  // Recipient-phone capture on the location-confirm step (iter6 OTP-phone v2).
  String get recipientPhoneLabel => _get('recipientPhoneLabel');
  String get recipientPhoneHint => _get('recipientPhoneHint');
  String get recipientPhoneHelper => _get('recipientPhoneHelper');
  String get recipientPhoneInvalid => _get('recipientPhoneInvalid');

  // G1 (sprint-009 P0): "What do you need?" compose block on the
  // location-confirm step — the customer's request content.
  String get composeDescriptionHeading => _get('composeDescriptionHeading');
  String get composeDescriptionHint => _get('composeDescriptionHint');
  String get composeDescriptionHelper => _get('composeDescriptionHelper');
  String get composeDescriptionRequired => _get('composeDescriptionRequired');
  String get composeDescriptionMicSemantic =>
      _get('composeDescriptionMicSemantic');

  // G1: customer-side echo of the request content on the waiting screen.
  String get waitingRequestSummaryLabel => _get('waitingRequestSummaryLabel');

  // Capture Location screen (Figma 56546:2303)
  String get captureLocationTitle => _get('captureLocationTitle');
  String get captureLocationPinCta => _get('captureLocationPinCta');
  String get captureLocationMapSemantic => _get('captureLocationMapSemantic');
  String get captureLocationPinSemantic => _get('captureLocationPinSemantic');
  String get captureLocationMapPreview => _get('captureLocationMapPreview');
  // T-MOB-012: "centre map on current GPS" button (maps wiring).
  String get captureLocationMyLocation => _get('captureLocationMyLocation');

  // T-MOB-012: GPS denied + outside service area (AC4/AC5)
  String get captureLocationGpsDeniedTitle =>
      _get('captureLocationGpsDeniedTitle');
  String get captureLocationGpsDeniedBody =>
      _get('captureLocationGpsDeniedBody');
  String get captureLocationGpsDeniedOpenSettings =>
      _get('captureLocationGpsDeniedOpenSettings');
  String get captureLocationOutsideServiceArea =>
      _get('captureLocationOutsideServiceArea');

  // T-MOB-012: Saved locations chip row
  String get savedLocationsTitle => _get('savedLocationsTitle');
  String get savedLocationsChipHome => _get('savedLocationsChipHome');
  String get savedLocationsChipWork => _get('savedLocationsChipWork');
  String get savedLocationsChipOther => _get('savedLocationsChipOther');
  String get savedLocationsEmpty => _get('savedLocationsEmpty');
  String get savedLocationsSaveSheetTitle =>
      _get('savedLocationsSaveSheetTitle');
  String get savedLocationsSaveSheetSave => _get('savedLocationsSaveSheetSave');
  String get savedLocationsSaveSheetSkip => _get('savedLocationsSaveSheetSkip');
  String get savedLocationsNameHint => _get('savedLocationsNameHint');

  // KYC wizard
  String get kycWizardTitle => _get('kycWizardTitle');
  String kycWizardProgressLabel({required int current, required int total}) =>
      _get(
        'kycWizardProgressLabel',
      ).replaceFirst('{current}', '$current').replaceFirst('{total}', '$total');
  String get kycWizardStepIdLabel => _get('kycWizardStepIdLabel');
  String get kycWizardStepSelfieLabel => _get('kycWizardStepSelfieLabel');
  String get kycWizardBack => _get('kycWizardBack');
  String get kycWizardNext => _get('kycWizardNext');
  String get kycWizardSubmit => _get('kycWizardSubmit');
  String get kycWizardSubmitting => _get('kycWizardSubmitting');
  String get kycSubmittingTitle => _get('kycSubmittingTitle');
  String get kycSubmittingBody => _get('kycSubmittingBody');

  String get kycIdStepTitle => _get('kycIdStepTitle');
  String get kycIdStepSubtitle => _get('kycIdStepSubtitle');
  String get kycIdAlignmentGuideTitle => _get('kycIdAlignmentGuideTitle');
  String get kycIdAlignmentGuideCaption => _get('kycIdAlignmentGuideCaption');
  String get kycIdFrontLabel => _get('kycIdFrontLabel');
  String get kycIdBackLabel => _get('kycIdBackLabel');
  String get kycIdRetake => _get('kycIdRetake');
  String get kycIdCaptureCta => _get('kycIdCaptureCta');
  String get kycIdTypeLabel => _get('kycIdTypeLabel');
  String get kycIdTypeNationalId => _get('kycIdTypeNationalId');
  String get kycIdTypePassport => _get('kycIdTypePassport');
  String get kycIdTypeResidency => _get('kycIdTypeResidency');
  String get kycIdTypeInvalid => _get('kycIdTypeInvalid');
  String get kycIdNumberLabel => _get('kycIdNumberLabel');
  String get kycIdNumberLabelPassport => _get('kycIdNumberLabelPassport');
  String get kycIdNumberLabelResidency => _get('kycIdNumberLabelResidency');
  String get kycIdNumberHint => _get('kycIdNumberHint');
  String get kycIdNumberHintDocument => _get('kycIdNumberHintDocument');
  String get kycIdNumberRequired => _get('kycIdNumberRequired');
  String get kycIdNumberInvalid => _get('kycIdNumberInvalid');
  String get kycIdNumberRejected => _get('kycIdNumberRejected');

  String get kycSelfieStepTitle => _get('kycSelfieStepTitle');
  String get kycSelfieStepSubtitle => _get('kycSelfieStepSubtitle');
  String get kycSelfieLivenessPrompt => _get('kycSelfieLivenessPrompt');
  String get kycSelfieLivenessBlink => _get('kycSelfieLivenessBlink');
  String get kycSelfieLivenessSmile => _get('kycSelfieLivenessSmile');
  String get kycSelfieRetake => _get('kycSelfieRetake');
  String get kycSelfieCaptureCta => _get('kycSelfieCaptureCta');

  String get kycStatusPendingTitle => _get('kycStatusPendingTitle');
  String get kycStatusPendingBody => _get('kycStatusPendingBody');
  String get kycStatusApprovedTitle => _get('kycStatusApprovedTitle');
  String get kycStatusApprovedBody => _get('kycStatusApprovedBody');
  String get kycStatusRejectedTitle => _get('kycStatusRejectedTitle');
  String get kycStatusRejectedBody => _get('kycStatusRejectedBody');
  String get kycStatusResubmitTitle => _get('kycStatusResubmitTitle');
  String get kycStatusResubmitBody => _get('kycStatusResubmitBody');
  String get kycStatusResubmitRequestedCta =>
      _get('kycStatusResubmitRequestedCta');
  String get kycResubmitStepIdFront => _get('kycResubmitStepIdFront');
  String get kycResubmitStepIdBack => _get('kycResubmitStepIdBack');
  String get kycResubmitStepSelfie => _get('kycResubmitStepSelfie');
  String get kycResubmitStepIdNumber => _get('kycResubmitStepIdNumber');
  String get kycResubmitStepOther => _get('kycResubmitStepOther');
  String get kycStatusBackToProfileCta => _get('kycStatusBackToProfileCta');

  String get kycRejectionReasonIdUnreadable =>
      _get('kycRejectionReasonIdUnreadable');
  String get kycRejectionReasonSelfieMismatch =>
      _get('kycRejectionReasonSelfieMismatch');
  String get kycRejectionReasonExpired => _get('kycRejectionReasonExpired');
  String get kycRejectionReasonOther => _get('kycRejectionReasonOther');

  // T-MOB-013: schema-driven KYC — ToS step + new error strings.
  String get kycTosStepTitle => _get('kycTosStepTitle');
  String get kycTosStepSubtitle => _get('kycTosStepSubtitle');
  String kycTosVersionLabel({required String version}) =>
      _get('kycTosVersionLabel').replaceFirst('{version}', version);
  String get kycTosDocumentTitle => _get('kycTosDocumentTitle');
  String get kycTosDocumentBody => _get('kycTosDocumentBody');
  String get kycTosSignatureLabel => _get('kycTosSignatureLabel');
  String get kycTosSignatureHint => _get('kycTosSignatureHint');
  String get kycTosSignatureRecorded => _get('kycTosSignatureRecorded');
  String get kycTosSignatureClear => _get('kycTosSignatureClear');
  String get kycTosSignaturePadSemanticLabel =>
      _get('kycTosSignaturePadSemanticLabel');
  String get kycTosSignAndSubmit => _get('kycTosSignAndSubmit');
  String get kycRetry => _get('kycRetry');
  String get kycErrorSchemaLoadFailed => _get('kycErrorSchemaLoadFailed');
  String get kycErrorContractLoadFailed => _get('kycErrorContractLoadFailed');
  String get kycErrorSignFailed => _get('kycErrorSignFailed');
  String get kycErrorFileTooLarge => _get('kycErrorFileTooLarge');
  String get kycErrorFileTypeNotAllowed => _get('kycErrorFileTypeNotAllowed');

  String get kycErrorPermissionDenied => _get('kycErrorPermissionDenied');
  String get kycErrorUnavailable => _get('kycErrorUnavailable');
  String get kycErrorCompressionFailed => _get('kycErrorCompressionFailed');
  String get kycErrorSubmitFailed => _get('kycErrorSubmitFailed');
  String get kycErrorSubmitValidationFailed =>
      _get('kycErrorSubmitValidationFailed');
  String get kycScrollForSelfieHint => _get('kycScrollForSelfieHint');

  String get profileKycSectionTitle => _get('profileKycSectionTitle');
  String get profileKycStatusNotSubmitted =>
      _get('profileKycStatusNotSubmitted');
  String get profileKycStatusPending => _get('profileKycStatusPending');
  String get profileKycStatusApproved => _get('profileKycStatusApproved');
  String get profileKycStatusRejected => _get('profileKycStatusRejected');
  String get profileKycStartCta => _get('profileKycStartCta');
  String get profileKycViewCta => _get('profileKycViewCta');

  // Jeeber dashboard (T-mobile-039).
  String get dashboardTodayEarningsTitle => _get('dashboardTodayEarningsTitle');
  String get dashboardTodayEarningsEmpty => _get('dashboardTodayEarningsEmpty');
  String dashboardTodayEarningsTips(String amount) =>
      _get('dashboardTodayEarningsTips').replaceFirst('{amount}', amount);
  String dashboardTodayEarningsCompleted(int count) {
    if (count == 0) return _get('dashboardTodayEarningsCompletedZero');
    if (count == 1) return _get('dashboardTodayEarningsCompletedOne');
    if (count == 2) return _get('dashboardTodayEarningsCompletedTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'dashboardTodayEarningsCompletedFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'dashboardTodayEarningsCompletedMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'dashboardTodayEarningsCompletedOther',
    ).replaceFirst('{count}', '$count');
  }

  String get dashboardActiveDeliveryTitle =>
      _get('dashboardActiveDeliveryTitle');
  String get dashboardActiveDeliveryStageEnRoutePickup =>
      _get('dashboardActiveDeliveryStageEnRoutePickup');
  String get dashboardActiveDeliveryStageAtPickup =>
      _get('dashboardActiveDeliveryStageAtPickup');
  String get dashboardActiveDeliveryStageEnRouteDropoff =>
      _get('dashboardActiveDeliveryStageEnRouteDropoff');
  String get dashboardActiveDeliveryStageAtDropoff =>
      _get('dashboardActiveDeliveryStageAtDropoff');
  String dashboardActiveDeliveryEta(int minutes) =>
      _get('dashboardActiveDeliveryEta').replaceFirst('{minutes}', '$minutes');
  String get dashboardActiveDeliveryOpen => _get('dashboardActiveDeliveryOpen');
  String get dashboardActiveDeliveryMessage =>
      _get('dashboardActiveDeliveryMessage');

  String get dashboardRecentCompletionsTitle =>
      _get('dashboardRecentCompletionsTitle');
  String get dashboardRecentCompletionsEmpty =>
      _get('dashboardRecentCompletionsEmpty');

  String dashboardNearbyRequestsCount(int count) {
    if (count == 0) return _get('dashboardNearbyRequestsZero');
    if (count == 1) return _get('dashboardNearbyRequestsOne');
    if (count == 2) return _get('dashboardNearbyRequestsTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'dashboardNearbyRequestsFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'dashboardNearbyRequestsMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'dashboardNearbyRequestsOther',
    ).replaceFirst('{count}', '$count');
  }

  String get dashboardNearbyRequestsOfflineHint =>
      _get('dashboardNearbyRequestsOfflineHint');

  // Jeeber request feed + incoming match prompt (T-mobile-013)
  String get jeeberFeedSectionTitle => _get('jeeberFeedSectionTitle');
  String get jeeberFeedEmpty => _get('jeeberFeedEmpty');
  String jeeberFeedDistance(String distance) =>
      _get('jeeberFeedDistance').replaceFirst('{distance}', distance);
  String jeeberFeedClientRatingReviews(int count) =>
      _get('jeeberFeedClientRatingReviews').replaceFirst('{count}', '$count');
  String get jeeberFeedSearchHint => _get('jeeberFeedSearchHint');
  String get jeeberFeedFilterRequests => _get('jeeberFeedFilterRequests');
  String get jeeberFeedFilterPendingResponse =>
      _get('jeeberFeedFilterPendingResponse');
  String get jeeberFeedFilterReplies => _get('jeeberFeedFilterReplies');
  String get jeeberFeedIgnoreAction => _get('jeeberFeedIgnoreAction');
  String get jeeberFeedOfferAction => _get('jeeberFeedOfferAction');
  String get jeeberFeedAnonymousClient => _get('jeeberFeedAnonymousClient');
  String jeeberFeedDistanceAway(String distance) =>
      _get('jeeberFeedDistanceAway').replaceFirst('{distance}', distance);
  String get jeeberFeedStatusPending => _get('jeeberFeedStatusPending');
  String get jeeberFeedStatusExpired => _get('jeeberFeedStatusExpired');
  String get jeeberFeedActionHeadingToDropOff =>
      _get('jeeberFeedActionHeadingToDropOff');
  String get jeeberFeedAcceptOrdersLabel => _get('jeeberFeedAcceptOrdersLabel');
  String get jeeberFeedEmptyTitle => _get('jeeberFeedEmptyTitle');
  String get jeeberFeedEmptySubtitle => _get('jeeberFeedEmptySubtitle');
  String jeeberFeedRatingSemantic(String rating) =>
      _get('jeeberFeedRatingSemantic').replaceFirst('{rating}', rating);
  String get requestFeedTierFlash => _get('requestFeedTierFlash');
  String get jeeberIncomingMatchTitle => _get('jeeberIncomingMatchTitle');
  String get jeeberIncomingMatchAccept => _get('jeeberIncomingMatchAccept');
  String get jeeberIncomingMatchDecline => _get('jeeberIncomingMatchDecline');
  String jeeberIncomingMatchCountdown(int seconds) => _get(
    'jeeberIncomingMatchCountdown',
  ).replaceFirst('{seconds}', '$seconds');

  // Request summary (T-mobile-012)
  String get requestSummaryTitle => _get('requestSummaryTitle');
  String get requestSummarySectionDescription =>
      _get('requestSummarySectionDescription');
  String get requestSummarySectionPhotos => _get('requestSummarySectionPhotos');
  String get requestSummarySectionTier => _get('requestSummarySectionTier');
  String get requestSummarySectionPickup => _get('requestSummarySectionPickup');
  String get requestSummarySectionDropoff =>
      _get('requestSummarySectionDropoff');
  String get requestSummaryDescriptionEmpty =>
      _get('requestSummaryDescriptionEmpty');
  String get requestSummaryPhotosEmpty => _get('requestSummaryPhotosEmpty');
  String get requestSummarySectionTranscription =>
      _get('requestSummarySectionTranscription');
  String requestSummaryPhotosAttached(int count) =>
      _get('requestSummaryPhotosAttached').replaceFirst('{count}', '$count');
  String get requestSummarySubmit => _get('requestSummarySubmit');
  String get requestSummaryRetry => _get('requestSummaryRetry');
  String get requestSummaryErrorNetwork => _get('requestSummaryErrorNetwork');
  String get requestSummaryErrorGeneric => _get('requestSummaryErrorGeneric');

  String get requestSummaryProhibitedTitle =>
      _get('requestSummaryProhibitedTitle');
  String get requestSummaryProhibitedIntro =>
      _get('requestSummaryProhibitedIntro');
  String get requestSummaryProhibitedItemWeapons =>
      _get('requestSummaryProhibitedItemWeapons');
  String get requestSummaryProhibitedItemDrugs =>
      _get('requestSummaryProhibitedItemDrugs');
  String get requestSummaryProhibitedItemHazardous =>
      _get('requestSummaryProhibitedItemHazardous');
  String get requestSummaryProhibitedItemLiveAnimals =>
      _get('requestSummaryProhibitedItemLiveAnimals');
  String get requestSummaryProhibitedItemCash =>
      _get('requestSummaryProhibitedItemCash');
  String get requestSummaryProhibitedAcknowledge =>
      _get('requestSummaryProhibitedAcknowledge');
  String get requestSummaryProhibitedConfirm =>
      _get('requestSummaryProhibitedConfirm');

  String get requestSummaryFindingTitle => _get('requestSummaryFindingTitle');
  String requestSummaryFindingNotifiedCount(int count) {
    if (count == 0) return _get('requestSummaryFindingNotifiedZero');
    if (count == 1) return _get('requestSummaryFindingNotifiedOne');
    if (count == 2) return _get('requestSummaryFindingNotifiedTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'requestSummaryFindingNotifiedFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'requestSummaryFindingNotifiedMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'requestSummaryFindingNotifiedOther',
    ).replaceFirst('{count}', '$count');
  }

  String get requestSummaryFindingHint => _get('requestSummaryFindingHint');

  // No-offer timeout / expired-request banners (T-mobile-035)
  String get requestSummaryNoOffersTitle => _get('requestSummaryNoOffersTitle');
  String get requestSummaryNoOffersBody => _get('requestSummaryNoOffersBody');
  String requestSummaryExpandToTier(String tier) =>
      _get('requestSummaryExpandToTier').replaceFirst('{tier}', tier);
  String get requestSummaryExpiredTitle => _get('requestSummaryExpiredTitle');
  String get requestSummaryExpiredBody => _get('requestSummaryExpiredBody');
  String get requestSummaryReRequest => _get('requestSummaryReRequest');
  // Shown when /request-summary is reached without a draft (e.g. a cold
  // deep-link), replacing a raw scaffold with hardcoded English.
  String get requestSummaryUnavailableTitle =>
      _get('requestSummaryUnavailableTitle');
  String get requestSummaryUnavailableBody =>
      _get('requestSummaryUnavailableBody');

  String requestNoLongerAvailable(String requestId) =>
      _get('requestNoLongerAvailable').replaceFirst('{requestId}', requestId);
  String get requestUnavailableTitle => _get('requestUnavailableTitle');
  String get requestUnavailableBrowseCta => _get('requestUnavailableBrowseCta');
  String get jeeberRequestDetailTitle => _get('jeeberRequestDetailTitle');
  String get jeeberRequestDetailSectionPickup =>
      _get('jeeberRequestDetailSectionPickup');
  String get jeeberRequestDetailSectionDropoff =>
      _get('jeeberRequestDetailSectionDropoff');
  String get jeeberRequestDetailSectionDescription =>
      _get('jeeberRequestDetailSectionDescription');
  String get jeeberRequestDetailRequestSection =>
      _get('jeeberRequestDetailRequestSection');
  String get jeeberRequestDetailReference =>
      _get('jeeberRequestDetailReference');
  String jeeberRequestDetailDistance(String distance) =>
      _get('jeeberRequestDetailDistance').replaceFirst('{distance}', distance);
  String get jeeberRequestDetailReportButton =>
      _get('jeeberRequestDetailReportButton');
  String get jeeberRequestDetailReportHint =>
      _get('jeeberRequestDetailReportHint');
  String get jeeberRequestDetailDeclineButton =>
      _get('jeeberRequestDetailDeclineButton');
  String get jeeberRequestDetailDeclineWithoutPenaltyButton =>
      _get('jeeberRequestDetailDeclineWithoutPenaltyButton');
  String get jeeberRequestDetailReportConfirmTitle =>
      _get('jeeberRequestDetailReportConfirmTitle');
  String get jeeberRequestDetailReportConfirmBody =>
      _get('jeeberRequestDetailReportConfirmBody');
  String get jeeberRequestDetailReportConfirmAction =>
      _get('jeeberRequestDetailReportConfirmAction');
  String get jeeberRequestDetailReportedTitle =>
      _get('jeeberRequestDetailReportedTitle');
  String get jeeberRequestDetailReportedBody =>
      _get('jeeberRequestDetailReportedBody');
  String get jeeberRequestDetailReportErrorNetwork =>
      _get('jeeberRequestDetailReportErrorNetwork');
  String get jeeberRequestDetailReportErrorGeneric =>
      _get('jeeberRequestDetailReportErrorGeneric');
  String get jeeberRequestUnavailableTitle =>
      _get('jeeberRequestUnavailableTitle');
  String get jeeberRequestUnavailableBody =>
      _get('jeeberRequestUnavailableBody');
  String get jeeberRequestUnavailableBackToFeed =>
      _get('jeeberRequestUnavailableBackToFeed');

  String get offersPanelHeader => _get('offersPanelHeader');
  String get offersPanelStillSearching => _get('offersPanelStillSearching');
  String offersCardEtaMinutes(int minutes) =>
      _get('offersCardEtaMinutes').replaceFirst('{minutes}', '$minutes');
  String offersCardFee(String amount, String currency) => _get(
    'offersCardFee',
  ).replaceFirst('{amount}', amount).replaceFirst('{currency}', currency);
  String get offersCardVehicleCar => _get('offersCardVehicleCar');
  String get offersCardVehicleMotorcycle => _get('offersCardVehicleMotorcycle');
  String get offersCardVehicleBicycle => _get('offersCardVehicleBicycle');
  String get offersCardVehicleScooter => _get('offersCardVehicleScooter');
  String get offersCardVehicleWalker => _get('offersCardVehicleWalker');
  String get offersCardVehicleVan => _get('offersCardVehicleVan');
  String get offersCardAccept => _get('offersCardAccept');
  String get offersCardAccepting => _get('offersCardAccepting');
  String offersCardSemanticLabel({
    required String name,
    required String rating,
    required String vehicle,
    required String fee,
    required String currency,
    required int minutes,
  }) => _get('offersCardSemanticLabel')
      .replaceFirst('{name}', name)
      .replaceFirst('{rating}', rating)
      .replaceFirst('{vehicle}', vehicle)
      .replaceFirst('{fee}', fee)
      .replaceFirst('{currency}', currency)
      .replaceFirst('{minutes}', '$minutes');
  // W6/SW-08 offer identity: honest name + rating fallbacks (never a UUID name
  // or a fabricated "4.5 (0)").
  String get offersCardJeeberFallback => _get('offersCardJeeberFallback');
  String get offersCardNoRatingsYet => _get('offersCardNoRatingsYet');
  String offersCardSemanticLabelUnrated({
    required String name,
    required String vehicle,
    required String fee,
    required String currency,
    required int minutes,
  }) => _get('offersCardSemanticLabelUnrated')
      .replaceFirst('{name}', name)
      .replaceFirst('{vehicle}', vehicle)
      .replaceFirst('{fee}', fee)
      .replaceFirst('{currency}', currency)
      .replaceFirst('{minutes}', '$minutes');
  String get offersHighFeeDialogTitle => _get('offersHighFeeDialogTitle');
  String offersHighFeeDialogBody(String amount, String currency) => _get(
    'offersHighFeeDialogBody',
  ).replaceFirst('{amount}', amount).replaceFirst('{currency}', currency);
  String get offersHighFeeDialogConfirm => _get('offersHighFeeDialogConfirm');
  String get offersHighFeeDialogCancel => _get('offersHighFeeDialogCancel');
  String get offersErrorNetwork => _get('offersErrorNetwork');
  String get offersErrorRequestNotOpen => _get('offersErrorRequestNotOpen');
  String get offersErrorOfferNotPending => _get('offersErrorOfferNotPending');
  String get offersErrorJeeberAtCapacity => _get('offersErrorJeeberAtCapacity');
  String get offersErrorGeneric => _get('offersErrorGeneric');
  String get offersLoadErrorGeneric => _get('offersLoadErrorGeneric');
  String get offersAcceptedBannerTitle => _get('offersAcceptedBannerTitle');
  String get offersAcceptedBannerBody => _get('offersAcceptedBannerBody');
  // JM-028 offer-review additions.
  String offerCardCashOnDelivery(String amount, String currency) => _get(
    'offerCardCashOnDelivery',
  ).replaceFirst('{amount}', amount).replaceFirst('{currency}', currency);
  String get offerReviewCancelCta => _get('offerReviewCancelCta');
  // JM-030 cancel-request-confirm sheet body (D69). Getter added by JM-028 to
  // unblock the shared cancel sheet it invokes; the JM-030 engineer owns it.
  String get cancelRequestFreeNote => _get('cancelRequestFreeNote');
  // cycle-4 typed cancel errors (DELETE /v1/requests/{id}): 409 conflict copy
  // + the generic 404/403/5xx fallback. Network reuses loginNetworkError.
  String get cancelRequestErrorConflict => _get('cancelRequestErrorConflict');
  String get cancelRequestErrorGeneric => _get('cancelRequestErrorGeneric');

  String get offerSubmissionTitle => _get('offerSubmissionTitle');
  String get offerSubmissionIntro => _get('offerSubmissionIntro');
  String get offerSubmissionFeeLabel => _get('offerSubmissionFeeLabel');
  String get offerSubmissionFeeHint => _get('offerSubmissionFeeHint');
  String offerSubmissionFeeHelper(String minimum, String currency) => _get(
    'offerSubmissionFeeHelper',
  ).replaceFirst('{minimum}', minimum).replaceFirst('{currency}', currency);
  String get offerSubmissionFeeErrorRequired =>
      _get('offerSubmissionFeeErrorRequired');
  String offerSubmissionFeeErrorBelowMinimum(String minimum, String currency) =>
      _get(
        'offerSubmissionFeeErrorBelowMinimum',
      ).replaceFirst('{minimum}', minimum).replaceFirst('{currency}', currency);
  String offerSubmissionFeeErrorAboveMaximum(String maximum, String currency) =>
      _get(
        'offerSubmissionFeeErrorAboveMaximum',
      ).replaceFirst('{maximum}', maximum).replaceFirst('{currency}', currency);
  String get offerSubmissionEtaLabel => _get('offerSubmissionEtaLabel');
  String get offerSubmissionEtaHint => _get('offerSubmissionEtaHint');
  String get offerSubmissionEtaSuffix => _get('offerSubmissionEtaSuffix');
  String offerSubmissionEtaHelper(int min, int max) => _get(
    'offerSubmissionEtaHelper',
  ).replaceFirst('{min}', '$min').replaceFirst('{max}', '$max');
  String get offerSubmissionEtaErrorRequired =>
      _get('offerSubmissionEtaErrorRequired');
  String offerSubmissionEtaErrorBelowMinimum(int min) =>
      _get('offerSubmissionEtaErrorBelowMinimum').replaceFirst('{min}', '$min');
  String offerSubmissionEtaErrorAboveMaximum(int max) =>
      _get('offerSubmissionEtaErrorAboveMaximum').replaceFirst('{max}', '$max');
  String get offerSubmissionNoteLabel => _get('offerSubmissionNoteLabel');
  String get offerSubmissionNoteHint => _get('offerSubmissionNoteHint');
  String offerSubmissionNoteErrorTooLong(int max) =>
      _get('offerSubmissionNoteErrorTooLong').replaceFirst('{max}', '$max');
  String get offerSubmissionSubmitButton => _get('offerSubmissionSubmitButton');
  String get offerSubmissionSubmittingButton =>
      _get('offerSubmissionSubmittingButton');
  String get offerSubmissionRetryButton => _get('offerSubmissionRetryButton');
  String get offerSubmissionConfirmedTitle =>
      _get('offerSubmissionConfirmedTitle');
  String get offerSubmissionConfirmedBody =>
      _get('offerSubmissionConfirmedBody');
  String offerSubmissionConfirmedFee(String amount, String currency) => _get(
    'offerSubmissionConfirmedFee',
  ).replaceFirst('{amount}', amount).replaceFirst('{currency}', currency);
  String offerSubmissionConfirmedEta(int minutes) =>
      _get('offerSubmissionConfirmedEta').replaceFirst('{minutes}', '$minutes');
  String get offerSubmissionWithdrawButton =>
      _get('offerSubmissionWithdrawButton');
  String get offerSubmissionWithdrawingButton =>
      _get('offerSubmissionWithdrawingButton');
  String get offerSubmissionWithdrawnTitle =>
      _get('offerSubmissionWithdrawnTitle');
  String get offerSubmissionWithdrawnBody =>
      _get('offerSubmissionWithdrawnBody');
  String get offerSubmissionErrorNetwork => _get('offerSubmissionErrorNetwork');
  String get offerSubmissionErrorRequestNotOpen =>
      _get('offerSubmissionErrorRequestNotOpen');
  String get offerSubmissionErrorDuplicate =>
      _get('offerSubmissionErrorDuplicate');
  String get offerSubmissionErrorGeneric => _get('offerSubmissionErrorGeneric');
  String get offerSubmissionWithdrawErrorNetwork =>
      _get('offerSubmissionWithdrawErrorNetwork');
  String get offerSubmissionWithdrawErrorGeneric =>
      _get('offerSubmissionWithdrawErrorGeneric');

  String get trackingTitle => _get('trackingTitle');
  String get trackingStepOrdered => _get('trackingStepOrdered');
  String get trackingStepPicked => _get('trackingStepPicked');
  String get trackingStepInTransit => _get('trackingStepInTransit');
  String trackingDistanceAway(String distance) =>
      _get('trackingDistanceAway').replaceFirst('{distance}', distance);
  String trackingEstimatedTime(int minutes) =>
      _get('trackingEstimatedTime').replaceFirst('{minutes}', '$minutes');
  String get trackingDistanceUnknown => _get('trackingDistanceUnknown');
  String get trackingEtaUnknown => _get('trackingEtaUnknown');
  String trackingDeadlineLocked(String time) =>
      _get('trackingDeadlineLocked').replaceFirst('{time}', time);
  String get trackingMapSemanticLabel => _get('trackingMapSemanticLabel');
  String get trackingStepAccepted => _get('trackingStepAccepted');
  String get trackingStepPickedUp => _get('trackingStepPickedUp');
  String get trackingStepHeadingOff => _get('trackingStepHeadingOff');
  String get trackingStepCompleted => _get('trackingStepCompleted');
  String get trackingEtaLabel => _get('trackingEtaLabel');
  String get trackingEtaPaused => _get('trackingEtaPaused');
  String trackingEtaMinutes(int minutes) =>
      _get('trackingEtaMinutes').replaceFirst('{minutes}', '$minutes');
  String get trackingEtaArriving => _get('trackingEtaArriving');
  String get trackingEtaUnavailable => _get('trackingEtaUnavailable');
  String get trackingGpsLostTitle => _get('trackingGpsLostTitle');
  String get trackingGpsLostBody => _get('trackingGpsLostBody');
  String get trackingGpsLostRetry => _get('trackingGpsLostRetry');
  String get trackingGpsStaleTitle => _get('trackingGpsStaleTitle');
  String get trackingGpsStaleBody => _get('trackingGpsStaleBody');

  String get deliveryStatusTitle => _get('deliveryStatusTitle');
  String deliveryStatusIdSubtitle(String id) =>
      _get('deliveryStatusIdSubtitle').replaceFirst('{id}', id);
  String get deliveryStatusLoading => _get('deliveryStatusLoading');
  String get deliveryStatusErrorTitle => _get('deliveryStatusErrorTitle');
  String get deliveryStatusErrorBody => _get('deliveryStatusErrorBody');
  String get deliveryStatusRetry => _get('deliveryStatusRetry');

  String get deliveryStageMatched => _get('deliveryStageMatched');
  String get deliveryStagePickedUp => _get('deliveryStagePickedUp');
  String get deliveryStageInTransit => _get('deliveryStageInTransit');
  String get deliveryStageDelivered => _get('deliveryStageDelivered');
  String get deliveryStageCancelled => _get('deliveryStageCancelled');

  String get deliveryStageTimestampPending =>
      _get('deliveryStageTimestampPending');
  String deliveryStageReachedAt(String time) =>
      _get('deliveryStageReachedAt').replaceFirst('{time}', time);

  String get deliveryDetailsTitle => _get('deliveryDetailsTitle');
  String get deliveryPickupLabel => _get('deliveryPickupLabel');
  String get deliveryDropoffLabel => _get('deliveryDropoffLabel');
  String get deliveryTierLabel => _get('deliveryTierLabel');

  String get deliveryTierBike => _get('deliveryTierBike');
  String get deliveryTierScooter => _get('deliveryTierScooter');
  String get deliveryTierCar => _get('deliveryTierCar');
  String get deliveryTierPickup => _get('deliveryTierPickup');

  String get deliveryJeeberCardTitle => _get('deliveryJeeberCardTitle');
  String get deliveryJeeberWaiting => _get('deliveryJeeberWaiting');
  String deliveryJeeberRating(String rating) =>
      _get('deliveryJeeberRating').replaceFirst('{rating}', rating);

  String get deliveryEtaLabel => _get('deliveryEtaLabel');
  String deliveryEtaMinutes(int minutes) =>
      _get('deliveryEtaMinutes').replaceFirst('{minutes}', '$minutes');
  String get deliveryEtaArriving => _get('deliveryEtaArriving');

  String get deliveryActionCancel => _get('deliveryActionCancel');
  String get deliveryActionContact => _get('deliveryActionContact');
  String get deliveryActionContactCustomer =>
      _get('deliveryActionContactCustomer');
  String get deliveryActionCancellingLabel =>
      _get('deliveryActionCancellingLabel');

  // JEBV4-309 — state-aware customer delivery-details hub.
  String get deliveryActionReceipt => _get('deliveryActionReceipt');
  String get deliveryDetailDeliveredBanner =>
      _get('deliveryDetailDeliveredBanner');
  String get deliveryDetailDeliveredBannerBody =>
      _get('deliveryDetailDeliveredBannerBody');
  String get deliveryDetailCancelledBanner =>
      _get('deliveryDetailCancelledBanner');
  String get deliveryDetailCancelledBannerBody =>
      _get('deliveryDetailCancelledBannerBody');

  String get deliveryCancelDialogTitle => _get('deliveryCancelDialogTitle');
  String get deliveryCancelDialogBody => _get('deliveryCancelDialogBody');
  String get deliveryCancelDialogConfirm => _get('deliveryCancelDialogConfirm');
  String get deliveryCancelDialogDismiss => _get('deliveryCancelDialogDismiss');

  String get deliveryErrorCancelTooLate => _get('deliveryErrorCancelTooLate');
  String get deliveryErrorCancelNetwork => _get('deliveryErrorCancelNetwork');
  String get deliveryErrorContactUnavailable =>
      _get('deliveryErrorContactUnavailable');
  String get deliveryErrorStreamLost => _get('deliveryErrorStreamLost');

  String get deliveryCompletedBanner => _get('deliveryCompletedBanner');
  String get deliveryCancelledBanner => _get('deliveryCancelledBanner');
  String get trackingCancelledBody => _get('trackingCancelledBody');
  String get trackingCancelledHomeCta => _get('trackingCancelledHomeCta');

  // P6/A3 + P6/A1: `expired` and `FailedNeedsEscalation` no longer collapse
  // into the cancelled body — cancel/expire carry different fee + strike
  // semantics, and an escalated row is still LIVE (admin can resolve it).
  String get trackingExpiredTitle => _get('trackingExpiredTitle');
  String get trackingExpiredBody => _get('trackingExpiredBody');
  String get trackingUnderReviewTitle => _get('trackingUnderReviewTitle');
  String get trackingUnderReviewBody => _get('trackingUnderReviewBody');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (l) => l.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final tag = locale.languageCode;
    final raw = await rootBundle.loadString('lib/l10n/app_$tag.arb');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final strings = <String, String>{
      for (final entry in json.entries)
        if (!entry.key.startsWith('@') && entry.value is String)
          entry.key: entry.value as String,
    };
    return AppLocalizations(locale, strings);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Synchronous variant used by tests and bootstrap so we don't need a
/// rootBundle round-trip when the app boots. Returns the same shape produced
/// by [_AppLocalizationsDelegate.load].
@visibleForTesting
AppLocalizations debugLoadAppLocalizationsSync(Locale locale, String arbJson) {
  final json = jsonDecode(arbJson) as Map<String, dynamic>;
  final strings = <String, String>{
    for (final entry in json.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
  return AppLocalizations(locale, strings);
}

/// Compat extension restoring 156 ARB getters dropped during the wave-2-4
/// merge. Reuses the same `_get(...)` runtime loader as the main class so
/// the parity script in `qa/t-mob-fix-002/l10n_parity_check.sh` sees all
/// getters as single-line literals. JEB-2 LEAD comment 14782 §1+§6.
extension AppLocalizationsRestored on AppLocalizations {
  String get appBarSignOut => _get('appBarSignOut');
  String availabilityActiveDeliveries(int count) {
    if (count == 0) return _get('availabilityActiveDeliveriesZero');
    if (count == 1) return _get('availabilityActiveDeliveriesOne');
    if (count == 2) return _get('availabilityActiveDeliveriesTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'availabilityActiveDeliveriesFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'availabilityActiveDeliveriesMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'availabilityActiveDeliveriesOther',
    ).replaceFirst('{count}', '$count');
  }

  String get availabilityActiveDeliveriesLabel =>
      _get('availabilityActiveDeliveries');
  String get availabilityHomeTitle => _get('availabilityHomeTitle');
  String get availabilityInactivityWarningBody =>
      _get('availabilityInactivityWarningBody');
  String get availabilityInactivityWarningCta =>
      _get('availabilityInactivityWarningCta');
  String get availabilityInactivityWarningTitle =>
      _get('availabilityInactivityWarningTitle');
  String get availabilityLoadError => _get('availabilityLoadError');
  String get availabilityLoadRetry => _get('availabilityLoadRetry');
  String get availabilityToggleErrorBody => _get('availabilityToggleErrorBody');
  String get chatActiveDeliverySubtitle => _get('chatActiveDeliverySubtitle');
  String get chatActiveDeliveryTitle => _get('chatActiveDeliveryTitle');
  String get chatAttachTooltip => _get('chatAttachTooltip');
  String get chatAttachmentCamera => _get('chatAttachmentCamera');
  String get chatAttachmentCancel => _get('chatAttachmentCancel');
  String get chatAttachmentGallery => _get('chatAttachmentGallery');
  /// P5: sheet subtitle — OMDS's static `show()` helper drops it, so the
  /// composer mounts `OmdsMediaPickerSheet` directly to pass it through.
  String get chatAttachmentSheetSubtitle =>
      _get('chatAttachmentSheetSubtitle');
  String get chatAttachmentSheetTitle => _get('chatAttachmentSheetTitle');
  String get chatComposerHint => _get('chatComposerHint');
  String get chatComposerHintPriceTime => _get('chatComposerHintPriceTime');
  String chatBalanceDeductionNotice(String amount) =>
      _get('chatBalanceDeductionNotice').replaceFirst('{amount}', amount);
  String chatBalanceDeductionA11y(String amount) =>
      _get('chatBalanceDeductionA11y').replaceFirst('{amount}', amount);
  String get chatBalanceDeductionDismissA11y =>
      _get('chatBalanceDeductionDismissA11y');
  String get chatDmOrderPickedAction => _get('chatDmOrderPickedAction');
  String get confirmPickingSheetTitle => _get('confirmPickingSheetTitle');
  String get confirmPickingSheetSubtitle => _get('confirmPickingSheetSubtitle');
  String get confirmHeadingOffSheetTitle => _get('confirmHeadingOffSheetTitle');
  String get confirmHeadingOffSheetSubtitle =>
      _get('confirmHeadingOffSheetSubtitle');
  String get confirmDeliveryActionCta => _get('confirmDeliveryActionCta');
  String get confirmDeliveryActionDragHandleA11y =>
      _get('confirmDeliveryActionDragHandleA11y');
  String get confirmDeliveryActionIllustrationA11y =>
      _get('confirmDeliveryActionIllustrationA11y');
  String get chatEmptyThreadSubtitle => _get('chatEmptyThreadSubtitle');
  String get chatEmptyThreadTitle => _get('chatEmptyThreadTitle');
  /// P4/P5: the in-chat image attachment failed to reach the CDN.
  String get chatErrorAttachmentUploadFailed =>
      _get('chatErrorAttachmentUploadFailed');
  String get chatErrorPermissionDenied => _get('chatErrorPermissionDenied');
  String get chatErrorPickUnavailable => _get('chatErrorPickUnavailable');
  String get chatErrorSendFailed => _get('chatErrorSendFailed');
  String chatPendingMessages(int count) {
    if (count == 0) return _get('chatPendingMessagesZero');
    if (count == 1) return _get('chatPendingMessagesOne');
    if (count == 2) return _get('chatPendingMessagesTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get('chatPendingMessagesFew').replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get('chatPendingMessagesMany').replaceFirst('{count}', '$count');
    }
    return _get('chatPendingMessagesOther').replaceFirst('{count}', '$count');
  }

  String get chatPendingMessagesLabel => _get('chatPendingMessages');
  String get chatNoConversationTitle => _get('chatNoConversationTitle');
  String get chatNoConversationSubtitle => _get('chatNoConversationSubtitle');
  String get chatPlaceholderCounterpartName =>
      _get('chatPlaceholderCounterpartName');
  String get chatSendTooltip => _get('chatSendTooltip');
  String get chatStatusConnected => _get('chatStatusConnected');
  String get chatStatusConnecting => _get('chatStatusConnecting');
  String get chatStatusOffline => _get('chatStatusOffline');
  String get chatStatusReconnecting => _get('chatStatusReconnecting');
  String get homeGreetingFallback => _get('homeGreetingFallback');
  String homeGreetingNamed(String name) =>
      _get('homeGreetingNamed').replaceFirst('{name}', name);
  String homeAvatarA11yLabel(String name) =>
      _get('homeAvatarA11yLabel').replaceFirst('{name}', name);
  String get homeLoadFailedBody => _get('homeLoadFailedBody');
  String get homeLoadFailedRetry => _get('homeLoadFailedRetry');
  String get homeLoadFailedTitle => _get('homeLoadFailedTitle');
  String homeRequestCardSemanticLabel({
    required String title,
    required String status,
  }) => _get(
    'homeRequestCardSemanticLabel',
  ).replaceFirst('{title}', title).replaceFirst('{status}', status);
  String get homeRequestEtaUnknown => _get('homeRequestEtaUnknown');
  String homeRequestJeeberAssigned(String name) =>
      _get('homeRequestJeeberAssigned').replaceFirst('{name}', name);
  String get locationConfirmAndSave => _get('locationConfirmAndSave');
  String get locationConfirmedTitle => _get('locationConfirmedTitle');
  String get locationContinueToDropoff => _get('locationContinueToDropoff');
  String locationCoordinatesFallback(String lat, String lng) => _get(
    'locationCoordinatesFallback',
  ).replaceFirst('{lat}', lat).replaceFirst('{lng}', lng);
  String get locationDetectingGps => _get('locationDetectingGps');
  String get locationDropoffTitle => _get('locationDropoffTitle');
  String get locationErrorGeocodingFailed =>
      _get('locationErrorGeocodingFailed');
  String get locationErrorGpsUnavailable => _get('locationErrorGpsUnavailable');
  String get locationErrorPermissionDenied =>
      _get('locationErrorPermissionDenied');
  String get locationErrorSaveFailed => _get('locationErrorSaveFailed');
  String get locationErrorSearchFailed => _get('locationErrorSearchFailed');
  String get locationNoSelectionYet => _get('locationNoSelectionYet');
  String get locationOpenMap => _get('locationOpenMap');
  String get locationPickupTitle => _get('locationPickupTitle');
  String get locationResolvingAddress => _get('locationResolvingAddress');
  String get locationSavingCta => _get('locationSavingCta');
  String get locationSearchEmpty => _get('locationSearchEmpty');
  String get locationSelectedPreviewLabel =>
      _get('locationSelectedPreviewLabel');
  String get locationStepDone => _get('locationStepDone');
  String get locationStepDropoff => _get('locationStepDropoff');
  String get locationStepPickup => _get('locationStepPickup');
  String get locationUseCurrentGps => _get('locationUseCurrentGps');
  String get offersEmptyBody => _get('offersEmptyBody');
  String get offersEmptyTitle => _get('offersEmptyTitle');
  String get offersRatingCount => _get('offersRatingCount');
  String get offersRequestClosedTitle => _get('offersRequestClosedTitle');
  String get offersRetryAction => _get('offersRetryAction');
  String get offersScreenTitle => _get('offersScreenTitle');
  String get offersSortByPrice => _get('offersSortByPrice');
  String get offersSortByRating => _get('offersSortByRating');
  String get offersSortLabel => _get('offersSortLabel');
  String get offersWindowExpired => _get('offersWindowExpired');
  String offersWindowRemaining(String time) =>
      _get('offersWindowRemaining').replaceFirst('{time}', time);
  String get orderHistoryAddressMissing => _get('orderHistoryAddressMissing');
  String get orderHistoryAmountUnavailable =>
      _get('orderHistoryAmountUnavailable');
  String orderHistoryCardSemanticLabel(String id) =>
      _get('orderHistoryCardSemanticLabel').replaceFirst('{id}', id);
  String get orderHistoryEmptyActive => _get('orderHistoryEmptyActive');
  String get orderHistoryEmptyCancelled => _get('orderHistoryEmptyCancelled');
  String get orderHistoryEmptyCompleted => _get('orderHistoryEmptyCompleted');
  String get orderHistoryEmptyTitle => _get('orderHistoryEmptyTitle');
  String get orderHistoryErrorNetwork => _get('orderHistoryErrorNetwork');
  String get orderHistoryErrorRetry => _get('orderHistoryErrorRetry');
  String get orderHistoryErrorServer => _get('orderHistoryErrorServer');
  String get orderHistoryErrorTitle => _get('orderHistoryErrorTitle');
  String get orderHistoryFilterActive => _get('orderHistoryFilterActive');
  String get orderHistoryFilterAnyDate => _get('orderHistoryFilterAnyDate');
  String get orderHistoryFilterApply => _get('orderHistoryFilterApply');
  String get orderHistoryFilterClear => _get('orderHistoryFilterClear');
  String orderHistoryFilterClearDate(String field) =>
      _get('orderHistoryFilterClearDate').replaceFirst('{field}', field);
  String get orderHistoryFilterCta => _get('orderHistoryFilterCta');
  String get orderHistoryFilterFrom => _get('orderHistoryFilterFrom');
  String get orderHistoryFilterTitle => _get('orderHistoryFilterTitle');
  String get orderHistoryFilterTo => _get('orderHistoryFilterTo');
  String get orderHistoryStatusCancelled => _get('orderHistoryStatusCancelled');
  String get orderHistoryStatusDelivered => _get('orderHistoryStatusDelivered');
  String get orderHistoryStatusDisputed => _get('orderHistoryStatusDisputed');
  String get orderHistoryStatusEnRoute => _get('orderHistoryStatusEnRoute');
  String get orderHistoryStatusMatched => _get('orderHistoryStatusMatched');
  String get orderHistoryStatusPending => _get('orderHistoryStatusPending');
  String get orderHistoryStatusPickedUp => _get('orderHistoryStatusPickedUp');
  String get orderHistoryStatusUnknown => _get('orderHistoryStatusUnknown');
  String get orderHistoryTabActive => _get('orderHistoryTabActive');
  String get orderHistoryTabCancelled => _get('orderHistoryTabCancelled');
  String get orderHistoryTabCompleted => _get('orderHistoryTabCompleted');
  String get registrationSocialCollisionTitle =>
      _get('registrationSocialCollisionTitle');
  String get registrationSocialCollisionBody =>
      _get('registrationSocialCollisionBody');
  String get registrationSocialCollisionDismiss =>
      _get('registrationSocialCollisionDismiss');
  String get registrationSocialErrorAccountDisabled =>
      _get('registrationSocialErrorAccountDisabled');
  String get registrationSocialErrorGeneric =>
      _get('registrationSocialErrorGeneric');
  String get registrationSocialErrorInvalidToken =>
      _get('registrationSocialErrorInvalidToken');
  String get registrationSocialErrorNetwork =>
      _get('registrationSocialErrorNetwork');
  String get requestFeedAccept => _get('requestFeedAccept');
  String get requestFeedAccepting => _get('requestFeedAccepting');
  String get requestFeedActionAcceptedSnack =>
      _get('requestFeedActionAcceptedSnack');
  String get requestFeedActionDeclinedSnack =>
      _get('requestFeedActionDeclinedSnack');
  String get requestFeedActionExpiredSnack =>
      _get('requestFeedActionExpiredSnack');
  String get requestFeedActionNetworkSnack =>
      _get('requestFeedActionNetworkSnack');
  String get requestFeedActionTakenSnack => _get('requestFeedActionTakenSnack');
  String get requestFeedDecline => _get('requestFeedDecline');
  String get requestFeedDeclining => _get('requestFeedDeclining');
  String requestFeedDistance(String distance) =>
      _get('requestFeedDistance').replaceFirst('{distance}', distance);
  String get requestFeedDropoffLabel => _get('requestFeedDropoffLabel');
  String requestFeedEarnings(String amount, String currency) => _get(
    'requestFeedEarnings',
  ).replaceFirst('{amount}', amount).replaceFirst('{currency}', currency);
  String get requestFeedEmptySubtitle => _get('requestFeedEmptySubtitle');
  String get requestFeedEmptyTitle => _get('requestFeedEmptyTitle');
  String get requestFeedErrorLoad => _get('requestFeedErrorLoad');
  String get requestFeedErrorRetry => _get('requestFeedErrorRetry');
  String get requestFeedErrorTitle => _get('requestFeedErrorTitle');
  String requestFeedExpiresIn(int seconds) =>
      _get('requestFeedExpiresIn').replaceFirst('{seconds}', '$seconds');
  String get requestFeedPickupLabel => _get('requestFeedPickupLabel');
  String get requestFeedReconnecting => _get('requestFeedReconnecting');
  String get requestFeedTierBulk => _get('requestFeedTierBulk');
  String get requestFeedTierLight => _get('requestFeedTierLight');
  String get requestFeedTierStandard => _get('requestFeedTierStandard');
  String get requestFeedTitle => _get('requestFeedTitle');
  String get settingsNetworkError => _get('settingsNetworkError');
  String get signOutCompleted => _get('signOutCompleted');
  String get signOutDialogBody => _get('signOutDialogBody');
  String get signOutDialogTitle => _get('signOutDialogTitle');
  String get voiceRecordingCancel => _get('voiceRecordingCancel');
  String get voiceRecordingDiscard => _get('voiceRecordingDiscard');
  String get voiceRecordingErrorMaxReached =>
      _get('voiceRecordingErrorMaxReached');
  String get voiceRecordingErrorPermission =>
      _get('voiceRecordingErrorPermission');
  String get voiceRecordingErrorRecorderFailed =>
      _get('voiceRecordingErrorRecorderFailed');
  String get voiceRecordingErrorTooShort => _get('voiceRecordingErrorTooShort');
  String get voiceRecordingErrorUnavailable =>
      _get('voiceRecordingErrorUnavailable');
  String get voiceRecordingErrorUploadGeneric =>
      _get('voiceRecordingErrorUploadGeneric');
  String get voiceRecordingErrorUploadNetwork =>
      _get('voiceRecordingErrorUploadNetwork');
  String get voiceRecordingErrorUploadServer =>
      _get('voiceRecordingErrorUploadServer');
  String get voiceRecordingHoldToRecord => _get('voiceRecordingHoldToRecord');
  String get voiceRecordingMicSemantic => _get('voiceRecordingMicSemantic');
  String get voiceRecordingPause => _get('voiceRecordingPause');
  String get voiceRecordingPlay => _get('voiceRecordingPlay');
  String get voiceRecordingRecordAgain => _get('voiceRecordingRecordAgain');
  String get voiceRecordingPermissionTitle =>
      _get('voiceRecordingPermissionTitle');
  String get voiceRecordingPermissionBody =>
      _get('voiceRecordingPermissionBody');
  String get voiceRecordingUnavailableTitle =>
      _get('voiceRecordingUnavailableTitle');
  String get voiceRecordingRetry => _get('voiceRecordingRetry');
  String get voiceRecordingRecordAnother => _get('voiceRecordingRecordAnother');
  String get voiceRecordingReleaseToStop => _get('voiceRecordingReleaseToStop');
  String get voiceRecordingRetryUploadSubmit =>
      _get('voiceRecordingRetryUploadSubmit');
  String get voiceRecordingReviewTitle => _get('voiceRecordingReviewTitle');
  String get voiceRecordingSend => _get('voiceRecordingSend');
  String get voiceRecordingSending => _get('voiceRecordingSending');
  String get voiceRecordingSentBody => _get('voiceRecordingSentBody');
  String get voiceRecordingSentTitle => _get('voiceRecordingSentTitle');
  String get voiceRecordingSubmit => _get('voiceRecordingSubmit');
  String get voiceRecordingSubtitle => _get('voiceRecordingSubtitle');
  String voiceRecordingTimerLabel(String duration) =>
      _get('voiceRecordingTimerLabel').replaceFirst('{duration}', duration);
  String get voiceRecordingTitle => _get('voiceRecordingTitle');
  String get voiceRecordingUploadErrorTitle =>
      _get('voiceRecordingUploadErrorTitle');

  // T-MOB-011: Broadcasting sub-line shown post-send (AC3)
  String get voiceRecordingBroadcastingHint =>
      _get('voiceRecordingBroadcastingHint');

  String get splashTagline => _get('splashTagline');
  String get splashLogoSemantic => _get('splashLogoSemantic');

  // --- Customer Profile (Figma 56581:1910, screen 18) ---
  String get customerProfileTitle => _get('customerProfileTitle');
  String get customerProfileSectionAccount =>
      _get('customerProfileSectionAccount');
  String get customerProfileRegisterAsDelivery =>
      _get('customerProfileRegisterAsDelivery');
  String get customerProfileRegisterCta => _get('customerProfileRegisterCta');
  String get customerProfilePasswordSecurity =>
      _get('customerProfilePasswordSecurity');
  String get customerProfileNotification => _get('customerProfileNotification');
  String get customerProfileResetLocation =>
      _get('customerProfileResetLocation');
  String get customerProfileSectionSupport =>
      _get('customerProfileSectionSupport');
  String get customerProfileContactUs => _get('customerProfileContactUs');
  String get customerProfileRateApp => _get('customerProfileRateApp');
  String get customerProfileVerifiedBadgeLabel =>
      _get('customerProfileVerifiedBadgeLabel');

  // Shown when a profile route is reached without typed view-data (release-safe
  // fallback in place of the debug-only fixture).
  String get profileUnavailableTitle => _get('profileUnavailableTitle');
  String get profileUnavailableBody => _get('profileUnavailableBody');

  // --- Delivery Man public Profile (Figma 56580:2697, screen 27) ---
  String get deliveryManProfileCloseLabel =>
      _get('deliveryManProfileCloseLabel');
  String get deliveryManProfileVerifiedBadgeLabel =>
      _get('deliveryManProfileVerifiedBadgeLabel');
  String get deliveryManProfileAvailable => _get('deliveryManProfileAvailable');
  String get deliveryManProfileUnavailable =>
      _get('deliveryManProfileUnavailable');
  String deliveryManProfileRatingSummary(String rating, int count) => _get(
    'deliveryManProfileRatingSummary',
  ).replaceFirst('{rating}', rating).replaceFirst('{count}', '$count');
  String deliveryManProfileLocationAvailability(
    String location,
    String availability,
  ) => _get('deliveryManProfileLocationAvailability')
      .replaceFirst('{location}', location)
      .replaceFirst('{availability}', availability);
  String get deliveryManProfileReviewsTitle =>
      _get('deliveryManProfileReviewsTitle');
  String deliveryManProfileReviewsCount(int count) =>
      _get('deliveryManProfileReviewsCount').replaceFirst('{count}', '$count');
  String get deliveryManProfileViewAllReviews =>
      _get('deliveryManProfileViewAllReviews');
  String deliveryManProfileRatingStarsLabel(String rating) => _get(
    'deliveryManProfileRatingStarsLabel',
  ).replaceFirst('{rating}', rating);
  String get deliveryManProfileEmptyReviewsTitle =>
      _get('deliveryManProfileEmptyReviewsTitle');
  String get deliveryManProfileEmptyReviewsSubtitle =>
      _get('deliveryManProfileEmptyReviewsSubtitle');
  String get reviewerVerifiedBadge => _get('reviewerVerifiedBadge');
  String get reviewerAnonymousLabel => _get('reviewerAnonymousLabel');
  String reviewRatingStarsLabel(String rating) =>
      _get('reviewRatingStarsLabel').replaceFirst('{rating}', rating);
  String get reviewHelpfulAction => _get('reviewHelpfulAction');
  String get reviewReplyAction => _get('reviewReplyAction');
  String reviewRelativeDaysAgo(int count) =>
      _get('reviewRelativeDaysAgo').replaceFirst('{count}', '$count');
  // Screen 19 — Delivery tab upsell for an unregistered jeeber (closes JEEB-66).
  String get jeeberRegisterTitle => _get('jeeberRegisterTitle');
  String get jeeberRegisterSubtitle => _get('jeeberRegisterSubtitle');
  String get jeeberRegisterCta => _get('jeeberRegisterCta');
  String get jeeberRegisterHeroSemantic => _get('jeeberRegisterHeroSemantic');

  // Screens 20-22 — Delivery-man onboarding wizard.
  String get dmOnboardingPhotoStepTitle => _get('dmOnboardingPhotoStepTitle');
  String get dmOnboardingSubmitFailed => _get('dmOnboardingSubmitFailed');
  String get dmOnboardingPhotoPickFailed => _get('dmOnboardingPhotoPickFailed');
  String get dmOnboardingPhotoUploadTitle =>
      _get('dmOnboardingPhotoUploadTitle');
  String get dmOnboardingPhotoUploadSubtitle =>
      _get('dmOnboardingPhotoUploadSubtitle');
  String get dmOnboardingPhotoUploadHint => _get('dmOnboardingPhotoUploadHint');
  String get dmOnboardingPhotoUploadCameraLabel =>
      _get('dmOnboardingPhotoUploadCameraLabel');
  String get dmOnboardingPhotoUploadGalleryLabel =>
      _get('dmOnboardingPhotoUploadGalleryLabel');
  String get dmOnboardingPersonalDetailsTitle =>
      _get('dmOnboardingPersonalDetailsTitle');
  String get dmOnboardingAddressStateLabel =>
      _get('dmOnboardingAddressStateLabel');
  String get dmOnboardingAddressStateHint =>
      _get('dmOnboardingAddressStateHint');
  String get dmOnboardingAddressCountryLabel =>
      _get('dmOnboardingAddressCountryLabel');
  String get dmOnboardingAddressCountryHint =>
      _get('dmOnboardingAddressCountryHint');
  String get dmOnboardingAddressStreetLabel =>
      _get('dmOnboardingAddressStreetLabel');
  String get dmOnboardingAddressStreetHint =>
      _get('dmOnboardingAddressStreetHint');
  String get dmOnboardingAddressAddressLabel =>
      _get('dmOnboardingAddressAddressLabel');
  String get dmOnboardingAddressAddressHint =>
      _get('dmOnboardingAddressAddressHint');
  String get dmOnboardingServiceAreaTitle =>
      _get('dmOnboardingServiceAreaTitle');
  String get dmOnboardingServiceAreaHeading =>
      _get('dmOnboardingServiceAreaHeading');
  String get dmOnboardingServiceAreaSubtitle =>
      _get('dmOnboardingServiceAreaSubtitle');
  String get dmOnboardingServiceAreaPrimaryLocationLabel =>
      _get('dmOnboardingServiceAreaPrimaryLocationLabel');
  String get dmOnboardingServiceAreaLocationFieldLabel =>
      _get('dmOnboardingServiceAreaLocationFieldLabel');
  String get dmOnboardingServiceAreaLocationPlaceholder =>
      _get('dmOnboardingServiceAreaLocationPlaceholder');
  String get dmOnboardingServiceAreaMapPlaceholder =>
      _get('dmOnboardingServiceAreaMapPlaceholder');
  String get dmOnboardingContinue => _get('dmOnboardingContinue');
  String dmOnboardingStepProgressLabel({
    required int current,
    required int total,
  }) => _get(
    'dmOnboardingStepProgressLabel',
  ).replaceFirst('{current}', '$current').replaceFirst('{total}', '$total');

  // T-MOB-027: Become a Jeeber card
  String get becomeJeeberCardTitle => _get('becomeJeeberCardTitle');
  String get becomeJeeberCardSubtitle => _get('becomeJeeberCardSubtitle');
  String get becomeJeeberCardCta => _get('becomeJeeberCardCta');
  String get becomeJeeberCardSemantic => _get('becomeJeeberCardSemantic');

  // T-MOB-028: Role toggle setting
  String get roleSettingTitle => _get('roleSettingTitle');
  String get roleSettingClient => _get('roleSettingClient');
  String get roleSettingJeeber => _get('roleSettingJeeber');
  String roleSettingSemanticLabel(String role) =>
      _get('roleSettingSemanticLabel').replaceFirst('{role}', role);
  String get roleSettingSwitchError => _get('roleSettingSwitchError');
  String get roleSettingKycGateTitle => _get('roleSettingKycGateTitle');
  String get roleSettingKycGateBody => _get('roleSettingKycGateBody');
  String get roleSettingKycGateCta => _get('roleSettingKycGateCta');
  String get roleSettingKycGateDismiss => _get('roleSettingKycGateDismiss');

  // T-MOB-029: Jeeber feed tier filters + offline banner
  String get jeeberFeedTierAll => _get('jeeberFeedTierAll');
  String get jeeberFeedTierFlash => _get('jeeberFeedTierFlash');
  String get jeeberFeedTierExpress => _get('jeeberFeedTierExpress');
  String get jeeberFeedTierStandard => _get('jeeberFeedTierStandard');
  String get jeeberFeedOfflineBannerTitle =>
      _get('jeeberFeedOfflineBannerTitle');
  String get jeeberFeedOfflineBannerSubtitle =>
      _get('jeeberFeedOfflineBannerSubtitle');
  String jeeberFeedRowSemantic({
    required String tier,
    required String distance,
    required String payout,
  }) => _get('jeeberFeedRowSemantic')
      .replaceFirst('{tier}', tier)
      .replaceFirst('{distance}', distance)
      .replaceFirst('{payout}', payout);

  // T-MOB-006/007/008: Home tab isolated tab widgets
  String get pendingTabSearchingLabel => _get('pendingTabSearchingLabel');
  String pendingTabTtlLabel(String minutes, String seconds) => _get(
    'pendingTabTtlLabel',
  ).replaceFirst('{minutes}', minutes).replaceFirst('{seconds}', seconds);
  String get pendingTabExpiredLabel => _get('pendingTabExpiredLabel');
  String get pendingTabRetryCta => _get('pendingTabRetryCta');
  String get pendingTabReconnecting => _get('pendingTabReconnecting');
  String pendingCardA11yLabel(String title, String ttl) => _get(
    'pendingCardA11yLabel',
  ).replaceFirst('{title}', title).replaceFirst('{ttl}', ttl);
  String pendingCardOffersBadge(int count) {
    if (count == 0) return _get('pendingCardOffersBadgeZero');
    if (count == 1) return _get('pendingCardOffersBadgeOne');
    if (count == 2) return _get('pendingCardOffersBadgeTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'pendingCardOffersBadgeFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'pendingCardOffersBadgeMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'pendingCardOffersBadgeOther',
    ).replaceFirst('{count}', '$count');
  }

  String get pendingCardCreatedJustNow => _get('pendingCardCreatedJustNow');
  String pendingCardCreatedMinutes(int count) {
    if (count == 0) return _get('pendingCardCreatedMinutesZero');
    if (count == 1) return _get('pendingCardCreatedMinutesOne');
    if (count == 2) return _get('pendingCardCreatedMinutesTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'pendingCardCreatedMinutesFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'pendingCardCreatedMinutesMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'pendingCardCreatedMinutesOther',
    ).replaceFirst('{count}', '$count');
  }

  String pendingCardCreatedHours(int count) {
    if (count == 0) return _get('pendingCardCreatedHoursZero');
    if (count == 1) return _get('pendingCardCreatedHoursOne');
    if (count == 2) return _get('pendingCardCreatedHoursTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'pendingCardCreatedHoursFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'pendingCardCreatedHoursMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'pendingCardCreatedHoursOther',
    ).replaceFirst('{count}', '$count');
  }

  String pendingCardCreatedDays(int count) {
    if (count == 0) return _get('pendingCardCreatedDaysZero');
    if (count == 1) return _get('pendingCardCreatedDaysOne');
    if (count == 2) return _get('pendingCardCreatedDaysTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) {
      return _get(
        'pendingCardCreatedDaysFew',
      ).replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get(
        'pendingCardCreatedDaysMany',
      ).replaceFirst('{count}', '$count');
    }
    return _get(
      'pendingCardCreatedDaysOther',
    ).replaceFirst('{count}', '$count');
  }

  String inProgressTabA11yLabel(String title, String status, String eta) =>
      _get('inProgressTabA11yLabel')
          .replaceFirst('{title}', title)
          .replaceFirst('{status}', status)
          .replaceFirst('{eta}', eta);
  String repliesTabA11yLabel(int count) =>
      _get('repliesTabA11yLabel').replaceFirst('{count}', count.toString());
  String get homeErrorRetry => _get('homeErrorRetry');

  // T-MOB-021: Prohibited items acknowledgment dialog
  String get prohibitedItemsDialogTitle => _get('prohibitedItemsDialogTitle');
  String get prohibitedItemsDialogBody => _get('prohibitedItemsDialogBody');
  String get prohibitedItemsDialogAcknowledge =>
      _get('prohibitedItemsDialogAcknowledge');
  String get prohibitedItemsDialogError => _get('prohibitedItemsDialogError');
  String get prohibitedItemsDialogRetry => _get('prohibitedItemsDialogRetry');
  String prohibitedItemsSemanticItem(String name) =>
      _get('prohibitedItemsSemanticItem').replaceFirst('{name}', name);

  // T-MOB-017: Live tracking at-door card + in-transit snack
  String get trackingAtDoorHeadline => _get('trackingAtDoorHeadline');
  String get trackingAtDoorBody => _get('trackingAtDoorBody');
  String get trackingAtDoorCta => _get('trackingAtDoorCta');
  // G4: at-door inline code + pre-at-door compact code row
  String get trackingAtDoorShareCode => _get('trackingAtDoorShareCode');
  String get trackingCodeChipLabel => _get('trackingCodeChipLabel');
  String get trackingCodeChipHint => _get('trackingCodeChipHint');
  String get trackingJeeberOnTheWay => _get('trackingJeeberOnTheWay');

  // T-MOB-018: OTP handover screen (client + Jeeber views)
  String get otpHandoverClientTitle => _get('otpHandoverClientTitle');
  String get otpHandoverJeeberTitle => _get('otpHandoverJeeberTitle');
  String get otpClientShareInstruction => _get('otpClientShareInstruction');
  String get otpClientDoNotShare => _get('otpClientDoNotShare');
  // G4: honest customer fallback when the app holds no code (SMS trigger)
  String get otpClientSmsSentTitle => _get('otpClientSmsSentTitle');
  String get otpClientSmsSentBody => _get('otpClientSmsSentBody');
  String get otpClientResendSms => _get('otpClientResendSms');
  String get otpJeeberInstruction => _get('otpJeeberInstruction');
  String get otpVerifyButton => _get('otpVerifyButton');
  String get otpWrongCode => _get('otpWrongCode');
  String otpAttemptsRemaining(int count) =>
      _get('otpAttemptsRemaining').replaceFirst('{count}', count.toString());
  String get otpEscalateDialogTitle => _get('otpEscalateDialogTitle');
  String get otpEscalateDialogBody => _get('otpEscalateDialogBody');
  String get otpEscalateConfirm => _get('otpEscalateConfirm');
  String get otpEscalateDismiss => _get('otpEscalateDismiss');
  String get otpDoneTitle => _get('otpDoneTitle');
  String get otpDoneBody => _get('otpDoneBody');
  String get otpRateNowCta => _get('otpRateNowCta');
  String get otpRetry => _get('otpRetry');
  String get otpErrorNetwork => _get('otpErrorNetwork');
  String get otpErrorServer => _get('otpErrorServer');
  String get otpErrorGeneric => _get('otpErrorGeneric');

  // T-MOB-019: Earnings dashboard — period filter + PDF export
  String get earningsPeriodCustom => _get('earningsPeriodCustom');
  String get earningsGross => _get('earningsGross');
  String get earningsNet => _get('earningsNet');
  String get earningsCommission => _get('earningsCommission');
  String get earningsExportButton => _get('earningsExportButton');
  String get earningsExportLoading => _get('earningsExportLoading');
  String get earningsExportError => _get('earningsExportError');
  String earningsDeliveryItemTitle(String id) =>
      _get('earningsDeliveryItemTitle').replaceFirst('{id}', id);
  String earningsDeliveryItemTier(String tier) =>
      _get('earningsDeliveryItemTier').replaceFirst('{tier}', tier);
  String earningsDeliveryItemFare(String amount, String currency) => _get(
    'earningsDeliveryItemFare',
  ).replaceFirst('{amount}', amount).replaceFirst('{currency}', currency);

  // T-MOB-020: Mutual blind rating
  String get mutualRatingTitle => _get('mutualRatingTitle');
  String get mutualRatingSubtitle => _get('mutualRatingSubtitle');
  String get mutualRatingTagsLabel => _get('mutualRatingTagsLabel');
  // JEBV4-296/297: localized quick-tag chip labels — one per canonical
  // gateway rating-tag key (wire values stay the English taxonomy keys,
  // see `kMutualRatingTags` / `_tagLabel` in mutual_rating_screen.dart).
  String get mutualRatingTagPunctuality => _get('mutualRatingTagPunctuality');
  String get mutualRatingTagCommunication =>
      _get('mutualRatingTagCommunication');
  String get mutualRatingTagPackageCondition =>
      _get('mutualRatingTagPackageCondition');
  String get mutualRatingTagCourtesy => _get('mutualRatingTagCourtesy');
  String get mutualRatingTagNavigation => _get('mutualRatingTagNavigation');
  String get mutualRatingSubmit => _get('mutualRatingSubmit');
  String get mutualRatingAwaitingTitle => _get('mutualRatingAwaitingTitle');
  String get mutualRatingAwaitingBody => _get('mutualRatingAwaitingBody');
  String get mutualRatingRevealedTitle => _get('mutualRatingRevealedTitle');
  String get mutualRatingAutoRevealedTitle =>
      _get('mutualRatingAutoRevealedTitle');
  String get mutualRatingNoCounterRating => _get('mutualRatingNoCounterRating');
  String mutualRatingTheirStars(int stars) =>
      _get('mutualRatingTheirStars').replaceFirst('{stars}', stars.toString());
  String get mutualRatingError => _get('mutualRatingError');
  String get mutualRatingDone => _get('mutualRatingDone');

  // T-MOB-022: Escalate/dispute flow
  String get escalateTitle => _get('escalateTitle');
  String get escalateSubtitle => _get('escalateSubtitle');
  String get escalateReasonLabel => _get('escalateReasonLabel');
  String get escalateReasonDamaged => _get('escalateReasonDamaged');
  String get escalateReasonWrongItem => _get('escalateReasonWrongItem');
  String get escalateReasonNoShow => _get('escalateReasonNoShow');
  String get escalateReasonFraud => _get('escalateReasonFraud');
  String get escalateReasonAbuse => _get('escalateReasonAbuse');
  String get escalateReasonOther => _get('escalateReasonOther');
  String get escalatePhotoLabel => _get('escalatePhotoLabel');
  String escalatePhotoCountRemaining(int remaining) => _get(
    'escalatePhotoCountRemaining',
  ).replaceFirst('{remaining}', remaining.toString());
  String escalatePhotoAttached(int count) =>
      _get('escalatePhotoAttached').replaceFirst('{count}', count.toString());
  String get escalateCommentLabel => _get('escalateCommentLabel');
  String get escalateSubmitButton => _get('escalateSubmitButton');
  String get escalateSubmitting => _get('escalateSubmitting');
  String get escalateErrorNetwork => _get('escalateErrorNetwork');
  String get escalateErrorServer => _get('escalateErrorServer');
  String get escalateErrorAlreadyOpen => _get('escalateErrorAlreadyOpen');
  String get escalateConfirmationTitle => _get('escalateConfirmationTitle');
  String get escalateConfirmationBody => _get('escalateConfirmationBody');
  String escalateConfirmationCaseNumber(String caseNumber) => _get(
    'escalateConfirmationCaseNumber',
  ).replaceFirst('{caseNumber}', caseNumber);
  String get escalateConfirmationDone => _get('escalateConfirmationDone');

  // Generic action labels
  String get actionDone => _get('actionDone');
  String get actionConfirm => _get('actionConfirm');

  // T-MOB-024: Cancellation flow
  String get cancellationTitle => _get('cancellationTitle');
  String get cancellationReasonPrompt => _get('cancellationReasonPrompt');
  String get cancellationReasonChangedMind =>
      _get('cancellationReasonChangedMind');
  String get cancellationReasonWaitTooLong =>
      _get('cancellationReasonWaitTooLong');
  String get cancellationReasonWrongAddress =>
      _get('cancellationReasonWrongAddress');
  String get cancellationReasonOther => _get('cancellationReasonOther');
  String get cancellationReasonCantComplete =>
      _get('cancellationReasonCantComplete');
  String get cancellationReasonVehicleIssue =>
      _get('cancellationReasonVehicleIssue');
  String get cancellationReasonEmergency => _get('cancellationReasonEmergency');
  String get cancellationReasonProhibitedItem =>
      _get('cancellationReasonProhibitedItem');
  String get cancellationOtherHint => _get('cancellationOtherHint');
  String get cancellationConfirmButton => _get('cancellationConfirmButton');
  String get cancellationWalletCta => _get('cancellationWalletCta');
  String get cancellationSuccess => _get('cancellationSuccess');
  String get cancellationTooLate => _get('cancellationTooLate');

  // T-MOB-025: Saved locations CRUD
  String get savedLocationsManage => _get('savedLocationsManage');
  String get savedLocationsAddNew => _get('savedLocationsAddNew');
  String get savedLocationsEdit => _get('savedLocationsEdit');
  String get savedLocationsDelete => _get('savedLocationsDelete');
  String get savedLocationsDeleteConfirmTitle =>
      _get('savedLocationsDeleteConfirmTitle');
  String savedLocationsDeleteConfirmBody(String label) =>
      _get('savedLocationsDeleteConfirmBody').replaceFirst('{label}', label);
  String get savedLocationsCapReached => _get('savedLocationsCapReached');
  String get savedLocationsError => _get('savedLocationsError');
  String get savedLocationsRetry => _get('savedLocationsRetry');
  String get savedLocationsDeleteError => _get('savedLocationsDeleteError');
  String get savedLocationsSaveError => _get('savedLocationsSaveError');

  // T-MOB-030: Offer submission form
  String get offerSubmitTitle => _get('offerSubmitTitle');
  String get offerSubmitPriceLabel => _get('offerSubmitPriceLabel');
  String get offerSubmitEtaLabel => _get('offerSubmitEtaLabel');
  String get offerSubmitNoteLabel => _get('offerSubmitNoteLabel');
  String get offerSubmitButton => _get('offerSubmitButton');
  String get offerSubmitButtonSemantics => _get('offerSubmitButtonSemantics');
  String get offerSubmitWithdrawTooltip => _get('offerSubmitWithdrawTooltip');
  String get offerSubmitRequestGone => _get('offerSubmitRequestGone');

  // T-MOB-031: Active delivery (Jeeber)
  String get activeDeliveryTitle => _get('activeDeliveryTitle');
  String get activeDeliveryProgressTitle => _get('activeDeliveryProgressTitle');
  String get activeDeliveryCancelledTitle =>
      _get('activeDeliveryCancelledTitle');
  String get activeDeliveryCancelledBody => _get('activeDeliveryCancelledBody');
  String get activeDeliveryExpiredTitle => _get('activeDeliveryExpiredTitle');
  String get activeDeliveryExpiredBody => _get('activeDeliveryExpiredBody');
  String get activeDeliveryDisputedTitle => _get('activeDeliveryDisputedTitle');
  String get activeDeliveryDisputedBody => _get('activeDeliveryDisputedBody');
  String get activeDeliveryDropOffLabel => _get('activeDeliveryDropOffLabel');
  String get activeDeliveryStatusOrdered => _get('activeDeliveryStatusOrdered');
  String get activeDeliveryStatusPicked => _get('activeDeliveryStatusPicked');
  String get activeDeliveryStatusInTransit =>
      _get('activeDeliveryStatusInTransit');
  String get activeDeliveryStatusAtDoor => _get('activeDeliveryStatusAtDoor');
  String get activeDeliveryStatusDone => _get('activeDeliveryStatusDone');
  String get activeDeliveryStageCompletedState =>
      _get('activeDeliveryStageCompletedState');
  String get activeDeliveryStageCurrentState =>
      _get('activeDeliveryStageCurrentState');
  String get activeDeliveryStageUpcomingState =>
      _get('activeDeliveryStageUpcomingState');
  String get jeeberActiveDeliveriesTitle => _get('jeeberActiveDeliveriesTitle');
  String get jeeberActiveDeliveriesFallbackTitle =>
      _get('jeeberActiveDeliveriesFallbackTitle');
  String get jeeberActiveDeliveriesOpenChat =>
      _get('jeeberActiveDeliveriesOpenChat');
  String get jeeberActiveDeliveriesManage =>
      _get('jeeberActiveDeliveriesManage');
  String jeeberActiveDeliveriesViewAll(int count) =>
      _get('jeeberActiveDeliveriesViewAll').replaceFirst('{count}', '$count');
  String get jeeberActiveDeliveriesShowLess =>
      _get('jeeberActiveDeliveriesShowLess');
  String get activeDeliveryMarkPicked => _get('activeDeliveryMarkPicked');
  String get activeDeliveryMarkInTransit => _get('activeDeliveryMarkInTransit');
  String get activeDeliveryMarkAtDoor => _get('activeDeliveryMarkAtDoor');
  String get activeDeliveryMarkDone => _get('activeDeliveryMarkDone');
  String get activeDeliveryOtpTitle => _get('activeDeliveryOtpTitle');
  String get activeDeliveryOtpInstruction =>
      _get('activeDeliveryOtpInstruction');
  String get activeDeliveryOtpSubmit => _get('activeDeliveryOtpSubmit');
  String get activeDeliveryOpenMapsButton =>
      _get('activeDeliveryOpenMapsButton');
  String get activeDeliveryOpenChatButton =>
      _get('activeDeliveryOpenChatButton');
  String get activeDeliveryEnterGoodsCostButton =>
      _get('activeDeliveryEnterGoodsCostButton');
  String get activeDeliveryUnavailable => _get('activeDeliveryUnavailable');
  String get activeDeliveryLoadError => _get('activeDeliveryLoadError');

  // P6/B4: kind-specific transition-failure copy. One message for three
  // different failures was ranked cause #3 of the 2026-07-25 incident.
  String get activeDeliveryErrorInvalidTransition =>
      _get('activeDeliveryErrorInvalidTransition');
  String get activeDeliveryErrorBadRequest =>
      _get('activeDeliveryErrorBadRequest');
  String get activeDeliveryErrorNetwork => _get('activeDeliveryErrorNetwork');
  String get activeDeliveryErrorOtpNeeded =>
      _get('activeDeliveryErrorOtpNeeded');
  String get activeDeliveryErrorGeneric => _get('activeDeliveryErrorGeneric');
  String activeDeliveryStepperA11y(String current, String next) => _get(
    'activeDeliveryStepperA11y',
  ).replaceFirst('{current}', current).replaceFirst('{next}', next);
  String activeDeliveryStepperCurrentDone(String current) => _get(
    'activeDeliveryStepperCurrentDone',
  ).replaceFirst('{current}', current);

  // T-MOB-032: Settlement statements
  String get settlementTitle => _get('settlementTitle');
  String get settlementEmptyMessage => _get('settlementEmptyMessage');
  String get settlementLoadError => _get('settlementLoadError');
  String get settlementUnavailable => _get('settlementUnavailable');
  String get settlementStatusPaid => _get('settlementStatusPaid');
  String get settlementStatusPending => _get('settlementStatusPending');
  String get settlementDownloadTooltip => _get('settlementDownloadTooltip');
  String settlementRowSemantics(String amount, String status) => _get(
    'settlementRowSemantics',
  ).replaceFirst('{amount}', amount).replaceFirst('{status}', status);
  String get settlementBreakdownTitle => _get('settlementBreakdownTitle');
  String get settlementTotalPayout => _get('settlementTotalPayout');
  String settlementCommissionLabel(String amount) =>
      _get('settlementCommissionLabel').replaceFirst('{amount}', amount);

  // ── WAVE 0 auth funnel (CTO-D1; JM-005/007/008/020/021/022/066) ───────────
  // Integrator-batched keys (40_GUARDRAILS §9 S4). W0 screen engineers
  // reference these; never inline-add a string in a widget.

  // JM-007 — Login
  String get loginTitle => _get('loginTitle');
  String get loginEmailLabel => _get('loginEmailLabel');
  String get loginEmailHint => _get('loginEmailHint');
  String get loginPasswordLabel => _get('loginPasswordLabel');
  String get loginPasswordHint => _get('loginPasswordHint');
  String get loginContinueCta => _get('loginContinueCta');
  String get loginForgotPasswordLink => _get('loginForgotPasswordLink');
  String get loginSignupLink => _get('loginSignupLink');
  String get loginPhoneEntryLink => _get('loginPhoneEntryLink');
  String get loginBiometricAffordance => _get('loginBiometricAffordance');
  String get loginInvalidCredentials => _get('loginInvalidCredentials');
  String get loginNetworkError => _get('loginNetworkError');

  // JM-008 — Sign up
  String get signupTitle => _get('signupTitle');
  String get signupNameLabel => _get('signupNameLabel');
  String get signupNameHint => _get('signupNameHint');
  String get signupEmailLabel => _get('signupEmailLabel');
  String get signupEmailHint => _get('signupEmailHint');
  String get signupPasswordLabel => _get('signupPasswordLabel');
  String get signupPasswordHint => _get('signupPasswordHint');
  String get signupPasswordStrengthWeak => _get('signupPasswordStrengthWeak');
  String get signupPasswordStrengthMedium =>
      _get('signupPasswordStrengthMedium');
  String get signupPasswordStrengthStrong =>
      _get('signupPasswordStrengthStrong');
  String get signupSubmitCta => _get('signupSubmitCta');
  String get signupLoginLink => _get('signupLoginLink');
  String get signupEmailCollision => _get('signupEmailCollision');

  // JM-020 — Recover password
  String get recoverTitle => _get('recoverTitle');
  String get recoverSubtitle => _get('recoverSubtitle');
  String get recoverEmailLabel => _get('recoverEmailLabel');
  String get recoverEmailHint => _get('recoverEmailHint');
  String get recoverSubmitCta => _get('recoverSubmitCta');
  String get recoverSignupLink => _get('recoverSignupLink');
  String get recoverBackToSigninLink => _get('recoverBackToSigninLink');

  // JM-021 — Verify recovery code
  String get verifyCodeTitle => _get('verifyCodeTitle');
  String get verifyCodeSubtitle => _get('verifyCodeSubtitle');
  String get verifyCodeSubmitCta => _get('verifyCodeSubmitCta');
  String get verifyCodeResendCta => _get('verifyCodeResendCta');
  String get verifyCodeError => _get('verifyCodeError');

  // JM-022 — Set password
  String get setpwTitle => _get('setpwTitle');
  String get setpwNewLabel => _get('setpwNewLabel');
  String get setpwNewHint => _get('setpwNewHint');
  String get setpwConfirmLabel => _get('setpwConfirmLabel');
  String get setpwConfirmHint => _get('setpwConfirmHint');
  String get setpwSubmitCta => _get('setpwSubmitCta');
  String get setpwValidationError => _get('setpwValidationError');

  // JM-066 — Account status
  String get accountStatusTitle => _get('accountStatusTitle');
  String get accountStatusBody => _get('accountStatusBody');
  String get accountStatusSupportCta => _get('accountStatusSupportCta');
  String get accountStatusSignoutCta => _get('accountStatusSignoutCta');

  // JM-005 — Biometric unlock
  String get biometricUnlockTitle => _get('biometricUnlockTitle');
  String get biometricUnlockAuthenticateCta =>
      _get('biometricUnlockAuthenticateCta');
  String get biometricUnlockUsePasswordLink =>
      _get('biometricUnlockUsePasswordLink');

  // W1-INT (S3) — shell persistent header actions (wallet chip + bell)
  String get shellWalletChipLabel => _get('shellWalletChipLabel');
  String get shellBellLabel => _get('shellBellLabel');
  String get shellComingSoon => _get('shellComingSoon');

  // Sprint-5 Stream C — free-text search (compose + results screens).
  String get shellSearchLabel => _get('shellSearchLabel');
  String get searchTitle => _get('searchTitle');
  String get searchHint => _get('searchHint');
  String get searchPromptTitle => _get('searchPromptTitle');
  String get searchPromptBody => _get('searchPromptBody');
  String get searchResultsTitle => _get('searchResultsTitle');
  String get searchNoResultsTitle => _get('searchNoResultsTitle');
  String get searchNoResultsBody => _get('searchNoResultsBody');
  String get searchUnavailableTitle => _get('searchUnavailableTitle');
  String get searchUnavailableBody => _get('searchUnavailableBody');
  String get searchNetworkError => _get('searchNetworkError');
  String get searchLoadError => _get('searchLoadError');
  String get searchRetry => _get('searchRetry');

  // JM-031 — Order summary (CTO-D3 deep-link target)
  String get orderSummaryTitle => _get('orderSummaryTitle');
  String get orderSummaryOpenChat => _get('orderSummaryOpenChat');
  String get orderSummaryTrack => _get('orderSummaryTrack');
  String get orderChatViewSummaryLink => _get('orderChatViewSummaryLink');
  String get orderChatPayCashOnDelivery => _get('orderChatPayCashOnDelivery');
  String get orderChatRequestLabel => _get('orderChatRequestLabel');
  String get orderSummaryValuePending => _get('orderSummaryValuePending');
  String get chatPartyJeeberFallback => _get('chatPartyJeeberFallback');
  String get chatPartyCustomerFallback => _get('chatPartyCustomerFallback');

  // JM-050 — Address detail form
  String get addressFormTitle => _get('addressFormTitle');
  String get addressFormSaveCta => _get('addressFormSaveCta');

  // JM-026 — Waiting / No-Coverage state (D48, D69)
  String get waitingTitle => _get('waitingTitle');
  String waitingCountdownLabel(String time) =>
      _get('waitingCountdownLabel').replaceFirst('{time}', time);
  String get waitingNoCoverageTitle => _get('waitingNoCoverageTitle');
  String get waitingNoCoverageBody => _get('waitingNoCoverageBody');
  String get waitingReachingOutLabel => _get('waitingReachingOutLabel');
  String get waitingReviewOffersCta => _get('waitingReviewOffersCta');
  String get waitingRetargetCta => _get('waitingRetargetCta');
  String get waitingCancelCta => _get('waitingCancelCta');
  String get waitingErrorBody => _get('waitingErrorBody');

  // JM-033 — Confirm Receipt (Customer), delivered-receipt-confirm (D11, D3)
  String get receiptTitle => _get('receiptTitle');
  String get receiptPromptHeading => _get('receiptPromptHeading');
  String receiptCashToJeeber(String amount, String jeeber) => _get(
    'receiptCashToJeeber',
  ).replaceFirst('{amount}', amount).replaceFirst('{jeeber}', jeeber);
  String get receiptJeeberFallback => _get('receiptJeeberFallback');
  String receiptCashToJeeberNoAmount(String jeeber) =>
      _get('receiptCashToJeeberNoAmount').replaceFirst('{jeeber}', jeeber);
  String get receiptProofPhotoLabel => _get('receiptProofPhotoLabel');
  String get receiptConfirmCta => _get('receiptConfirmCta');
  String get receiptNotYetCta => _get('receiptNotYetCta');
  String get receiptRetryAction => _get('receiptRetryAction');
  String get receiptErrorNetwork => _get('receiptErrorNetwork');
  String get receiptErrorNotFound => _get('receiptErrorNotFound');
  String get receiptErrorTransition => _get('receiptErrorTransition');
  String get receiptErrorGeneric => _get('receiptErrorGeneric');

  // JM-053 — Wallet Hub (wallet-hub)
  String get walletHubTitle => _get('walletHubTitle');
  String get walletAvailableBalanceLabel => _get('walletAvailableBalanceLabel');
  String get walletTopUpCta => _get('walletTopUpCta');
  String get walletHubLoadError => _get('walletHubLoadError');
  String get walletHubRetry => _get('walletHubRetry');

  // JM-054 — Wallet Charge Info (wallet-charge-info, static D92/D93)
  String get chargeInfoTitle => _get('chargeInfoTitle');
  String get chargeInfoStoreStep => _get('chargeInfoStoreStep');
  String get chargeInfoIdentityStep => _get('chargeInfoIdentityStep');
  String get chargeInfoPayCashStep => _get('chargeInfoPayCashStep');
  String get chargeInfoAutoUpdateNote => _get('chargeInfoAutoUpdateNote');
  String get chargeInfoFeeNote => _get('chargeInfoFeeNote');
  String get chargeInfoBackCta => _get('chargeInfoBackCta');

  // JM-041 — Onboarding Funding (onboarding-funding)
  String get fundingTitle => _get('fundingTitle');
  String get fundingStarterCreditBody => _get('fundingStarterCreditBody');
  String get fundingReserveBody => _get('fundingReserveBody');
  String get fundingTopupCta => _get('fundingTopupCta');
  String get fundingContinueCta => _get('fundingContinueCta');

  // JM-044 — Offer KYC Gate (offer-kyc-gate, D38)
  String get offerKycGateTitle => _get('offerKycGateTitle');
  String get offerKycGateHeadline => _get('offerKycGateHeadline');
  String get offerKycGateBody => _get('offerKycGateBody');
  String get gateTopupNote => _get('gateTopupNote');
  String get gateStartKycCta => _get('gateStartKycCta');
  String get gateRegisterLink => _get('gateRegisterLink');
  String get gateBackCta => _get('gateBackCta');

  // JM-043 — KYC Rejected (kyc-rejected, D52/D87 appeal-only)
  String get kycRejectedTitle => _get('kycRejectedTitle');
  String get kycRejectedHeadline => _get('kycRejectedHeadline');
  String get kycRejectedBody => _get('kycRejectedBody');
  String get kycRejectedAppealCta => _get('kycRejectedAppealCta');
  String get kycRejectedBackCta => _get('kycRejectedBackCta');

  // JM-047 — Jeeber Pending Offers (jeeber-pending-offers, D15)
  String get pendingOffersTitle => _get('pendingOffersTitle');
  String get pendingOffersEmptyTitle => _get('pendingOffersEmptyTitle');
  String get pendingOffersEmptyBody => _get('pendingOffersEmptyBody');

  // JM-055 — Wallet Activity List (wallet-activity-list, W2m typed ledger)
  String get walletActivityTitle => _get('walletActivityTitle');
  String get walletActivityEmptyTitle => _get('walletActivityEmptyTitle');
  String get walletActivityEmptyBody => _get('walletActivityEmptyBody');
  String get walletActivityBackCta => _get('walletActivityBackCta');

  // JM-056 — Transaction Detail (transaction-detail, per-type W3m)
  String get txnDetailTitle => _get('txnDetailTitle');
  String get txnDetailBody => _get('txnDetailBody');
  String get txnDetailOrderLink => _get('txnDetailOrderLink');
  String get txnDetailDisputeLink => _get('txnDetailDisputeLink');

  // JM-057 — Notifications List (notifications-list, header bell target, D84)
  String get notificationsTitle => _get('notificationsTitle');
  String get notificationsEmptyTitle => _get('notificationsEmptyTitle');
  String get notificationsEmptyBody => _get('notificationsEmptyBody');

  // JM-063 — Support Ticket / Contact Us (support-ticket, D76)
  String get supportTitle => _get('supportTitle');
  String get supportBody => _get('supportBody');
  String get supportSubmitCta => _get('supportSubmitCta');
  String get supportDisputeLink => _get('supportDisputeLink');

  // JM-065 — Dispute Status (dispute-status, D2/D53)
  String get disputeStatusTitle => _get('disputeStatusTitle');
  String get disputeStatusOpenLabel => _get('disputeStatusOpenLabel');
  String get disputeStatusBody => _get('disputeStatusBody');
  String get disputeStatusSupportCta => _get('disputeStatusSupportCta');
  String get disputeStatusBackCta => _get('disputeStatusBackCta');

  // JM-068 — All Reviews list (reviews-list, D58/D59/D73)
  String get reviewsTitle => _get('reviewsTitle');
  String get reviewsEmptyTitle => _get('reviewsEmptyTitle');
  String get reviewsEmptyBody => _get('reviewsEmptyBody');

  // JM-061 — Password & Security (password-security, D90)
  String get passwordSecurityTitle => _get('passwordSecurityTitle');
  String get passwordSecurityBody => _get('passwordSecurityBody');
  String get passwordSetEntryCta => _get('passwordSetEntryCta');
  String get passwordChangeUnavailable => _get('passwordChangeUnavailable');

  // Goods cost (jeeber goods-cost entry, Sprint 5 RTL/l10n pass)
  String get goodsCostTitle => _get('goodsCostTitle');
  String get goodsCostHeadline => _get('goodsCostHeadline');
  String get goodsCostBody => _get('goodsCostBody');
  String goodsCostFieldLabel(String currency) =>
      _get('goodsCostFieldLabel').replaceFirst('{currency}', currency);
  String get goodsCostFieldLabelNeutral => _get('goodsCostFieldLabelNeutral');
  String get goodsCostSubmit => _get('goodsCostSubmit');
  String get goodsCostErrorNetwork => _get('goodsCostErrorNetwork');
  String get goodsCostErrorNotFound => _get('goodsCostErrorNotFound');
  String get goodsCostErrorValidation => _get('goodsCostErrorValidation');
  String get goodsCostErrorGeneric => _get('goodsCostErrorGeneric');

  // Router fallbacks (Sprint 5 RTL/l10n pass)
  String get statementNotFound => _get('statementNotFound');
  String routeNotFound(String uri) =>
      _get('routeNotFound').replaceFirst('{uri}', uri);

  // Saved-location add/edit coordinate fields (Sprint 5 RTL/l10n pass)
  String get savedAddressLatitudeLabel => _get('savedAddressLatitudeLabel');
  String get savedAddressLongitudeLabel => _get('savedAddressLongitudeLabel');

  // Cycle-6 Arabic/RTL error-path + a11y strings (arabic-rtl-audit F1–F6)
  String get chatCreateRequestFailed => _get('chatCreateRequestFailed');
  String get callButtonLabel => _get('callButtonLabel');
  String get callInitiateFailed => _get('callInitiateFailed');
  String get earningsAccountUnavailable => _get('earningsAccountUnavailable');
  String get commonDismiss => _get('commonDismiss');
  String get handoverCodeA11yLabel => _get('handoverCodeA11yLabel');
  String get cancellationGenericError => _get('cancellationGenericError');

  // JEBV4-13 P1-5: dm-onboarding error surfaces (previously-silent DmOnboardingError)
  // NOTE: dmOnboardingPhotoPickFailed getter is defined once above (merged from
  // ui/cycle-6-fixes); the coverage-check surface is the ux-side addition.
  String get dmOnboardingCoverageCheckFailed =>
      _get('dmOnboardingCoverageCheckFailed');

  // JEBV4-13: profile-edit Change-avatar flow (previously a dead onTap)
  String get profilePhotoSheetSubtitle => _get('profilePhotoSheetSubtitle');
  String get profilePhotoPermissionDenied =>
      _get('profilePhotoPermissionDenied');
  String get profilePhotoChangeFailed => _get('profilePhotoChangeFailed');

  // JEBV4-13: offline banner (previously hardcoded EN + dead DISMISS)
  String get offlineBannerMessage => _get('offlineBannerMessage');

  // JEBV4-108: honest 401-at-create handling (session expiry → re-auth)
  String get createSessionExpired => _get('createSessionExpired');

  // F6 / JEBV4-303 customer-wallet stub (role-bleed): the customer-appropriate
  // wallet surface the top-bar wallet chip routes a client to.
  String get customerWalletStubTitle => _get('customerWalletStubTitle');
  String get customerWalletStubHeadline => _get('customerWalletStubHeadline');
  String get customerWalletStubBody => _get('customerWalletStubBody');
  String get customerWalletStubCodTitle => _get('customerWalletStubCodTitle');
  String get customerWalletStubCodBody => _get('customerWalletStubCodBody');
  String get customerWalletStubDoneCta => _get('customerWalletStubDoneCta');
}
