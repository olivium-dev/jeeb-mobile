import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/accessibility/accessibility.dart';
import '../../../../core/theme/jeeb_scrim.dart';
import '../../../../core/widgets/jeeb/jeeb_filter_sheet.dart';
import '../../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../jeeber_request_feed/data/request_feed_models.dart';
import 'jeeber_feed_tab_view.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// What the jeeber committed when they tapped Apply.
class JeeberFeedFilterSelection {
  const JeeberFeedFilterSelection({required this.tier, required this.query});

  final JeeberTierFilter tier;
  final String query;
}

/// The visible name of a tier facet — shared by the sheet's chips and the
/// applied pill so the two can never drift apart.
String jeeberTierFilterLabel(AppLocalizations l10n, JeeberTierFilter tier) =>
    switch (tier) {
      JeeberTierFilter.all => l10n.jeeberFeedTierAll,
      JeeberTierFilter.flash => l10n.jeeberFeedTierFlash,
      JeeberTierFilter.express => l10n.jeeberFeedTierExpress,
      JeeberTierFilter.standard => l10n.jeeberFeedTierStandard,
    };

/// The jeeber board's filter sheet: search text + delivery tier, both STAGED —
/// nothing reaches the feed until Apply, whose label carries the live count.
class JeeberFeedFilterSheet extends StatefulWidget {
  const JeeberFeedFilterSheet({
    super.key,
    required this.requests,
    required this.tab,
    required this.tier,
    required this.query,
  });

  /// The feed's current request set, used only for the live result count.
  final List<DeliveryRequest> requests;

  /// The stage tab the filter will apply to.
  final JeeberFeedTab tab;

  /// Tier facet as currently applied to the feed.
  final JeeberTierFilter tier;

  /// Search facet as currently applied to the feed.
  final String query;

  /// Presents the sheet and resolves to the committed selection, or null when
  /// the jeeber dismissed it.
  static Future<JeeberFeedFilterSelection?> show(
    BuildContext context, {
    required List<DeliveryRequest> requests,
    required JeeberFeedTab tab,
    required JeeberTierFilter tier,
    required String query,
  }) {
    return showModalBottomSheet<JeeberFeedFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      // The scaffold's footer already pays max(viewInsets, viewPadding), so
      // the keyboard cannot bury the CTAs and nothing is paid twice.
      builder: (_) => JeeberFeedFilterSheet(
        requests: requests,
        tab: tab,
        tier: tier,
        query: query,
      ),
    );
  }

  @override
  State<JeeberFeedFilterSheet> createState() => _JeeberFeedFilterSheetState();
}

class _JeeberFeedFilterSheetState extends State<JeeberFeedFilterSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.query,
  );
  late JeeberTierFilter _tier = widget.tier;
  late String _query = widget.query;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Tier only ever narrowed the Nearby list.
  bool get _tierApplies => widget.tab == JeeberFeedTab.requests;

  bool get _hasStagedFacets =>
      _tier != JeeberTierFilter.all || _query.trim().isNotEmpty;

  int get _resultCount => jeeberFeedVisibleRequests(
    source: widget.requests,
    tab: widget.tab,
    tier: _tier,
    query: _query,
  ).length;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebFilterSheetScaffold(
      identifier: 'jeeber_feed_filter_sheet',
      title: l10n.jeeberFeedFilterSheetTitle,
      subtitle: l10n.jeeberFeedFilterSheetSubtitle,
      clearLabel: l10n.filterSheetClearCta,
      applyLabel: l10n.filterSheetApplyCta(_resultCount),
      clearEnabled: _hasStagedFacets,
      clearIdentifier: 'jeeber_feed_filter_clear',
      applyIdentifier: 'jeeber_feed_filter_apply',
      onClear: _onClear,
      onApply: _onApply,
      children: [
        JeebFilterSheetGroupLabel(text: l10n.jeeberFeedFilterSearchGroup),
        _FeedSearchField(
          controller: _controller,
          onChanged: (value) => setState(() => _query = value),
        ),
        if (_tierApplies) ...[
          const SizedBox(height: Spacing.large),
          JeebFilterSheetGroupLabel(text: l10n.jeeberFeedFilterTierGroup),
          _TierFilterWrap(
            active: _tier,
            onChanged: (tier) => setState(() => _tier = tier),
          ),
        ],
      ],
    );
  }

  /// Resets the draft in place; the feed still only changes on Apply.
  void _onClear() {
    setState(() {
      _tier = JeeberTierFilter.all;
      _query = '';
      _controller.clear();
    });
  }

  void _onApply() {
    Navigator.of(context).pop(
      JeeberFeedFilterSelection(tier: _tier, query: _query.trim()),
    );
  }
}

/// The board's search input, now a facet of the sheet instead of a row of the
/// feed. Lifted whole from the feed so the periwinkle focus ring survives.
class _FeedSearchField extends StatelessWidget {
  const _FeedSearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'jeeber_feed_search_field',
      // `OmdsSearchBar` hardcodes its focus ring to `colorScheme.primary` in
      // the decoration, so app_theme's periwinkle `focusedBorder` never lands.
      child: Theme(
        data: theme.copyWith(
          colorScheme: theme.colorScheme.copyWith(
            primary: theme.colorScheme.secondary,
          ),
        ),
        child: OmdsSearchBar(
          key: JeeberFeedTabView.searchBarKey,
          controller: controller,
          hintText: AppLocalizations.of(context).jeeberFeedSearchHint,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// T-MOB-029's tier chips — All / Flash / Express / Standard — rehoused as a
/// wrapping facet group. The `jeeber_feed_tier_chip_$index` ids are unchanged.
class _TierFilterWrap extends StatelessWidget {
  const _TierFilterWrap({required this.active, required this.onChanged});

  final JeeberTierFilter active;
  final ValueChanged<JeeberTierFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        key: JeeberFeedTabView.tierStripKey,
        spacing: Spacing.xSmall,
        runSpacing: Spacing.xSmall,
        children: JeeberTierFilter.values.indexed
            .map((entry) => _tierChip(entry.$1, entry.$2, l10n))
            .toList(growable: false),
      ),
    );
  }

  Widget _tierChip(int index, JeeberTierFilter tier, AppLocalizations l10n) {
    final label = jeeberTierFilterLabel(l10n, tier);
    void onTap() => onChanged(tier);
    return Semantics(
      identifier: 'jeeber_feed_tier_chip_$index',
      button: true,
      selected: active == tier,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: MinTapTarget(
          onTap: onTap,
          child: JeebSelectChip(
            role: JeebChipRole.filter,
            label: label,
            selected: active == tier,
          ),
        ),
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Room for both facet groups over the pinned footer.
const Size _jeeberFeedFilterSheetBox = Size(390, 520);

/// Search only — the shape the Pending and Replies stages get.
const Size _jeeberFeedFilterSheetSearchOnlyBox = Size(390, 380);

/// Mounted the way `showModalBottomSheet` presents it, without a route to push.
Widget _jeeberFeedFilterSheetHosted({
  required JeeberFeedTab tab,
  JeeberTierFilter tier = JeeberTierFilter.all,
  String query = '',
}) {
  return Align(
    alignment: AlignmentDirectional.bottomCenter,
    child: JeeberFeedFilterSheet(
      requests: const <DeliveryRequest>[],
      tab: tab,
      tier: tier,
      query: query,
    ),
  );
}

/// Nearby at rest: nothing staged, so the ghost CTA is inert.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Nearby · nothing staged',
  size: _jeeberFeedFilterSheetBox,
)
Widget jeeberFeedFilterSheetRest() =>
    _jeeberFeedFilterSheetHosted(tab: JeeberFeedTab.requests);

/// Both facets staged. Matrix, because the split footer is where AR bites.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Nearby · both facets staged',
  size: _jeeberFeedFilterSheetBox,
  matrix: true,
)
Widget jeeberFeedFilterSheetStaged() => _jeeberFeedFilterSheetHosted(
  tab: JeeberFeedTab.requests,
  tier: JeeberTierFilter.flash,
  query: 'pharmacy',
);

/// Pending: tier never narrowed this stage, so the group is absent entirely.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Pending · search only',
  size: _jeeberFeedFilterSheetSearchOnlyBox,
)
Widget jeeberFeedFilterSheetPendingStage() =>
    _jeeberFeedFilterSheetHosted(tab: JeeberFeedTab.pendingResponse);
