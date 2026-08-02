/// Widget previews for [ProfileAvatar] — run with
/// `flutter widget-preview start`.
///
/// [ProfileAvatar] is a pure [StatelessWidget] over three plain fields
/// (`name`, `photoUrl`, `diameter`), so every state below is a bare constructor
/// call: no cubit, no repository, nothing to seed. Network-free by
/// construction, not merely by [jeebPreviewHost]'s guard — see the note on
/// `photoUrl` below.
///
/// Fixtures are the ones this feature already uses: 'Sami' is the seed in
/// `test/profile_edit_screen_test.dart:82`, and the stale-path state spells out
/// the filename shape `AppDirProfilePhotoStore.persist` actually writes
/// (`profile_avatar_<millis>.jpg` under the app documents directory —
/// `lib/features/settings/data/profile_photo_store.dart:28`).
///
/// **The three branches, and which two are previewable.** `build` forks on
/// `photoUrl`:
///
/// | `photoUrl`                | branch                       | previewed |
/// |---------------------------|------------------------------|-----------|
/// | `null` / `''`             | `_InitialBubble`             | yes       |
/// | starts `/` or `file://`   | `Image.file` + `errorBuilder`| yes       |
/// | anything else (`https:`)  | `OmdsCachedImage`            | **no**    |
///
/// The `https:` branch is deliberately unpreviewed. It hands the URL to
/// `CachedNetworkImage`, whose fetch resolves in neither the canvas nor a test,
/// so it would land on the very same `_InitialBubble` the `null` states already
/// render — the "every preview looks identical" failure the `expectedText` map
/// in the test exists to catch — while being the one state that reaches the
/// network. It is also close to unreachable in production: there is no
/// avatar-upload endpoint (`ProfilePhotoStore`'s own doc says so), and the only
/// route that mounts this widget writes `photoUrl` exclusively from a local
/// `ProfilePhotoStore` path. A remote URL here can only arrive as legacy data.
///
/// **Measured geometry** (off the render tree, bundled Inter — not eyeballed).
/// The circle is a fixed `diameter` (default `Sizes.tenXLarge` = 96 dp) and the
/// initial is `displaySmall` at a flat 36 dp with no `TextScaler` clamp, so the
/// glyph scales and its container does not:
///
/// | rendering | circle | initial line box |
/// |-----------|--------|------------------|
/// | 1x        | 96 dp  | 36 × 44 dp       |
/// | 200% text | 96 dp  | 72 × 88 dp       |
///
/// So the **EN 200% text** rendering holds — with 4 dp of clearance top and
/// bottom, and `Container` sets no `clipBehavior` to catch it if that goes. The
/// headroom is arithmetic (96 > 2 × 44), not design: one step up the type ramp
/// and the letter paints onto the page background.
///
/// The same fixed 36 dp makes the public `diameter` knob a trap in the other
/// direction — it shrinks the circle and nothing else, so any caller passing a
/// diameter under the 44 dp line box gets a letter taller than its bubble.
/// Nothing in the app does today (`ProfileEditScreen` is the sole call site and
/// takes the default), which is why that is pinned in the test rather than
/// given a preview of its own.
library;

import 'package:flutter/material.dart';

import '../harness/jeeb_preview.dart';
import '../../features/settings/presentation/widgets/profile_avatar.dart';

/// Snug around the 96 dp circle, with vertical room for what the initial takes
/// at 200% text — an overflow stripe in the canvas is then a real regression,
/// not a box that was drawn too small. The widget does not centre itself
/// (`ProfileEditScreen` puts it in a `Column`), so it hugs the leading edge.
const Size _avatarBox = Size(200, 180);

/// One specimen. Mirrors the sole call site,
/// `lib/features/settings/presentation/screens/profile_edit_screen.dart:202`
/// (`ProfileAvatar(name: state.profile.name, photoUrl: state.profile.photoUrl)`),
/// so a preview cannot drift from how the screen builds it.
Widget _hosted(String? name, {String? photoUrl}) =>
    ProfileAvatar(name: name, photoUrl: photoUrl);

/// The state nearly every profile is in.
///
/// `UserProfile.photoUrl` is null until the user runs the JEBV4-13 "Change
/// avatar" flow, and there is no server-side avatar to inherit, so the initial
/// bubble — not a photo — is the shipping appearance of this widget. 'Sami' is
/// the fixture `test/profile_edit_screen_test.dart` seeds.
///
/// Worth reading for contrast: this bubble paints `onPrimaryContainer` on
/// `primaryContainer` — the M3 tone-10/tone-90 pair the b02 audit installed —
/// measuring 13.28:1 light and 7.23:1 dark, where its sibling `FeedbackAvatar`
/// hardcodes white ink on the same fill and measures 1.29:1. Same fill, same
/// glyph, one of them legible.
@JeebPreview(group: 'settings', name: 'Named, no photo', size: _avatarBox)
Widget profileAvatarNamed() => _hosted('Sami');

/// Cold start for an OTP-only signup: no name, no photo.
///
/// `SettingsCubit` seeds `UserProfile.name` as null for a phone-only account
/// (`test/profile_edit_screen_test.dart:124` asserts exactly that after a
/// rejected save), and the profile-edit screen opens on this. The `?` fallback
/// is the widget's whole reason for existing — a blank circle here would read
/// as a failed image load rather than as an empty profile.
///
/// Also covers `name: '   '`: `_initial` trims before testing for empty, so a
/// whitespace-only name lands on this identical rendering rather than on a
/// space-shaped hole.
@JeebPreview(group: 'settings', name: 'No name yet', size: _avatarBox)
Widget profileAvatarNoName() => _hosted(null);

/// An Arabic name — the majority case for this app.
///
/// Two things this state proves that no Latin fixture can. `toUpperCase()` is a
/// no-op for Arabic, so the glyph must arrive as authored; and the initial must
/// be the *first* letter as written, i.e. the rightmost glyph of the name.
///
/// It is also the one place [ProfileAvatar] is measurably better than the
/// sibling avatar in `lib/previews/rating/feedback_avatar_preview.dart`: this
/// widget puts `trimmed.characters.first` — a full grapheme cluster — straight
/// into a [Text], whereas `OmdsProfileAvatar` re-slices its initial with
/// `initial[0]`, a UTF-16 code-unit index, and drops the second half of any
/// decomposed letter. Check **AR RTL dark**: the circle is symmetric, so
/// anything that shifts there is the ambient [Directionality], not the avatar.
@JeebPreview(group: 'settings', name: 'Arabic name', size: _avatarBox)
Widget profileAvatarArabicName() => _hosted('ليلى حداد');

/// A phone-only account as `getMe` returns it (sprint-009 §T5).
///
/// Jeeb mints `jeeb-<hash>` display names for OTP-only signups, and this widget
/// takes `name` raw — it has none of the `displayNameOrNull` suppression that
/// `ClientHomeGreeting` applies to the same string. The result is worse than a
/// blank avatar: the circle shows a confident 'J', which reads as a person
/// whose name starts with J rather than as "we do not know this user's name".
/// The `?` fallback never fires, because a synthetic handle is a non-empty
/// string.
@JeebPreview(group: 'settings', name: 'Phone-only synthetic handle', size: _avatarBox)
Widget profileAvatarSyntheticHandle() => _hosted('jeeb-e1a35ea8a520');

/// `photoUrl: ''` — what a JSON payload sends for "no photo", as distinct from
/// omitting the field.
///
/// `build` short-circuits on `photoUrl!.isEmpty` before it constructs anything
/// image-shaped, so this renders the initial rather than a broken-image box.
/// That check is load-bearing: without it an empty string is neither a local
/// path nor a valid URL, so it would fall through to `OmdsCachedImage` and make
/// this the one preview that reaches the network.
@JeebPreview(group: 'settings', name: 'Empty photo URL', size: _avatarBox)
Widget profileAvatarEmptyPhotoUrl() => _hosted('Zeina Karam', photoUrl: '');

/// JEBV4-13, one reinstall later: a stored local path whose file is gone.
///
/// `AppDirProfilePhotoStore` writes the avatar into the app documents directory
/// and saves the absolute path on the profile. On iOS that path contains the
/// app container's UUID, which the OS regenerates on reinstall (and on some
/// restores), so a perfectly valid saved `photoUrl` can stop resolving without
/// anything in the app changing. The profile survives; the bytes do not.
///
/// This is the state the `errorBuilder` on `Image.file` exists for — it must
/// degrade to the same initial bubble as "no photo at all", never to a grey
/// broken-image glyph or an exception. Note what it costs: the fallback is
/// invisible to the user, so a silently-vanished avatar looks identical to one
/// that was never set.
///
/// It is also the one state whose *first* frame is empty. `Image.file` is given
/// an `errorBuilder` but no `frameBuilder`, where the `OmdsCachedImage` branch
/// two lines below IS given `placeholder: (_, _) => placeholder` — so the local
/// path is the only branch with no loading appearance at all, and paints a bare
/// 96 dp hole until the read resolves one way or the other. In the canvas the
/// read fails within a frame or two and you will normally see the settled
/// bubble; the empty frame is pinned in the test, where it is the whole state.
@JeebPreview(group: 'settings', name: 'Stale local photo path', size: _avatarBox)
Widget profileAvatarStaleLocalPath() => _hosted(
      'Karim Aoun',
      photoUrl: '/var/mobile/Containers/Data/Application/'
          '8B4E9F2A-1C3D-4E5F-9A7B-2D6C8E0F1A3B/Documents/'
          'profile_avatar_1754136000000.jpg',
    );
