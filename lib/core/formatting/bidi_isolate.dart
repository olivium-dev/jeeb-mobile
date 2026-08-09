/// First-strong isolate marks (FSI / PDI), written as escapes: a raw bidi
/// control in source makes the code read differently than it compiles.
const String kBidiIsolateStart = '\u{2068}';
const String kBidiIsolateEnd = '\u{2069}';

/// Wraps user-authored free text in a first-strong isolate so a leading digit
/// stays attached to its item inside an RTL paragraph, while Arabic-authored
/// content keeps its own direction (unlike a hard LTR mark).
String bidiIsolate(String text) =>
    text.isEmpty ? text : '$kBidiIsolateStart$text$kBidiIsolateEnd';
