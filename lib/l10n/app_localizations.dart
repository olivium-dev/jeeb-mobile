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
    return value ?? key;
  }

  String get appTitle => _get('appTitle');

  String get navHome => _get('navHome');
  String get navOrders => _get('navOrders');
  String get navChat => _get('navChat');
  String get navProfile => _get('navProfile');
  String get navDashboard => _get('navDashboard');
  String get navEarnings => _get('navEarnings');

  String get homeTitle => _get('homeTitle');
  String get homeEmptyTitle => _get('homeEmptyTitle');
  String get homeEmptySubtitle => _get('homeEmptySubtitle');
  String get homeEmptyCta => _get('homeEmptyCta');
  String get homeActiveSectionTitle => _get('homeActiveSectionTitle');
  String get homeRecentSectionTitle => _get('homeRecentSectionTitle');
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
  String get chatActiveDeliveryTitle => _get('chatActiveDeliveryTitle');
  String get chatActiveDeliverySubtitle => _get('chatActiveDeliverySubtitle');
  String get chatPlaceholderCounterpartName =>
      _get('chatPlaceholderCounterpartName');
  String get chatEmptyThreadTitle => _get('chatEmptyThreadTitle');
  String get chatEmptyThreadSubtitle => _get('chatEmptyThreadSubtitle');
  String get chatComposerHint => _get('chatComposerHint');
  String get chatSendTooltip => _get('chatSendTooltip');
  String get chatAttachTooltip => _get('chatAttachTooltip');
  String get chatAttachmentSheetTitle => _get('chatAttachmentSheetTitle');
  String get chatAttachmentCamera => _get('chatAttachmentCamera');
  String get chatAttachmentGallery => _get('chatAttachmentGallery');
  String get chatAttachmentCancel => _get('chatAttachmentCancel');
  String get chatErrorPermissionDenied => _get('chatErrorPermissionDenied');
  String get chatErrorPickUnavailable => _get('chatErrorPickUnavailable');
  String get chatErrorSendFailed => _get('chatErrorSendFailed');
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
    return _get('dashboardTodayEarningsCompletedMany')
        .replaceFirst('{count}', '$count');
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
    return _get('dashboardNearbyRequestsMany').replaceFirst('{count}', '$count');
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
    return _get('requestSummaryFindingNotifiedMany')
        .replaceFirst('{count}', '$count');
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

  String get voiceRecordingTitle => _get('voiceRecordingTitle');
  String get voiceRecordingSubtitle => _get('voiceRecordingSubtitle');
  String get voiceRecordingHoldToRecord => _get('voiceRecordingHoldToRecord');
  String get voiceRecordingReleaseToStop => _get('voiceRecordingReleaseToStop');
  String get voiceRecordingMicSemantic => _get('voiceRecordingMicSemantic');
  String voiceRecordingTimerLabel(String duration) =>
      _get('voiceRecordingTimerLabel').replaceFirst('{duration}', duration);
  String get voiceRecordingPlay => _get('voiceRecordingPlay');
  String get voiceRecordingPause => _get('voiceRecordingPause');
  String get voiceRecordingDiscard => _get('voiceRecordingDiscard');
  String get voiceRecordingCancel => _get('voiceRecordingCancel');
  String get voiceRecordingSend => _get('voiceRecordingSend');
  String get voiceRecordingSending => _get('voiceRecordingSending');
  String get voiceRecordingSentTitle => _get('voiceRecordingSentTitle');
  String get voiceRecordingSentBody => _get('voiceRecordingSentBody');
  String get voiceRecordingRecordAnother =>
      _get('voiceRecordingRecordAnother');
  String get voiceRecordingErrorPermission =>
      _get('voiceRecordingErrorPermission');
  String get voiceRecordingErrorUnavailable =>
      _get('voiceRecordingErrorUnavailable');
  String get voiceRecordingErrorRecorderFailed =>
      _get('voiceRecordingErrorRecorderFailed');
  String get voiceRecordingErrorTooShort =>
      _get('voiceRecordingErrorTooShort');
  String get voiceRecordingErrorMaxReached =>
      _get('voiceRecordingErrorMaxReached');
  String get voiceRecordingErrorUploadNetwork =>
      _get('voiceRecordingErrorUploadNetwork');
  String get voiceRecordingErrorUploadServer =>
      _get('voiceRecordingErrorUploadServer');
  String get voiceRecordingErrorUploadGeneric =>
      _get('voiceRecordingErrorUploadGeneric');
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
