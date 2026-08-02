/// High-level connection state surfaced to the UI banner.
/// `disconnected` covers both "never connected" and "lost connection, not
/// yet retrying"; the screen renders the same offline indicator either way.
enum ConnectionStatus { disconnected, connecting, connected, reconnecting }
