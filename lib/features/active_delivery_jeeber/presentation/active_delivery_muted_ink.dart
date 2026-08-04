import 'package:flutter/material.dart';

import '../../../core/theme/jeeb_semantic_colors.dart';

/// The periwinkle secondary ink the board uses for every quiet line on 18
/// (stage labels, the collect line, the door-code prompt, the note tile).
///
/// Read **defensively**, exactly as `JeebTopBar` does: a bare `!` on the theme
/// extension crashes every harness that pumps a plain `MaterialApp` with no
/// `AppTheme.light()` — six of this feature's own tests do precisely that, and
/// so does any downstream widget test that mounts the screen. The extension is
/// always present in the real app; the fallback exists so a missing theme is a
/// styling degradation and never a null-check crash.
Color jeebMutedInk(BuildContext context) => jeebGlass(context).mutedText;

/// The whole Midnight token set, read with the same defensive fallback — 18's
/// evidence tiles and dashed note frame are glass, not opaque navy.
JeebSemanticColors jeebGlass(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.light();
