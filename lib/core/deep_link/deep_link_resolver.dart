library;

class DeepLinkResolution {
  const DeepLinkResolution({
    required this.location,
    required this.requiresAuth,
  });

  final String location;

  final bool requiresAuth;

  @override
  String toString() =>
      'DeepLinkResolution(location: $location, requiresAuth: $requiresAuth)';
}

class DeepLinkResolver {
  const DeepLinkResolver();

  static const String scheme = 'jeeb';

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._~-]+$');

  static const Set<String> _authPrefixes = <String>{
    'orders',
    'chat',
    'wallet',
    'disputes',
    'requests',
    'jeeber',
    'earnings',
    'notifications',
    'profile',
    'settings',
  };

  String? resolveLocation(Uri uri) => resolve(uri)?.location;

  DeepLinkResolution? resolve(Uri uri) {
    final segments = _foldedSegments(uri);
    if (segments == null || segments.isEmpty) return null;

    for (final segment in segments) {
      if (segment == '.' ||
          segment == '..' ||
          !_idPattern.hasMatch(segment)) {
        return null;
      }
    }

    final path = '/${segments.join('/')}';
    final query = uri.query;
    final location = query.isEmpty ? path : '$path?$query';
    return DeepLinkResolution(
      location: location,
      requiresAuth: _authPrefixes.contains(segments.first),
    );
  }

  List<String>? _foldedSegments(Uri uri) {
    final pathSegments = uri.pathSegments
        .where((s) => s.isNotEmpty)
        .toList(growable: true);
    if (uri.scheme == scheme) {
      final host = uri.host;
      return <String>[if (host.isNotEmpty) host, ...pathSegments];
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      return pathSegments;
    }
    return null;
  }
}
