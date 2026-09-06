import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../features/live_tracking/application/live_tracking_cubit.dart';
import '../../../features/live_tracking/presentation/live_tracking_screen.dart';
import '../../../features/notifications/application/notifications_list_cubit.dart';
import '../../../features/notifications/presentation/widgets/notification_row.dart';
import '../../../features/offers/application/offer_submission_cubit.dart';
import '../../../features/offers/domain/offer_submission_repository.dart';
import '../../../features/offers/presentation/widgets/jeeb_money_field.dart';
import '../../../features/reviews/application/reviews_cubit.dart';
import '../../../features/reviews/presentation/widgets/review_row.dart';
import 'catalog_transition_host.dart';

Widget catalogTrackingFailure(Widget child, {bool positionLost = false}) =>
    CatalogTransitionHost(
      steps: [
        for (var read = 0; read < (positionLost ? 2 : 1); read++)
          (root) {
            final element = CatalogTransitionHost.find<LiveTrackingScreen>(
              root,
            );
            if (element == null) return false;
            final cubit = element.read<LiveTrackingCubit>();
            if (cubit.state.trackingInfo == null) return false;
            unawaited(cubit.refreshNow());
            return true;
          },
        (root) {
          final element = CatalogTransitionHost.find<LiveTrackingScreen>(root);
          if (element == null) return false;
          final state = element.read<LiveTrackingCubit>().state;
          return positionLost
              ? state.trackingInfo?.positionLost == true
              : state.refreshError != null;
        },
      ],
      child: child,
    );

enum CatalogReviewAction { refresh, loadMore, report }

Widget catalogReviewFailure(Widget child, CatalogReviewAction action) =>
    CatalogTransitionHost(
      steps: [
        (root) {
          final element = CatalogTransitionHost.find<ReviewRow>(root);
          if (element == null) return false;
          final cubit = element.read<ReviewsCubit>();
          switch (action) {
            case CatalogReviewAction.refresh:
              unawaited(cubit.refresh());
            case CatalogReviewAction.loadMore:
              if (!cubit.state.hasMore) {
                throw StateError('Load-more fixture must have a second page');
              }
              unawaited(cubit.loadMore());
            case CatalogReviewAction.report:
              unawaited(cubit.reportReview(cubit.state.reviews.first.id));
          }
          return true;
        },
      ],
      child: child,
    );

Widget catalogNotificationFailure(Widget child, {bool refLess = false}) =>
    CatalogTransitionHost(
      steps: [
        (root) {
          final element = CatalogTransitionHost.find<NotificationRow>(root);
          if (element == null) return false;
          final row = element.widget as NotificationRow;
          if (refLess) {
            row.onTap();
          } else {
            // Exercise the PATCH/revert without following the row's separate
            // navigation into another screen before the rejection arrives.
            unawaited(
              element.read<NotificationsListCubit>().markRead(row.item.id),
            );
          }
          return true;
        },
      ],
      child: child,
    );

Widget catalogAttachPhoto(Widget child) => CatalogTransitionHost(
  steps: [
    (root) {
      final element = CatalogTransitionHost.find<JeebCtaButton>(
        root,
        (button) => button.identifier == 'prohibited_item_report_attach_photo',
      );
      if (element == null) return false;
      (element.widget as JeebCtaButton).onTap!();
      return true;
    },
  ],
  child: child,
);

Widget catalogSubmitOffer(Widget child, OfferSubmissionFailure failure) =>
    CatalogTransitionHost(
      steps: [
        (root) {
          final element = CatalogTransitionHost.find<JeebMoneyField>(root);
          if (element == null) return false;
          final field = element.widget as JeebMoneyField;
          final price = failure == OfferSubmissionFailure.insufficientBalance
              ? '125'
              : '15';
          field.controller.text = price;
          field.onChanged(price);
          final noteElement = CatalogTransitionHost.find<TextField>(
            root,
            (field) => field.maxLines != 1,
          );
          if (noteElement == null) return false;
          final noteField = noteElement.widget as TextField;
          final note = failure == OfferSubmissionFailure.noteTooLong
              ? List.filled(40, 'Please collect carefully.').join(' ')
              : 'Please collect from the pharmacy.';
          var value = TextEditingValue(
            text: note,
            selection: TextSelection.collapsed(offset: note.length),
          );
          final old = noteField.controller!.value;
          for (final formatter
              in noteField.inputFormatters ?? const <TextInputFormatter>[]) {
            value = formatter.formatEditUpdate(old, value);
          }
          noteField.controller!.value = value;
          noteField.onChanged?.call(value.text);
          return true;
        },
        (root) {
          final element = CatalogTransitionHost.find<JeebCtaButton>(
            root,
            (button) => button.identifier == 'offer_composer_send_cta',
          );
          if (element == null) return false;
          final button = element.widget as JeebCtaButton;
          if (!button.isEnabled) return false;
          button.onTap!();
          return true;
        },
        (root) {
          final element = CatalogTransitionHost.find<JeebMoneyField>(root);
          if (element == null) return false;
          final state = element.read<OfferFormCubit>().state;
          return !state.isSubmitting && state.mode != OfferFormMode.idle;
        },
      ],
      child: child,
    );
