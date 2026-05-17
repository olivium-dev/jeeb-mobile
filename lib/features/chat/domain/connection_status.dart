/// High-level connection state surfaced to the UI banner.
///
/// `disconnected` covers both "never connected" and "lost connection, not
/// yet retrying"; the screen renders the same offline indicator either way.
/// `reconnecting` is distinct from `connecting` so the banner can show a
/// "trying to reconnect…" copy instead of the first-time spinner.
enum ConnectionStatus { disconnected, connecting, connected, reconnecting }
