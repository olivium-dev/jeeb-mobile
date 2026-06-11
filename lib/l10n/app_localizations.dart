import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  static const supportedLocales = <Locale>[
    Locale('en'),
    Locale('ar'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(
      localizations != null,
      'AppLocalizations not found in context — did you forget to add '
      'AppLocalizations.delegate to MaterialApp.localizationsDelegates?',
    );
    return localizations!;
  }

  String _get(String key) {
    final value = _strings[key];
    assert(value != null, 'Missing ARB key: $key for ${locale.toLanguageTag()}');
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
  String get homeEmptySubtitle => _get('homeEmptySubtitle');
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
  String get homeSearchHint => _get('homeSearchHint');
  String get homeTrackOrderCta => _get('homeTrackOrderCta');
  String get homeStageOrdered => _get('homeStageOrdered');
  String get homeStagePicked => _get('homeStagePicked');
  String get homeStageInTransit => _get('homeStageInTransit');
  String get chatOfferAccept => _get('chatOfferAccept');
  String get chatOfferAccepting => _get('chatOfferAccepting');
  String chatOfferEtaMinutes(int minutes) =>
      _get('chatOfferEtaMinutes').replaceFirst('{minutes}', '$minutes');
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
      return _get('earningsSummaryCompletedFew').replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get('earningsSummaryCompletedMany').replaceFirst('{count}', '$count');
    }
    return _get('earningsSummaryCompletedOther').replaceFirst('{count}', '$count');
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
  String get notificationCategoryOffers => _get('notificationCategoryOffers');
  String get notificationCategoryOffersSubtitle =>
      _get('notificationCategoryOffersSubtitle');
  String get notificationCategoryChat => _get('notificationCategoryChat');
  String get notificationCategoryChatSubtitle =>
      _get('notificationCategoryChatSubtitle');
  String get notificationCategoryStatus => _get('notificationCategoryStatus');
  String get notificationCategoryStatusSubtitle =>
      _get('notificationCategoryStatusSubtitle');
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
  String get accountDeleteDialogBody => _get('accountDeleteDialogBody');
  String get accountDeleteConfirm => _get('accountDeleteConfirm');
  String get accountDeleteSubmitted => _get('accountDeleteSubmitted');

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
  String get locationMapPinSemanticLabel =>
      _get('locationMapPinSemanticLabel');
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

  String photoAttachmentTitle(int count, int max) => _get('photoAttachmentTitle')
      .replaceFirst('{count}', '$count')
      .replaceFirst('{max}', '$max');
  String get photoAttachmentAddLabel => _get('photoAttachmentAddLabel');
  String photoAttachmentRemoveLabel(int position) =>
      _get('photoAttachmentRemoveLabel').replaceFirst('{position}', '$position');
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
  String registrationOtpAttemptsRemaining(int remaining) =>
      _get('registrationOtpAttemptsRemaining')
          .replaceFirst('{remaining}', '$remaining');
  String get registrationLockoutTitle => _get('registrationLockoutTitle');
  String registrationLockoutBody(String minutes, String seconds) =>
      _get('registrationLockoutBody')
          .replaceFirst('{minutes}', minutes)
          .replaceFirst('{seconds}', seconds);
  String get registrationChangePhone => _get('registrationChangePhone');

  String get tierSelectionTitle => _get('tierSelectionTitle');
  String get tierSelectionSubtitle => _get('tierSelectionSubtitle');
  String get tierSelectionConfirm => _get('tierSelectionConfirm');
  String get tierSelectionWhatDifference =>
      _get('tierSelectionWhatDifference');
  String get tierSelectionRecommendedBadge =>
      _get('tierSelectionRecommendedBadge');
  String get tierSelectionLocked => _get('tierSelectionLocked');
  String get tierSelectionPriceLabel => _get('tierSelectionPriceLabel');
  String tierSelectionPriceRange(String low, String high) =>
      _get('tierSelectionPriceRange')
          .replaceFirst('{low}', low)
          .replaceFirst('{high}', high);
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
  String get tierSelectionFooterStandard =>
      _get('tierSelectionFooterStandard');
  String get tierSelectionFooterOnTheWay =>
      _get('tierSelectionFooterOnTheWay');
  String get tierSelectionFooterEco => _get('tierSelectionFooterEco');
  String tierSelectionCardSemanticLabel({
    required String name,
    required String sla,
    required String radius,
    required String price,
  }) =>
      _get('tierSelectionCardSemanticLabel')
          .replaceFirst('{name}', name)
          .replaceFirst('{sla}', sla)
          .replaceFirst('{radius}', radius)
          .replaceFirst('{price}', price);
  String get tierSelectionCardSelectedHint =>
      _get('tierSelectionCardSelectedHint');
  String get tierSelectionOnTheWayMvpNote =>
      _get('tierSelectionOnTheWayMvpNote');

  // KYC wizard
  String get kycWizardTitle => _get('kycWizardTitle');
  String kycWizardProgressLabel({required int current, required int total}) =>
      _get('kycWizardProgressLabel')
          .replaceFirst('{current}', '$current')
          .replaceFirst('{total}', '$total');
  String get kycWizardStepIdLabel => _get('kycWizardStepIdLabel');
  String get kycWizardStepSelfieLabel => _get('kycWizardStepSelfieLabel');
  String get kycWizardStepVehicleLabel => _get('kycWizardStepVehicleLabel');
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

  String get kycSelfieStepTitle => _get('kycSelfieStepTitle');
  String get kycSelfieStepSubtitle => _get('kycSelfieStepSubtitle');
  String get kycSelfieLivenessPrompt => _get('kycSelfieLivenessPrompt');
  String get kycSelfieLivenessBlink => _get('kycSelfieLivenessBlink');
  String get kycSelfieLivenessSmile => _get('kycSelfieLivenessSmile');
  String get kycSelfieRetake => _get('kycSelfieRetake');
  String get kycSelfieCaptureCta => _get('kycSelfieCaptureCta');

  String get kycVehicleStepTitle => _get('kycVehicleStepTitle');
  String get kycVehicleStepSubtitle => _get('kycVehicleStepSubtitle');
  String get kycVehicleTypeScooter => _get('kycVehicleTypeScooter');
  String get kycVehicleTypeCar => _get('kycVehicleTypeCar');
  String get kycVehicleTypeBicycle => _get('kycVehicleTypeBicycle');
  String get kycVehicleTypeOnFoot => _get('kycVehicleTypeOnFoot');
  String get kycVehicleRegistrationLabel =>
      _get('kycVehicleRegistrationLabel');
  String get kycVehicleRegistrationHint => _get('kycVehicleRegistrationHint');
  String get kycVehicleRegistrationRequired =>
      _get('kycVehicleRegistrationRequired');

  String get kycStatusPendingTitle => _get('kycStatusPendingTitle');
  String get kycStatusPendingBody => _get('kycStatusPendingBody');
  String get kycStatusApprovedTitle => _get('kycStatusApprovedTitle');
  String get kycStatusApprovedBody => _get('kycStatusApprovedBody');
  String get kycStatusRejectedTitle => _get('kycStatusRejectedTitle');
  String get kycStatusRejectedBody => _get('kycStatusRejectedBody');
  String get kycStatusResubmitCta => _get('kycStatusResubmitCta');
  String get kycStatusBackToProfileCta => _get('kycStatusBackToProfileCta');

  String get kycRejectionReasonIdUnreadable =>
      _get('kycRejectionReasonIdUnreadable');
  String get kycRejectionReasonSelfieMismatch =>
      _get('kycRejectionReasonSelfieMismatch');
  String get kycRejectionReasonVehicleDocumentMissing =>
      _get('kycRejectionReasonVehicleDocumentMissing');
  String get kycRejectionReasonExpired =>
      _get('kycRejectionReasonExpired');
  String get kycRejectionReasonOther => _get('kycRejectionReasonOther');

  String get kycErrorPermissionDenied => _get('kycErrorPermissionDenied');
  String get kycErrorUnavailable => _get('kycErrorUnavailable');
  String get kycErrorCompressionFailed => _get('kycErrorCompressionFailed');
  String get kycErrorSubmitFailed => _get('kycErrorSubmitFailed');

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
      return _get('dashboardTodayEarningsCompletedFew').replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get('dashboardTodayEarningsCompletedMany').replaceFirst('{count}', '$count');
    }
    return _get('dashboardTodayEarningsCompletedOther').replaceFirst('{count}', '$count');
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
  String get dashboardActiveDeliveryOpen =>
      _get('dashboardActiveDeliveryOpen');
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
      return _get('dashboardNearbyRequestsFew').replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get('dashboardNearbyRequestsMany').replaceFirst('{count}', '$count');
    }
    return _get('dashboardNearbyRequestsOther').replaceFirst('{count}', '$count');
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
  String jeeberFeedDistanceAway(String distance) =>
      _get('jeeberFeedDistanceAway').replaceFirst('{distance}', distance);
  String get jeeberFeedStatusPending => _get('jeeberFeedStatusPending');
  String get jeeberFeedActionHeadingToDropOff =>
      _get('jeeberFeedActionHeadingToDropOff');
  String get jeeberFeedAcceptOrdersLabel =>
      _get('jeeberFeedAcceptOrdersLabel');
  String get jeeberFeedEmptyTitle => _get('jeeberFeedEmptyTitle');
  String get jeeberFeedEmptySubtitle => _get('jeeberFeedEmptySubtitle');
  String jeeberFeedRatingSemantic(String rating) =>
      _get('jeeberFeedRatingSemantic').replaceFirst('{rating}', rating);
  String get requestFeedTierFlash => _get('requestFeedTierFlash');
  String get jeeberIncomingMatchTitle => _get('jeeberIncomingMatchTitle');
  String get jeeberIncomingMatchAccept => _get('jeeberIncomingMatchAccept');
  String get jeeberIncomingMatchDecline => _get('jeeberIncomingMatchDecline');
  String jeeberIncomingMatchCountdown(int seconds) =>
      _get('jeeberIncomingMatchCountdown').replaceFirst('{seconds}', '$seconds');

  // Request summary (T-mobile-012)
  String get requestSummaryTitle => _get('requestSummaryTitle');
  String get requestSummarySectionDescription =>
      _get('requestSummarySectionDescription');
  String get requestSummarySectionPhotos =>
      _get('requestSummarySectionPhotos');
  String get requestSummarySectionTier => _get('requestSummarySectionTier');
  String get requestSummarySectionPickup => _get('requestSummarySectionPickup');
  String get requestSummarySectionDropoff =>
      _get('requestSummarySectionDropoff');
  String get requestSummaryDescriptionEmpty =>
      _get('requestSummaryDescriptionEmpty');
  String get requestSummaryPhotosEmpty => _get('requestSummaryPhotosEmpty');
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
      return _get('requestSummaryFindingNotifiedFew').replaceFirst('{count}', '$count');
    }
    if (mod >= 11 && mod <= 99) {
      return _get('requestSummaryFindingNotifiedMany').replaceFirst('{count}', '$count');
    }
    return _get('requestSummaryFindingNotifiedOther').replaceFirst('{count}', '$count');
  }
  String get requestSummaryFindingHint => _get('requestSummaryFindingHint');

  // No-offer timeout / expired-request banners (T-mobile-035)
  String get requestSummaryNoOffersTitle =>
      _get('requestSummaryNoOffersTitle');
  String get requestSummaryNoOffersBody => _get('requestSummaryNoOffersBody');
  String requestSummaryExpandToTier(String tier) =>
      _get('requestSummaryExpandToTier').replaceFirst('{tier}', tier);
  String get requestSummaryExpiredTitle => _get('requestSummaryExpiredTitle');
  String get requestSummaryExpiredBody => _get('requestSummaryExpiredBody');
  String get requestSummaryReRequest => _get('requestSummaryReRequest');

  String get jeeberRequestDetailTitle => _get('jeeberRequestDetailTitle');
  String get jeeberRequestDetailSectionPickup =>
      _get('jeeberRequestDetailSectionPickup');
  String get jeeberRequestDetailSectionDropoff =>
      _get('jeeberRequestDetailSectionDropoff');
  String get jeeberRequestDetailSectionDescription =>
      _get('jeeberRequestDetailSectionDescription');
  String jeeberRequestDetailDistance(String distance) =>
      _get('jeeberRequestDetailDistance')
          .replaceFirst('{distance}', distance);
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
  String offersCardFee(String amount, String currency) => _get('offersCardFee')
      .replaceFirst('{amount}', amount)
      .replaceFirst('{currency}', currency);
  String get offersCardVehicleCar => _get('offersCardVehicleCar');
  String get offersCardVehicleMotorcycle =>
      _get('offersCardVehicleMotorcycle');
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
  }) =>
      _get('offersCardSemanticLabel')
          .replaceFirst('{name}', name)
          .replaceFirst('{rating}', rating)
          .replaceFirst('{vehicle}', vehicle)
          .replaceFirst('{fee}', fee)
          .replaceFirst('{currency}', currency)
          .replaceFirst('{minutes}', '$minutes');
  String get offersHighFeeDialogTitle => _get('offersHighFeeDialogTitle');
  String offersHighFeeDialogBody(String amount, String currency) =>
      _get('offersHighFeeDialogBody')
          .replaceFirst('{amount}', amount)
          .replaceFirst('{currency}', currency);
  String get offersHighFeeDialogConfirm => _get('offersHighFeeDialogConfirm');
  String get offersHighFeeDialogCancel => _get('offersHighFeeDialogCancel');
  String get offersErrorNetwork => _get('offersErrorNetwork');
  String get offersErrorRequestNotOpen => _get('offersErrorRequestNotOpen');
  String get offersErrorOfferNotPending => _get('offersErrorOfferNotPending');
  String get offersErrorGeneric => _get('offersErrorGeneric');
  String get offersAcceptedBannerTitle => _get('offersAcceptedBannerTitle');
  String get offersAcceptedBannerBody => _get('offersAcceptedBannerBody');

  String get offerSubmissionTitle => _get('offerSubmissionTitle');
  String get offerSubmissionIntro => _get('offerSubmissionIntro');
  String get offerSubmissionFeeLabel => _get('offerSubmissionFeeLabel');
  String get offerSubmissionFeeHint => _get('offerSubmissionFeeHint');
  String offerSubmissionFeeHelper(String minimum, String currency) =>
      _get('offerSubmissionFeeHelper')
          .replaceFirst('{minimum}', minimum)
          .replaceFirst('{currency}', currency);
  String get offerSubmissionFeeErrorRequired =>
      _get('offerSubmissionFeeErrorRequired');
  String offerSubmissionFeeErrorBelowMinimum(
          String minimum, String currency) =>
      _get('offerSubmissionFeeErrorBelowMinimum')
          .replaceFirst('{minimum}', minimum)
          .replaceFirst('{currency}', currency);
  String offerSubmissionFeeErrorAboveMaximum(
          String maximum, String currency) =>
      _get('offerSubmissionFeeErrorAboveMaximum')
          .replaceFirst('{maximum}', maximum)
          .replaceFirst('{currency}', currency);
  String get offerSubmissionEtaLabel => _get('offerSubmissionEtaLabel');
  String get offerSubmissionEtaHint => _get('offerSubmissionEtaHint');
  String get offerSubmissionEtaSuffix => _get('offerSubmissionEtaSuffix');
  String offerSubmissionEtaHelper(int min, int max) =>
      _get('offerSubmissionEtaHelper')
          .replaceFirst('{min}', '$min')
          .replaceFirst('{max}', '$max');
  String get offerSubmissionEtaErrorRequired =>
      _get('offerSubmissionEtaErrorRequired');
  String offerSubmissionEtaErrorBelowMinimum(int min) =>
      _get('offerSubmissionEtaErrorBelowMinimum')
          .replaceFirst('{min}', '$min');
  String offerSubmissionEtaErrorAboveMaximum(int max) =>
      _get('offerSubmissionEtaErrorAboveMaximum')
          .replaceFirst('{max}', '$max');
  String get offerSubmissionNoteLabel => _get('offerSubmissionNoteLabel');
  String get offerSubmissionNoteHint => _get('offerSubmissionNoteHint');
  String offerSubmissionNoteErrorTooLong(int max) =>
      _get('offerSubmissionNoteErrorTooLong').replaceFirst('{max}', '$max');
  String get offerSubmissionSubmitButton =>
      _get('offerSubmissionSubmitButton');
  String get offerSubmissionSubmittingButton =>
      _get('offerSubmissionSubmittingButton');
  String get offerSubmissionRetryButton => _get('offerSubmissionRetryButton');
  String get offerSubmissionConfirmedTitle =>
      _get('offerSubmissionConfirmedTitle');
  String get offerSubmissionConfirmedBody =>
      _get('offerSubmissionConfirmedBody');
  String offerSubmissionConfirmedFee(String amount, String currency) =>
      _get('offerSubmissionConfirmedFee')
          .replaceFirst('{amount}', amount)
          .replaceFirst('{currency}', currency);
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
  String get offerSubmissionErrorNetwork =>
      _get('offerSubmissionErrorNetwork');
  String get offerSubmissionErrorRequestNotOpen =>
      _get('offerSubmissionErrorRequestNotOpen');
  String get offerSubmissionErrorDuplicate =>
      _get('offerSubmissionErrorDuplicate');
  String get offerSubmissionErrorGeneric =>
      _get('offerSubmissionErrorGeneric');
  String get offerSubmissionWithdrawErrorNetwork =>
      _get('offerSubmissionWithdrawErrorNetwork');
  String get offerSubmissionWithdrawErrorGeneric =>
      _get('offerSubmissionWithdrawErrorGeneric');

  String get trackingTitle => _get('trackingTitle');
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
  String get deliveryActionCancellingLabel =>
      _get('deliveryActionCancellingLabel');

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
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode);

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
AppLocalizations debugLoadAppLocalizationsSync(
  Locale locale,
  String arbJson,
) {
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
    if (mod >= 3 && mod <= 10) return _get('availabilityActiveDeliveriesFew').replaceFirst('{count}', '$count');
    if (mod >= 11 && mod <= 99) return _get('availabilityActiveDeliveriesMany').replaceFirst('{count}', '$count');
    return _get('availabilityActiveDeliveriesOther').replaceFirst('{count}', '$count');
  }
  String get availabilityActiveDeliveriesLabel => _get('availabilityActiveDeliveries');
  String get availabilityHomeTitle => _get('availabilityHomeTitle');
  String get availabilityInactivityWarningBody => _get('availabilityInactivityWarningBody');
  String get availabilityInactivityWarningCta => _get('availabilityInactivityWarningCta');
  String get availabilityInactivityWarningTitle => _get('availabilityInactivityWarningTitle');
  String get availabilityLoadError => _get('availabilityLoadError');
  String get availabilityLoadRetry => _get('availabilityLoadRetry');
  String get availabilityToggleErrorBody => _get('availabilityToggleErrorBody');
  String get chatActiveDeliverySubtitle => _get('chatActiveDeliverySubtitle');
  String get chatActiveDeliveryTitle => _get('chatActiveDeliveryTitle');
  String get chatAttachTooltip => _get('chatAttachTooltip');
  String get chatAttachmentCamera => _get('chatAttachmentCamera');
  String get chatAttachmentCancel => _get('chatAttachmentCancel');
  String get chatAttachmentGallery => _get('chatAttachmentGallery');
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
  String get chatErrorPermissionDenied => _get('chatErrorPermissionDenied');
  String get chatErrorPickUnavailable => _get('chatErrorPickUnavailable');
  String get chatErrorSendFailed => _get('chatErrorSendFailed');
  String chatPendingMessages(int count) {
    if (count == 0) return _get('chatPendingMessagesZero');
    if (count == 1) return _get('chatPendingMessagesOne');
    if (count == 2) return _get('chatPendingMessagesTwo');
    final mod = count % 100;
    if (mod >= 3 && mod <= 10) return _get('chatPendingMessagesFew').replaceFirst('{count}', '$count');
    if (mod >= 11 && mod <= 99) return _get('chatPendingMessagesMany').replaceFirst('{count}', '$count');
    return _get('chatPendingMessagesOther').replaceFirst('{count}', '$count');
  }
  String get chatPendingMessagesLabel => _get('chatPendingMessages');
  String get chatNoConversationTitle => _get('chatNoConversationTitle');
  String get chatNoConversationSubtitle => _get('chatNoConversationSubtitle');
  String get chatPlaceholderCounterpartName => _get('chatPlaceholderCounterpartName');
  String get chatSendTooltip => _get('chatSendTooltip');
  String get chatStatusConnected => _get('chatStatusConnected');
  String get chatStatusConnecting => _get('chatStatusConnecting');
  String get chatStatusOffline => _get('chatStatusOffline');
  String get chatStatusReconnecting => _get('chatStatusReconnecting');
  String get homeGreetingFallback => _get('homeGreetingFallback');
  String homeGreetingNamed(String name) => _get('homeGreetingNamed').replaceFirst('{name}', name);
  String get homeGreetingSubtitle => _get('homeGreetingSubtitle');
  String homeAvatarA11yLabel(String name) => _get('homeAvatarA11yLabel').replaceFirst('{name}', name);
  String get homeEmptyOrdersTitle => _get('homeEmptyOrdersTitle');
  String get homeEmptyOrdersBody => _get('homeEmptyOrdersBody');
  String get homeNewOrderCta => _get('homeNewOrderCta');
  String get homeLoadFailedBody => _get('homeLoadFailedBody');
  String get homeLoadFailedRetry => _get('homeLoadFailedRetry');
  String get homeLoadFailedTitle => _get('homeLoadFailedTitle');
  String get homeRecordVoiceRequest => _get('homeRecordVoiceRequest');
  String homeRequestCardSemanticLabel({required String title, required String status}) => _get('homeRequestCardSemanticLabel').replaceFirst('{title}', title).replaceFirst('{status}', status);
  String get homeRequestEtaUnknown => _get('homeRequestEtaUnknown');
  String homeRequestJeeberAssigned(String name) => _get('homeRequestJeeberAssigned').replaceFirst('{name}', name);
  String get locationConfirmAndSave => _get('locationConfirmAndSave');
  String get locationConfirmedTitle => _get('locationConfirmedTitle');
  String get locationContinueToDropoff => _get('locationContinueToDropoff');
  String locationCoordinatesFallback(String lat, String lng) => _get('locationCoordinatesFallback').replaceFirst('{lat}', lat).replaceFirst('{lng}', lng);
  String get locationDetectingGps => _get('locationDetectingGps');
  String get locationDropoffTitle => _get('locationDropoffTitle');
  String get locationErrorGeocodingFailed => _get('locationErrorGeocodingFailed');
  String get locationErrorGpsUnavailable => _get('locationErrorGpsUnavailable');
  String get locationErrorPermissionDenied => _get('locationErrorPermissionDenied');
  String get locationErrorSaveFailed => _get('locationErrorSaveFailed');
  String get locationErrorSearchFailed => _get('locationErrorSearchFailed');
  String get locationNoSelectionYet => _get('locationNoSelectionYet');
  String get locationOpenMap => _get('locationOpenMap');
  String get locationPickupTitle => _get('locationPickupTitle');
  String get locationResolvingAddress => _get('locationResolvingAddress');
  String get locationSavingCta => _get('locationSavingCta');
  String get locationSearchEmpty => _get('locationSearchEmpty');
  String get locationSelectedPreviewLabel => _get('locationSelectedPreviewLabel');
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
  String offersWindowRemaining(String time) => _get('offersWindowRemaining').replaceFirst('{time}', time);
  String get orderHistoryAddressMissing => _get('orderHistoryAddressMissing');
  String orderHistoryCardSemanticLabel(String id) => _get('orderHistoryCardSemanticLabel').replaceFirst('{id}', id);
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
  String get registrationSocialErrorAccountDisabled => _get('registrationSocialErrorAccountDisabled');
  String get registrationSocialErrorGeneric => _get('registrationSocialErrorGeneric');
  String get registrationSocialErrorInvalidToken => _get('registrationSocialErrorInvalidToken');
  String get registrationSocialErrorNetwork => _get('registrationSocialErrorNetwork');
  String get requestFeedAccept => _get('requestFeedAccept');
  String get requestFeedAccepting => _get('requestFeedAccepting');
  String get requestFeedActionAcceptedSnack => _get('requestFeedActionAcceptedSnack');
  String get requestFeedActionDeclinedSnack => _get('requestFeedActionDeclinedSnack');
  String get requestFeedActionExpiredSnack => _get('requestFeedActionExpiredSnack');
  String get requestFeedActionNetworkSnack => _get('requestFeedActionNetworkSnack');
  String get requestFeedActionTakenSnack => _get('requestFeedActionTakenSnack');
  String get requestFeedDecline => _get('requestFeedDecline');
  String get requestFeedDeclining => _get('requestFeedDeclining');
  String requestFeedDistance(String distance) => _get('requestFeedDistance').replaceFirst('{distance}', distance);
  String get requestFeedDropoffLabel => _get('requestFeedDropoffLabel');
  String requestFeedEarnings(String amount, String currency) => _get('requestFeedEarnings').replaceFirst('{amount}', amount).replaceFirst('{currency}', currency);
  String get requestFeedEmptySubtitle => _get('requestFeedEmptySubtitle');
  String get requestFeedEmptyTitle => _get('requestFeedEmptyTitle');
  String get requestFeedErrorLoad => _get('requestFeedErrorLoad');
  String get requestFeedErrorRetry => _get('requestFeedErrorRetry');
  String get requestFeedErrorTitle => _get('requestFeedErrorTitle');
  String requestFeedExpiresIn(int seconds) => _get('requestFeedExpiresIn').replaceFirst('{seconds}', '$seconds');
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
  String get voiceRecordingErrorMaxReached => _get('voiceRecordingErrorMaxReached');
  String get voiceRecordingErrorPermission => _get('voiceRecordingErrorPermission');
  String get voiceRecordingErrorRecorderFailed => _get('voiceRecordingErrorRecorderFailed');
  String get voiceRecordingErrorTooShort => _get('voiceRecordingErrorTooShort');
  String get voiceRecordingErrorUnavailable => _get('voiceRecordingErrorUnavailable');
  String get voiceRecordingErrorUploadGeneric => _get('voiceRecordingErrorUploadGeneric');
  String get voiceRecordingErrorUploadNetwork => _get('voiceRecordingErrorUploadNetwork');
  String get voiceRecordingErrorUploadServer => _get('voiceRecordingErrorUploadServer');
  String get voiceRecordingHoldToRecord => _get('voiceRecordingHoldToRecord');
  String get voiceRecordingMicSemantic => _get('voiceRecordingMicSemantic');
  String get voiceRecordingPause => _get('voiceRecordingPause');
  String get voiceRecordingPlay => _get('voiceRecordingPlay');
  String get voiceRecordingRecordAnother => _get('voiceRecordingRecordAnother');
  String get voiceRecordingReleaseToStop => _get('voiceRecordingReleaseToStop');
  String get voiceRecordingSend => _get('voiceRecordingSend');
  String get voiceRecordingSending => _get('voiceRecordingSending');
  String get voiceRecordingSentBody => _get('voiceRecordingSentBody');
  String get voiceRecordingSentTitle => _get('voiceRecordingSentTitle');
  String get voiceRecordingSubtitle => _get('voiceRecordingSubtitle');
  String voiceRecordingTimerLabel(String duration) => _get('voiceRecordingTimerLabel').replaceFirst('{duration}', duration);
  String get voiceRecordingTitle => _get('voiceRecordingTitle');
  String get splashTagline => _get('splashTagline');
  String get splashLogoSemantic => _get('splashLogoSemantic');
}
