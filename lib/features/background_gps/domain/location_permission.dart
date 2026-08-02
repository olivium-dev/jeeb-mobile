enum LocationPermission {
  notDetermined,

  denied,

  deniedForever,

  whileInUse,

  always,
}

extension LocationPermissionX on LocationPermission {
  bool get requiresSystemSettings => this == LocationPermission.deniedForever;
}
