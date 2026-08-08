import 'package:cached_network_image/cached_network_image.dart';

import '../domain/avatar_cache_evictor.dart';

/// Real [AvatarCacheEvictor]: `OmdsCachedImage` is a bare `CachedNetworkImage`,
/// so its static evict is what drops the disk/memory cache entry.
class CachedNetworkImageAvatarCacheEvictor implements AvatarCacheEvictor {
  const CachedNetworkImageAvatarCacheEvictor();

  @override
  Future<void> evict(String url) => CachedNetworkImage.evictFromCache(url);
}
