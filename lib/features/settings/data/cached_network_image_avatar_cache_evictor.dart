import 'package:cached_network_image/cached_network_image.dart';

import '../domain/avatar_cache_evictor.dart';

/// Real [AvatarCacheEvictor]: `OmdsCachedImage` (which `JeebAvatar` composes,
/// jeeb_avatar.dart) is a bare `CachedNetworkImage`, so its own static evict
/// call is the one that actually drops the disk/memory cache entry.
class CachedNetworkImageAvatarCacheEvictor implements AvatarCacheEvictor {
  const CachedNetworkImageAvatarCacheEvictor();

  @override
  Future<void> evict(String url) => CachedNetworkImage.evictFromCache(url);
}
