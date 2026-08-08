/// Port for evicting a stale avatar URL from the image cache `JeebAvatar`
/// renders through — kept off the cubit so unit tests need no cache singleton.
abstract class AvatarCacheEvictor {
  Future<void> evict(String url);
}
