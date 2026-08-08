/// Port for evicting a stale avatar URL from whatever image cache
/// `JeebAvatar`/`OmdsProfileAvatar` render through. Kept behind a port
/// (rather than a direct `cached_network_image` import in the cubit) so unit
/// tests don't need a real image-cache singleton.
abstract class AvatarCacheEvictor {
  Future<void> evict(String url);
}
