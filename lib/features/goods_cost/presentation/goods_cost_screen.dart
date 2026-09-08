import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/goods_cost_cubit.dart';
import '../application/goods_cost_state.dart';
import '../data/dio_goods_cost_repository.dart';
import '../data/unavailable_goods_cost_repository.dart';
import '../domain/goods_cost.dart';
import '../domain/goods_cost_repository.dart';

/// "Enter Goods Cost" — the Jeeber declares how much the purchased goods cost
/// for a delivery (the amount the Client reimburses on receipt). Submitting
/// records the cost on the gateway and pops with the gateway-confirmed
/// [GoodsCost] (amount + currency verbatim).
///
/// [repository] is optional — production resolves [GoodsCostRepository] from
/// GetIt when registered, else constructs the Dio impl over the shared
/// `sl<Dio>()` so the running app reaches the real gateway; a DI-less
/// widget/router test falls back to the in-memory fake. Mirrors
/// `DeliveryReceiptScreen`'s self-resolving pattern.
///
/// Redesign-2026-08: re-skinned onto the Jeeb design system against its nearest
/// neighbour, screen 17 (offer composer) — in-body [JeebTopBar], an h1
/// headline, a [JeebSectionLabel] over the board's money-field treatment, the
/// honest cash note as a [JeebInfoNote], and one docked [JeebCtaFooter]. The
/// flow is untouched: same single field, same submit, same pop-with-record.
///
/// **This screen carries NO fee math, by design.** The goods cost is cash the
/// Client hands over in full — Jeeb takes its cut of the delivery fee, never of
/// the goods — so no platform-fee line, no [JeebMoneyBreakdown], no net row
/// belongs here.
// ORPHAN (JEBV4-227, verified 2026-07-12): zero external refs; its backend endpoint is also broken — see docs/project-understanding/reconciliation/orphans.md
class GoodsCostScreen extends StatelessWidget {
  const GoodsCostScreen({super.key, required this.deliveryId, this.repository});

  final String deliveryId;

  /// Optional repository override. Production leaves this null; widget tests
  /// inject a scripted instance.
  final GoodsCostRepository? repository;

  GoodsCostRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<GoodsCostRepository>()) {
      return sl<GoodsCostRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioGoodsCostRepository(sl<Dio>());
    }
    // GEN-01: a DI miss used to record goods costs against an in-memory fake
    // and pop a fabricated success.
    assert(false, 'GoodsCostRepository is not registered');
    return const UnavailableGoodsCostRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<GoodsCostCubit>(
      create: (_) =>
          GoodsCostCubit(repository: repo, deliveryId: deliveryId)
            ..loadCurrency(),
      child: const _GoodsCostView(),
    );
  }
}

class _GoodsCostView extends StatelessWidget {
  const _GoodsCostView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'goods_cost_root',
      explicitChildNodes: true,
      child: Scaffold(
        // R3: the app bar moves in-body — a 40px circle + title inside the
        // 24px gutter, not a Material chrome bar above it.
        body: SafeArea(
          child: Column(
            children: [
              // Title + prompt, not title + h1: the board never stacks a
              // headline larger than the bar title under it (17 `tpl 991-993`
              // is the same two-line bar). Both existing strings survive, in
              // the right order of voice — the imperative on top, the question
              // as its muted qualifier.
              JeebTopBar.back(
                title: l10n.goodsCostTitle,
                subtitle: l10n.goodsCostHeadline,
                identifier: 'goods_cost_back',
                leadingTooltip: MaterialLocalizations.of(
                  context,
                ).backButtonTooltip,
              ),
              const Expanded(child: _CostFieldAndSubmit()),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostFieldAndSubmit extends StatefulWidget {
  const _CostFieldAndSubmit();

  @override
  State<_CostFieldAndSubmit> createState() => _CostFieldAndSubmitState();
}

class _CostFieldAndSubmitState extends State<_CostFieldAndSubmit> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null) return;
    context.read<GoodsCostCubit>().submit(amount);
  }

  /// Entry-field label using the gateway-authoritative currency (no hardcoded
  /// currency — 40_GUARDRAILS_ARCH §5). There is no user/config currency field,
  /// so the delivery's currency from the gateway is the source of truth; until
  /// it resolves (or if the best-effort read failed) the label degrades to a
  /// neutral "Goods Cost".
  String _label(AppLocalizations l10n, String? currency) =>
      (currency != null && currency.isNotEmpty)
      ? l10n.goodsCostFieldLabel(currency)
      : l10n.goodsCostFieldLabelNeutral;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<GoodsCostCubit, GoodsCostState>(
      listenWhen: (prev, next) =>
          prev.submitStatus != next.submitStatus &&
          next.submitStatus == GoodsCostSubmitStatus.succeeded,
      listener: (context, state) {
        // Side effect ONLY in the listener (40_GUARDRAILS_ARCH §3): pop with the
        // gateway-confirmed record (amount + currency verbatim).
        final GoodsCost? recorded = state.recorded;
        if (recorded != null) {
          Navigator.of(context).pop(recorded);
        }
      },
      builder: (context, state) {
        final submitting = state.isSubmitting;
        final failed = state.submitStatus == GoodsCostSubmitStatus.failed;
        return Column(
          children: [
            Expanded(
              // R1: the residual space below the note stays bare field — the
              // content is top-aligned and never grows to fill it.
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.xLarge,
                  Spacing.large,
                  Spacing.xLarge,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: JeebSectionLabel(_label(l10n, state.currency)),
                        ),
                        if (state.currencyUnavailable)
                          JeebCtaButton.text(
                            identifier: 'goods_cost_currency_retry',
                            label: l10n.actionRetry,
                            onTap: () =>
                                context.read<GoodsCostCubit>().loadCurrency(),
                          ),
                      ],
                    ),
                    const SizedBox(height: Spacing.small),
                    _AmountField(
                      controller: _controller,
                      isEnabled: !submitting,
                      // UX-38: only a VALIDATION rejection is the field's
                      // fault; every other kind renders on the note below.
                      errorText:
                          failed &&
                              state.submitError == GoodsCostFailure.validation
                          ? l10n.goodsCostErrorValidation
                          : null,
                      onChanged: (_) {
                        if (failed) {
                          context.read<GoodsCostCubit>().acknowledgeError();
                        } else {
                          setState(() {});
                        }
                      },
                    ),
                    if (failed &&
                        state.submitError != GoodsCostFailure.validation) ...[
                      const SizedBox(height: Spacing.small),
                      Semantics(
                        liveRegion: true,
                        child: JeebInfoNote.error(
                          icon: Icons.error_outline,
                          text: _errorCopy(l10n, state),
                          identifier: 'goods_cost_error_note',
                        ),
                      ),
                    ],
                    if (state.currencyUnavailable) ...[
                      const SizedBox(height: Spacing.small),
                      JeebInfoNote.warning(
                        icon: Icons.help_outline,
                        text: l10n.goodsCostCurrencyUnavailable,
                        identifier: 'goods_cost_currency_note',
                      ),
                    ],
                    const SizedBox(height: Spacing.medium),
                    // The honest cash line, in the board's repeated note shape
                    // (17's wallet strip sits in exactly this slot). Copy is the
                    // screen's existing body string — unchanged, just re-housed.
                    JeebInfoNote.muted(
                      icon: Icons.payments,
                      text: l10n.goodsCostBody,
                      identifier: 'goods_cost_cash_note',
                    ),
                  ],
                ),
              ),
            ),
            JeebCtaFooter.single(
              child: JeebCtaButton.primary(
                label: l10n.goodsCostSubmit,
                isLoading: submitting,
                isEnabled: _controller.text.trim().isNotEmpty && !submitting,
                onTap: _submit,
                identifier: 'goods_cost_submit_cta',
              ),
            ),
          ],
        );
      },
    );
  }

  /// Feature copy where the gateway named a reason; the shared failure family
  /// otherwise, so a 5xx and a timeout no longer read alike (R6).
  static String _errorCopy(AppLocalizations l10n, GoodsCostState state) {
    switch (state.submitError) {
      case GoodsCostFailure.network:
        return l10n.goodsCostErrorNetwork;
      case GoodsCostFailure.notFound:
        return l10n.goodsCostErrorNotFound;
      case GoodsCostFailure.validation:
        return l10n.goodsCostErrorValidation;
      case GoodsCostFailure.currencyUnavailable:
        return l10n.goodsCostCurrencyUnavailable;
      case GoodsCostFailure.amountUnconfirmed:
        return l10n.goodsCostErrorAmountUnconfirmed;
      case GoodsCostFailure.unknown:
      case null:
        final cause = state.failure;
        return cause == null
            ? l10n.goodsCostErrorGeneric
            : failureCopy(l10n, cause).body;
    }
  }
}

/// The goods-cost money input, drawn to the board's money-field treatment
/// (screen 17 `tpl 995`): `min-h 64 / r16 / 2px ACCENT` over a
/// `surfaceContainerHigh` fill, with the amount in a w800 `onSurface` run —
/// [JeebMoneyField]'s ratified split, where the stroke is the screen's one
/// budgeted orange and the digits stay ink so they read. A failure swaps the
/// stroke to `colorScheme.error` and hangs the message beneath.
///
/// **Why not `OmdsTextField`.** The board needs a caller-set text style (the
/// amount is w800, far above any input style OMDS ships), `textDirection` on
/// the editable core, and no decoration at all (the border and fill belong to
/// this box). `omds_text_field.dart` exposes none of the three — the same
/// finding screen 17 recorded on `JeebMoneyField`.
///
/// **Why not that `JeebMoneyField`.** It lives in another lane's feature
/// directory (`lib/features/offers/presentation/widgets/`), and its `onStep`
/// and `±1` [JeebStepperPill] pair are required parameters — mounting it here
/// would add a price-stepper affordance this flow does not have. Wiring request
/// W4-GOODS-1 asks for it to be promoted into `lib/core/widgets/jeeb/` with an
/// optional stepper slot; this widget is deleted the day that lands.
///
/// Design values are snapped, not exact: `lib/features` may not write
/// `fontSize:` literals (`tool/check_design_tokens.sh`), so the amount uses
/// `jeebText.h1` at w800 — 26/w800 against the board's 26/w800, exact after
/// the Midnight ramp re-cut.
///
/// RTL: a plain box, so it mirrors as a block, while the editable core is
/// pinned to [TextDirection.ltr] so the digits and the decimal point never
/// reorder; the run hugs the leading edge in both directions.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.isEnabled,
    required this.onChanged,
    this.errorText,
  });

  /// `height: 64` (board `tpl 995`) — a MINIMUM, not a fixed height, so the box
  /// grows with the text scale instead of clipping at 200%.
  static const double minHeight = Sizes.sixXLarge;

  /// The board's `2px` accent stroke (`tpl 995`) — the lit-field treatment.
  static const double borderWidth = 2;

  final TextEditingController controller;

  /// False while a record is in flight — the field stops taking keystrokes,
  /// exactly as the previous `OmdsTextField(enabled:)` did.
  final bool isEnabled;

  final ValueChanged<String> onChanged;

  /// Submit failure. Non-null also swaps the stroke to `colorScheme.error`.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final message = errorText;

    final field = DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
        border: Border.all(
          color: message != null ? scheme.error : context.jeebRoles.accent,
          width: borderWidth,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
          ),
          child: _editableCore(context),
        ),
      ),
    );

    if (message == null) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        const SizedBox(height: Spacing.xSmall),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: Spacing.twoXSmall),
          child: Text(
            message,
            key: const Key('goods-cost-error'),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
      ],
    );
  }

  Widget _editableCore(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    // The box mirrors, so the digits must hug the leading edge from whichever
    // side it lands on — while the run itself stays LTR.
    final alignment = Directionality.of(context) == TextDirection.rtl
        ? TextAlign.end
        : TextAlign.start;

    return Semantics(
      identifier: 'goods_cost_amount_field',
      textField: true,
      // Raw field is deliberate — see the class doc. The marker sits inline
      // because `dart format` relocates a trailing `//` after an open paren.
      child: /* EXEMPT(flutter-omds-design-system-usage) */ TextField(
        controller: controller,
        enabled: isEnabled,
        onChanged: onChanged,
        style: context.jeebText.h1.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
        textDirection: TextDirection.ltr,
        textAlign: alignment,
        // Theme ruling 4: the caret stays periwinkle app-wide; orange is spent
        // on the stroke here, exactly as `JeebMoneyField` spends it.
        cursorColor: semantics.mutedText,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
