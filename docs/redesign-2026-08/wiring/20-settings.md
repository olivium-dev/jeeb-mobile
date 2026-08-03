# Wiring requests — 20 · Settings

Screen 20 was implemented against the shipped Wave-1 kit. Six new l10n keys are required; the two
kit asks (K1 `JeebSegment` key/identifier pass-through, K2 `JeebListRow.showChevron`) **already
shipped** in the audited kit, so no kit change is requested — the blocks are recorded at the bottom
for traceability only.

---

```
### l10n
file: lib/l10n/app_en.arb
need: Six new settings-scoped strings for the redesigned Settings screen.
exact change:
  "settingsIdentitySubtitle": "{phone} · {action}",
  "@settingsIdentitySubtitle": {"description": "Identity-card subtitle: LTR-isolated phone + edit-profile action, dot-separated.", "placeholders": {"phone": {}, "action": {}}},
  "settingsBecomeJeeberSubtitle": "Earn on errands you're already making",
  "@settingsBecomeJeeberSubtitle": {"description": "Become-a-Jeeber card subtitle on Settings (settings-scoped; do NOT reuse becomeJeeberCardSubtitle, which the jeeber tab empty state renders)."},
  "settingsBecomeJeeberCta": "Start",
  "@settingsBecomeJeeberCta": {"description": "Trailing CTA word on the Become-a-Jeeber settings card (distinct from becomeJeeberCardCta 'Start now')."},
  "settingsAlwaysOnQualifier": " · always on",
  "@settingsAlwaysOnQualifier": {"description": "Inline qualifier after the security-codes row title; leading separator kept inside the string so AR can reorder."},
  "settingsMoreSection": "More",
  "@settingsMoreSection": {"description": "Section label above the addresses/notification-prefs/diagnostics list card."},
  "settingsVersionFooter": "Jeeb v{version} · Beirut",
  "@settingsVersionFooter": {"description": "Centered footer caption. City is deliberate static copy (Beirut-only coverage), not data.", "placeholders": {"version": {}}},
why: §3.3 identity subtitle, §3.4 growth card, §3.6 door-codes row, §3.7 MORE label, §3.8 version line.

### l10n
file: lib/l10n/app_ar.arb
need: Arabic values for the six keys above (parity gate fails both directions).
exact change:
  "settingsIdentitySubtitle": "{phone} · {action}",
  "settingsBecomeJeeberSubtitle": "اكسب من المشاوير التي تقوم بها أصلًا",
  "settingsBecomeJeeberCta": "ابدأ",
  "settingsAlwaysOnQualifier": " · مفعّل دائمًا",
  "settingsMoreSection": "المزيد",
  "settingsVersionFooter": "جيب الإصدار {version} · بيروت",
why: AR/EN parity for the same six strings.

### l10n
file: lib/l10n/app_localizations.dart
need: Typed getters for the six keys, following the existing _get / replaceFirst pattern (cf. accountDeleteSubmitted at :374).
exact change:
  String settingsIdentitySubtitle({required String phone, required String action}) =>
      _get('settingsIdentitySubtitle')
          .replaceFirst('{phone}', phone)
          .replaceFirst('{action}', action);
  String get settingsBecomeJeeberSubtitle => _get('settingsBecomeJeeberSubtitle');
  String get settingsBecomeJeeberCta => _get('settingsBecomeJeeberCta');
  String get settingsAlwaysOnQualifier => _get('settingsAlwaysOnQualifier');
  String get settingsMoreSection => _get('settingsMoreSection');
  String settingsVersionFooter(String version) =>
      _get('settingsVersionFooter').replaceFirst('{version}', version);
why: call sites in settings_identity_card.dart, settings_become_jeeber_card.dart, settings_notifications_card.dart, settings_more_card.dart, settings_footer.dart. Until this lands, `dart analyze lib/features/settings` reports exactly six "undefined getter/method" errors and nothing else.

### cross-feature
file: lib/features/shell/ (owner decision — no specific file yet)
need: A forward-nav entry point to `/settings`: the redesigned screen is mounted by
      `lib/features/shell/tabs/profile_tab.dart:88` via a local `MaterialPageRoute`, while the
      `/settings` route itself builds `LiveSettingsScreen` (a different widget). Nothing in `lib/`
      does `goNamed('settings')`.
exact change: owner decides — either point the `/settings` route at this `SettingsScreen`, or
      confirm the profile-tab push is the real screen-20 surface and retire the orphan route entry.
why: the ORPHAN comment carried on the back handler ("`canPop ? pop : go('/')`") only makes sense
      while both hosts exist; the real-flow validation standard needs one reachable surface.
```

---

## Already satisfied by the shipped kit (no action — recorded for traceability)

```
### cross-feature (SATISFIED — jeeb_segmented_toggle.dart already ships this)
file: lib/core/widgets/jeeb/jeeb_segmented_toggle.dart
need: Per-segment `key` and `identifier` pass-through with full a11y semantics per segment.
status: shipped — `JeebSegment{key, identifier, semanticLabel}` and `_Segment` emits
        Semantics(identifier:, label:, button: true, container: true,
        inMutuallyExclusiveGroup: true, selected:) around an ExcludeSemantics child.

### cross-feature (SATISFIED — jeeb_list_row.dart already ships this)
file: lib/core/widgets/jeeb/jeeb_list_row.dart
need: The trailing chevron must be suppressible.
status: shipped — `showChevron` (default true). Note the audit also renamed
        `enabled` → `isEnabled` and `contentPadding` → `padding`; this screen calls the new names.
```
